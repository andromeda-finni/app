import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { transferBetweenWallets } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { withIdempotency } from "../../lib/idempotency.js";
import { bodySchema, idempotencyKeySchema } from "../../lib/schema.js";
import { HttpError } from "../../lib/errors.js";
import { lockGoalOwner, requireGoal } from "../economy/goals.js";

export async function walletRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/wallet",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query<{ kind: "SPENDABLE" | "SAVINGS"; balance: number }>(
        `SELECT kind, balance FROM wallets WHERE child_user_id = $1`,
        [req.authUser!.id],
      );
      const balances = Object.fromEntries(res.rows.map((row) => [row.kind, row.balance]));
      return {
        balance: balances.SPENDABLE ?? 0,
        savings: balances.SAVINGS ?? 0,
      };
    },
  );

  app.get(
    "/wallets",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query(
        `SELECT kind, balance, updated_at FROM wallets WHERE child_user_id = $1 ORDER BY kind`,
        [req.authUser!.id],
      );
      return res.rows;
    },
  );

  app.get(
    "/transactions",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query(
        `SELECT id, wallet_kind, event_type, delta_amount, balance_after, occurred_at
           FROM transactions WHERE child_user_id = $1
          ORDER BY occurred_at DESC LIMIT 50`,
        [req.authUser!.id],
      );
      return res.rows;
    },
  );

  // Voluntary extra saving/un-saving beyond the period's confirmed plan
  // (e.g. putting leftover spendable coins aside toward a goal).
  for (const [path, from, to] of [
    ["deposit", "SPENDABLE", "SAVINGS"],
    ["withdraw", "SAVINGS", "SPENDABLE"],
  ] as const) {
    app.post<{ Body: { amount: number; idempotencyKey: string } }>(
      `/savings/${path}`,
      {
        preHandler: [requireAuth, requireRole("CHILD")],
        schema: bodySchema(
          {
            amount: { type: "integer", minimum: 1 },
            idempotencyKey: idempotencyKeySchema,
          },
          ["amount", "idempotencyKey"],
        ),
      },
      async (req, reply) => {
        const { amount, idempotencyKey } = req.body;
        const childUserId = req.authUser!.id;
        const keyPrefix = `manual-${path}:${idempotencyKey}`;

        // Same replay guard as /purchases: the key is claimed inside the very
        // transaction that moves the money, so a retry returns the original
        // transfer and two concurrent retries can't both move it.
        const outcome = await withTransaction((client) =>
          withIdempotency(
            client,
            {
              childUserId,
              scope: `savings-${path}`,
              key: idempotencyKey,
              params: { amount },
            },
            async () => {
              await lockGoalOwner(client, childUserId);
              if (path === "deposit") await requireGoal(client, childUserId);
              const periodRes = await client.query<{
                opened_at: Date;
                required_need_amount: number;
              }>(
                `SELECT gp.opened_at, gp.required_need_amount
                   FROM game_periods gp
                   JOIN budget_plans bp ON bp.period_id = gp.id AND bp.status = 'CONFIRMED'
                  WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE'`,
                [childUserId],
              );
              const period = periodRes.rows[0];
              if (!period) {
                throw new HttpError(409, "active_day_with_confirmed_plan_required");
              }

              if (path === "deposit") {
                const stateRes = await client.query<{
                  balance: number;
                  need_spent: string;
                }>(
                  `SELECT w.balance,
                          COALESCE((SELECT SUM(p.total_price)
                                      FROM purchases p
                                      JOIN transactions t ON t.id = p.transaction_id
                                     WHERE p.child_user_id = $1 AND p.item_kind = 'NEED'
                                       AND t.occurred_at >= $2), 0)
                          + COALESCE((SELECT SUM(-t.delta_amount)
                                        FROM transactions t
                                       WHERE t.child_user_id = $1
                                         AND t.event_type = 'PET_EVENT_PAYMENT'
                                         AND t.occurred_at >= $2), 0) AS need_spent
                     FROM wallets w
                    WHERE w.child_user_id = $1 AND w.kind = 'SPENDABLE' FOR UPDATE`,
                  [childUserId, period.opened_at],
                );
                const state = stateRes.rows[0];
                const remainingReserve = Math.max(
                  period.required_need_amount - Number(state?.need_spent ?? 0),
                  0,
                );
                if ((state?.balance ?? 0) - amount < remainingReserve) {
                  throw new HttpError(409, "food_reserve_is_unavailable_for_savings");
                }
              }

              const result = await transferBetweenWallets(client, {
                childUserId,
                fromWallet: from,
                toWallet: to,
                amount,
                eventType: path === "deposit" ? "SAVINGS_DEPOSIT" : "SAVINGS_WITHDRAWAL",
                idempotencyKeyPrefix: keyPrefix,
              });
              await client.query(
                `UPDATE financial_goals g SET status = 'ACTIVE', achieved_at = NULL
                 WHERE g.child_user_id = $1 AND g.status = 'ACHIEVED'
                 AND g.target_amount > (SELECT balance FROM wallets WHERE child_user_id = $1 AND kind = 'SAVINGS')`,
                [childUserId],
              );
              return {
                ok: true,
                fromTransactionId: result.fromTxnId,
                toTransactionId: result.toTxnId,
              };
            },
          ),
        );

        reply.code(200).send({ ...outcome.result, replayed: outcome.replayed });
      },
    );
  }
}
