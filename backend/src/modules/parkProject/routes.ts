import type { FastifyInstance } from "fastify";
import type { PoolClient } from "pg";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { withIdempotency } from "../../lib/idempotency.js";
import { postTransaction } from "../../lib/ledger.js";
import { bodySchema, idempotencyKeySchema } from "../../lib/schema.js";

type ParkStage =
  | "FIRST_OFFER"
  | "WAITING_SECOND"
  | "SECOND_OFFER"
  | "WAITING_COMMUNITY"
  | "FUNDED"
  | "COMPLETE";

interface ParkRow {
  id: string;
  stage: ParkStage;
  stage_completed_days: number;
  funded_after_completed_days: number | null;
  child_contribution: number;
  first_decision: "CONTRIBUTE" | "DECLINE" | null;
  second_decision: "CONTRIBUTE" | "DECLINE" | null;
}

const TARGET_AMOUNT = 100;
const FIRST_COLLECTED = 80;
const SECOND_COLLECTED = 92;

async function completedDays(client: PoolClient, childUserId: string): Promise<number> {
  const result = await client.query<{ count: number }>(
    `SELECT COUNT(*)::int AS count FROM game_periods
      WHERE child_user_id = $1 AND status = 'COMPLETED'`,
    [childUserId],
  );
  return result.rows[0]?.count ?? 0;
}

async function assertParkUnlocked(client: PoolClient, childUserId: string): Promise<void> {
  const result = await client.query(
    `SELECT 1 FROM assignments
      WHERE child_user_id = $1 AND origin = 'SYSTEM'
        AND quest_id = 'Q_TUGRIKI_CURRENCY' AND status = 'COMPLETED'`,
    [childUserId],
  );
  if ((result.rowCount ?? 0) === 0) throw new HttpError(409, "park_quest_locked");
}

async function getOrCreateProject(
  client: PoolClient,
  childUserId: string,
  dayCount: number,
): Promise<ParkRow> {
  await client.query(
    `INSERT INTO park_projects (child_user_id, stage_completed_days)
     VALUES ($1, $2)
     ON CONFLICT (child_user_id) DO NOTHING`,
    [childUserId, dayCount],
  );
  const result = await client.query<ParkRow>(
    `SELECT id, stage, stage_completed_days, funded_after_completed_days,
            child_contribution, first_decision, second_decision
       FROM park_projects WHERE child_user_id = $1 FOR UPDATE`,
    [childUserId],
  );
  return result.rows[0]!;
}

async function advanceProject(
  client: PoolClient,
  row: ParkRow,
  dayCount: number,
): Promise<ParkRow> {
  const elapsed = Math.max(0, dayCount - row.stage_completed_days);
  let nextStage: ParkStage | null = null;
  let nextAnchor = row.stage_completed_days;
  let fundedAnchor: number | null = null;

  if (row.stage === "WAITING_SECOND" && elapsed >= 2) {
    nextStage = "FUNDED";
    nextAnchor = row.stage_completed_days + 2;
    fundedAnchor = nextAnchor;
  } else if (row.stage === "WAITING_SECOND" && elapsed >= 1) {
    nextStage = "SECOND_OFFER";
    nextAnchor = row.stage_completed_days + 1;
  } else if (row.stage === "SECOND_OFFER" && elapsed >= 1) {
    nextStage = "FUNDED";
    nextAnchor = row.stage_completed_days + 1;
    fundedAnchor = nextAnchor;
  } else if (row.stage === "WAITING_COMMUNITY" && elapsed >= 1) {
    nextStage = "FUNDED";
    nextAnchor = row.stage_completed_days + 1;
    fundedAnchor = nextAnchor;
  }

  if (nextStage === null) return row;
  const result = await client.query<ParkRow>(
    `UPDATE park_projects
        SET stage = $2, stage_completed_days = $3,
            funded_after_completed_days = $4, updated_at = now()
      WHERE id = $1
      RETURNING id, stage, stage_completed_days, funded_after_completed_days,
                child_contribution, first_decision, second_decision`,
    [row.id, nextStage, nextAnchor, fundedAnchor],
  );
  return result.rows[0]!;
}

