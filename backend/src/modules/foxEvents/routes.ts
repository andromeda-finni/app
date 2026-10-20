import type { FastifyInstance } from "fastify";
import type { PoolClient } from "pg";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction } from "../../lib/ledger.js";
import { bodySchema, shortIdSchema, uuidSchema } from "../../lib/schema.js";
import { advanceFox, rollFoxDay, type FoxState } from "./rules.js";

async function loadContext(client: PoolClient, child: string) {
  // Same owner lock/order as the game-day lifecycle and other economy actions.
  const profile = await client.query<{ difficulty: string }>(
    `SELECT difficulty FROM child_profiles WHERE user_id = $1 FOR UPDATE`, [child],
  );
  if (!profile.rows[0]) throw new HttpError(404, "child_profile_not_found");
  const period = await client.query<{ sequence_no: number }>(
    `SELECT gp.sequence_no FROM game_periods gp
       JOIN budget_plans bp ON bp.period_id = gp.id AND bp.status = 'CONFIRMED'
      WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE' FOR UPDATE OF gp`, [child],
  );
  const day = period.rows[0]?.sequence_no;
  if (day === undefined) return null;
  await client.query(
    `INSERT INTO fox_event_states (child_user_id) VALUES ($1) ON CONFLICT DO NOTHING`, [child],
  );
  const row = await client.query<{ state: FoxState }>(
    `SELECT state FROM fox_event_states WHERE child_user_id = $1 FOR UPDATE`, [child],
  );
  return { state: row.rows[0]!.state, day, difficulty: profile.rows[0].difficulty };
}

async function balance(client: PoolClient, child: string) {
  const result = await client.query<{ balance: number }>(
    `SELECT balance FROM wallets WHERE child_user_id = $1 AND kind = 'SPENDABLE' FOR UPDATE`, [child],
  );
  if (!result.rows[0]) throw new HttpError(404, "wallet_not_found");
  return result.rows[0].balance;
}

async function save(client: PoolClient, child: string, state: FoxState) {
  await client.query(
    `UPDATE fox_event_states SET state = $2::jsonb, updated_at = now() WHERE child_user_id = $1`,
    [child, JSON.stringify(state)],
  );
}

async function requireFreeCoins(client: PoolClient, child: string, amount: number, spendable: number) {
  const result = await client.query<{ reserve: number }>(
    `SELECT GREATEST(0, gp.required_need_amount
       - COALESCE((SELECT SUM(p.total_price) FROM purchases p
                    JOIN transactions t ON t.id = p.transaction_id
                   WHERE p.child_user_id = $1 AND p.item_kind = 'NEED'
                     AND t.occurred_at >= gp.opened_at), 0)
       - COALESCE((SELECT SUM(-t.delta_amount) FROM transactions t
                   WHERE t.child_user_id = $1 AND t.event_type = 'PET_EVENT_PAYMENT'
                     AND t.occurred_at >= gp.opened_at), 0))::int AS reserve
       FROM game_periods gp WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE'`, [child],
  );
  if (spendable - amount < (result.rows[0]?.reserve ?? 0)) {
    throw new HttpError(409, "insufficient_free_funds");
  }
}

export async function foxEventRoutes(app: FastifyInstance): Promise<void> {
  app.post("/fox-events/visit", {
    preHandler: [requireAuth, requireRole("CHILD")],
  }, async (req) => withTransaction(async (client) => {
    const child = req.authUser!.id;
    const context = await loadContext(client, child);
    if (!context) return { session: null };
    rollFoxDay(context.state, context.day, context.difficulty);
    await save(client, child, context.state);
    const session = context.state.session;
    return {
      session: session?.status === "active" ? session : null,
      gameDay: context.day, balance: await balance(client, child),
    };
  }));

  app.post<{ Body: { sessionId: string; nodeId: string; choiceId?: string } }>("/fox-events/advance", {
    preHandler: [requireAuth, requireRole("CHILD")],
    schema: bodySchema({ sessionId: uuidSchema, nodeId: shortIdSchema, choiceId: shortIdSchema }, ["sessionId", "nodeId"]),
  }, async (req) => withTransaction(async (client) => {
    const child = req.authUser!.id;
    const context = await loadContext(client, child);
    if (!context || context.state.session?.id !== req.body.sessionId) throw new HttpError(409, "fox_not_available");
    const { state, day } = context;
    const { nodeId, choiceId } = req.body;
    const delta = advanceFox(state, day, nodeId, choiceId);
    let spendable = await balance(client, child);
    if (delta !== 0) {
      if (delta < 0) await requireFreeCoins(client, child, -delta, spendable);
      const txn = await postTransaction(client, {
        childUserId: child, walletKind: "SPENDABLE", eventType: "FOX_EVENT", deltaAmount: delta,
        referenceType: "fox_event", referenceId: state.session!.id,
        idempotencyKey: `fox:${state.session!.id}:${nodeId}:${choiceId ?? "enter"}`,
      });
      spendable = txn.balanceAfter;
    }
    await save(client, child, state);
    return { session: state.session, gameDay: day, balance: spendable };
  }));
}