async function safeSpendable(
  client: PoolClient,
  childUserId: string,
): Promise<{ balance: number; available: number }> {
  const result = await client.query<{ balance: number; remaining_reserve: number }>(
    `SELECT w.balance,
            GREATEST(0, COALESCE(active.required_need_amount, 0)
              - COALESCE(active.need_spent, 0))::int AS remaining_reserve
       FROM wallets w
       LEFT JOIN LATERAL (
         SELECT gp.required_need_amount,
                COALESCE((SELECT SUM(p.total_price)
                            FROM purchases p JOIN transactions t ON t.id = p.transaction_id
                           WHERE p.child_user_id = $1 AND p.item_kind = 'NEED'
                             AND t.occurred_at >= gp.opened_at), 0)
                + COALESCE((SELECT SUM(-t.delta_amount)
                              FROM transactions t
                             WHERE t.child_user_id = $1
                               AND t.event_type = 'PET_EVENT_PAYMENT'
                               AND t.occurred_at >= gp.opened_at), 0) AS need_spent
           FROM game_periods gp
          WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE'
       ) active ON true
      WHERE w.child_user_id = $1 AND w.kind = 'SPENDABLE'
      FOR UPDATE OF w`,
    [childUserId],
  );
  const balance = result.rows[0]?.balance ?? 0;
  const reserve = result.rows[0]?.remaining_reserve ?? 0;
  return { balance, available: Math.max(0, balance - reserve) };
}

function parkResponse(row: ParkRow, dayCount: number, balance: number, available: number) {
  const constructionDays = row.funded_after_completed_days === null
    ? 0
    : Math.max(0, dayCount - row.funded_after_completed_days);
  const scene = row.stage === "COMPLETE"
    ? "OPEN"
    : row.stage !== "FUNDED"
      ? row.stage
      : constructionDays >= 3
        ? "OPEN"
        : constructionDays === 2
          ? "ALMOST_READY"
          : constructionDays === 1
            ? "BUILDING"
            : "FUNDED";
  const offerAmount = row.stage === "FIRST_OFFER" ? 20 : row.stage === "SECOND_OFFER" ? 8 : null;
  const collectedAmount = row.stage === "FIRST_OFFER" || row.stage === "WAITING_SECOND"
    ? FIRST_COLLECTED
    : row.stage === "SECOND_OFFER"
      ? SECOND_COLLECTED
      : TARGET_AMOUNT;
  return {
    stage: row.stage,
    scene,
    targetAmount: TARGET_AMOUNT,
    collectedAmount,
    offerAmount,
    spendableBalance: balance,
    availableToContribute: available,
    canContribute: offerAmount !== null && available >= offerAmount,
    childContribution: row.child_contribution,
    completed: row.stage === "COMPLETE",
    daysToNextStage: row.stage === "FUNDED" && constructionDays < 3
      ? 1
      : row.stage === "WAITING_SECOND" || row.stage === "WAITING_COMMUNITY"
        ? 1
        : null,
  };
}

async function loadState(client: PoolClient, childUserId: string) {
  await assertParkUnlocked(client, childUserId);
  const dayCount = await completedDays(client, childUserId);
  let row = await getOrCreateProject(client, childUserId, dayCount);
  row = await advanceProject(client, row, dayCount);
  const money = await safeSpendable(client, childUserId);
  return { row, dayCount, money };
}

export async function parkProjectRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/park-project",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => withTransaction(async (client) => {
      const state = await loadState(client, req.authUser!.id);
      return parkResponse(state.row, state.dayCount, state.money.balance, state.money.available);
    }),
  );

  app.post<{
    Body: {
      offer: "FIRST" | "SECOND";
      decision: "CONTRIBUTE" | "DECLINE";
      idempotencyKey: string;
    };
  }>(
    "/park-project/decision",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: bodySchema(
        {
          offer: { type: "string", enum: ["FIRST", "SECOND"] },
          decision: { type: "string", enum: ["CONTRIBUTE", "DECLINE"] },
          idempotencyKey: idempotencyKeySchema,
        },
        ["offer", "decision", "idempotencyKey"],
      ),
    },
    async (req) => withTransaction(async (client) => {
      const childUserId = req.authUser!.id;
      const { offer, decision, idempotencyKey } = req.body;
      const outcome = await withIdempotency(
        client,
        {
          childUserId,
          scope: "park-project-decision",
          key: idempotencyKey,
          params: { offer, decision },
        },
        async () => {
          const state = await loadState(client, childUserId);
          const expectedStage = offer === "FIRST" ? "FIRST_OFFER" : "SECOND_OFFER";
          if (state.row.stage !== expectedStage) throw new HttpError(409, "park_offer_changed");
          const amount = offer === "FIRST" ? 20 : 8;
          if (decision === "CONTRIBUTE" && state.money.available < amount) {
            throw new HttpError(409, "park_contribution_would_use_need_reserve");
          }

          let balance = state.money.balance;
          if (decision === "CONTRIBUTE") {
            const transaction = await postTransaction(client, {
              childUserId,
              walletKind: "SPENDABLE",
              eventType: "PARK_CONTRIBUTION",
              deltaAmount: -amount,
              referenceType: "park_project",
              referenceId: state.row.id,
              idempotencyKey: `park-contribution:${idempotencyKey}`,
            });
            balance = transaction.balanceAfter;
          }

          const nextStage: ParkStage = decision === "CONTRIBUTE"
            ? "FUNDED"
            : offer === "FIRST"
              ? "WAITING_SECOND"
              : "WAITING_COMMUNITY";
          const updated = await client.query<ParkRow>(
            `UPDATE park_projects
                SET stage = $2, stage_completed_days = $3,
                    funded_after_completed_days = $4,
                    child_contribution = child_contribution + $5,
                    first_decision = CASE WHEN $6 = 'FIRST' THEN $7 ELSE first_decision END,
                    second_decision = CASE WHEN $6 = 'SECOND' THEN $7 ELSE second_decision END,
                    updated_at = now()
              WHERE id = $1
              RETURNING id, stage, stage_completed_days, funded_after_completed_days,
                        child_contribution, first_decision, second_decision`,
            [
              state.row.id,
              nextStage,
              state.dayCount,
              decision === "CONTRIBUTE" ? state.dayCount : null,
              decision === "CONTRIBUTE" ? amount : 0,
              offer,
              decision,
            ],
          );
          return parkResponse(
            updated.rows[0]!,
            state.dayCount,
            balance,
            Math.max(0, state.money.available - (decision === "CONTRIBUTE" ? amount : 0)),
          );
        },
      );
      return { ...outcome.result, replayed: outcome.replayed };
    }),
  );

  app.post<{ Body: { idempotencyKey: string } }>(
    "/park-project/complete",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: bodySchema({ idempotencyKey: idempotencyKeySchema }, ["idempotencyKey"]),
    },
    async (req) => withTransaction(async (client) => {
      const childUserId = req.authUser!.id;
      const outcome = await withIdempotency(
        client,
        {
          childUserId,
          scope: "park-project-complete",
          key: req.body.idempotencyKey,
          params: {},
        },
        async () => {
          const state = await loadState(client, childUserId);
          const view = parkResponse(
            state.row,
            state.dayCount,
            state.money.balance,
            state.money.available,
          );
          if (view.scene !== "OPEN") throw new HttpError(409, "park_not_open_yet");
          const updated = await client.query<ParkRow>(
            `UPDATE park_projects
                SET stage = 'COMPLETE', completed_at = now(), updated_at = now()
              WHERE id = $1 AND stage <> 'COMPLETE'
              RETURNING id, stage, stage_completed_days, funded_after_completed_days,
                        child_contribution, first_decision, second_decision`,
            [state.row.id],
          );
          return parkResponse(
            updated.rows[0] ?? state.row,
            state.dayCount,
            state.money.balance,
            state.money.available,
          );
        },
      );
      return { ...outcome.result, replayed: outcome.replayed };
    }),
  );
}
