import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { bodySchema, paramsSchema, shortIdSchema, uuidSchema } from "../../lib/schema.js";
import { lockGoalOwner } from "../economy/goals.js";

export async function goalRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/goals/active",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const childUserId = req.authUser!.id;

      // Lazily promote ACTIVE -> ACHIEVED once SAVINGS covers the target —
      // cheap enough to check on every read, no scheduled job needed.
      await pool.query(
        `UPDATE financial_goals g
            SET status = 'ACHIEVED', achieved_at = now()
          WHERE g.child_user_id = $1 AND g.status = 'ACTIVE'
            AND g.target_amount <= (SELECT balance FROM wallets WHERE child_user_id = $1 AND kind = 'SAVINGS')`,
        [childUserId],
      );

      const res = await pool.query(
        `SELECT id, target_item_id, target_amount, status, selected_at, achieved_at
           FROM financial_goals
          WHERE child_user_id = $1 AND status IN ('ACTIVE', 'PAUSED', 'ACHIEVED')`,
        [childUserId],
      );
      return res.rows[0] ?? null;
    },
  );

  app.post<{ Body: { targetItemId: string } }>(
    "/goals",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: bodySchema({ targetItemId: shortIdSchema }, ["targetItemId"]),
    },
    async (req, reply) => {
      const childUserId = req.authUser!.id;
      const { targetItemId } = req.body;

      const result = await withTransaction(async (client) => {
        await lockGoalOwner(client, childUserId);

        const itemRes = await client.query<{ price: number }>(
          `SELECT price FROM shop_items WHERE id = $1 AND kind = 'ARTIFACT' AND active`,
          [targetItemId],
        );
        const item = itemRes.rows[0];
        if (!item) throw new HttpError(404, "artifact_not_found");

        const currentRes = await client.query<{ id: string; target_item_id: string }>(
          `SELECT id, target_item_id FROM financial_goals
            WHERE child_user_id = $1 AND status IN ('ACTIVE','PAUSED','ACHIEVED')
            FOR UPDATE`,
          [childUserId],
        );
        const current = currentRes.rows[0];
        if (current?.target_item_id === targetItemId) {
          return { id: current.id, targetAmount: item.price, replayed: true };
        }
        if (current) {
          throw new HttpError(409, "goal_change_not_allowed");
        }

        const owned = await client.query(
          `SELECT 1 FROM inventory_items WHERE child_user_id = $1 AND item_id = $2`,
          [childUserId, targetItemId],
        );
        if (owned.rowCount) throw new HttpError(409, "artifact_already_owned");

        const res = await client.query<{ id: string }>(
          `INSERT INTO financial_goals (child_user_id, target_item_id, target_amount)
           VALUES ($1, $2, $3) RETURNING id`,
          [childUserId, targetItemId, item.price],
        );
        return { id: res.rows[0]!.id, targetAmount: item.price, replayed: false };
      });

      reply.code(result.replayed ? 200 : 201).send(result);
    },
  );

  for (const path of ["pause", "resume", "cancel"] as const) {
    app.post<{ Params: { goalId: string } }>(
      `/goals/:goalId/${path}`,
      {
        preHandler: [requireAuth, requireRole("CHILD")],
        schema: paramsSchema({ goalId: uuidSchema }, ["goalId"]),
      },
      async () => {
        throw new HttpError(409, "goal_change_not_allowed");
      },
    );
  }

  app.post<{ Params: { goalId: string } }>(
    "/goals/:goalId/redeem",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: paramsSchema({ goalId: uuidSchema }, ["goalId"]),
    },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { goalId } = req.params;

      return withTransaction(async (client) => {
        await lockGoalOwner(client, childUserId);
        const dayRes = await client.query(
          `SELECT 1 FROM game_periods gp
            JOIN budget_plans bp ON bp.period_id = gp.id AND bp.status = 'CONFIRMED'
           WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE'`,
          [childUserId],
        );
        if ((dayRes.rowCount ?? 0) === 0) {
          throw new HttpError(409, "active_day_with_confirmed_plan_required");
        }

        const goalRes = await client.query<{ target_item_id: string; target_amount: number; status: string }>(
          `SELECT target_item_id, target_amount, status FROM financial_goals
            WHERE id = $1 AND child_user_id = $2 AND status IN ('ACTIVE','PAUSED','ACHIEVED','REDEEMED') FOR UPDATE`,
          [goalId, childUserId],
        );
        const goal = goalRes.rows[0];
        if (!goal) throw new HttpError(404, "achieved_goal_not_found");
        if (goal.status === 'REDEEMED') return { ok: true, replayed: true };

        const txn = await postTransaction(client, {
          childUserId,
          walletKind: "SAVINGS",
          eventType: "GOAL_REDEMPTION",
          deltaAmount: -goal.target_amount,
          referenceType: "financial_goal",
          referenceId: goalId,
          idempotencyKey: `goal-redeem:${goalId}`,
        });

        await client.query(
          `UPDATE financial_goals SET status = 'REDEEMED', achieved_at = COALESCE(achieved_at, now()), redeemed_at = now(), redemption_transaction_id = $1 WHERE id = $2`,
          [txn.id, goalId],
        );

        const invRes = await client.query<{ id: string }>(
          `INSERT INTO inventory_items (child_user_id, item_id, financial_goal_id)
           VALUES ($1, $2, $3) RETURNING id`,
          [childUserId, goal.target_item_id, goalId],
        );

        return { ok: true, inventoryItemId: invRes.rows[0]!.id };
      });
    },
  );

  app.get(
    "/inventory",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query(
        `SELECT i.id, i.item_id, s.name, s.rarity, i.acquired_at,
                (p.equipped_inventory_item_id = i.id) AS equipped
           FROM inventory_items i
           JOIN shop_items s ON s.id = i.item_id
           LEFT JOIN pets p ON p.child_user_id = i.child_user_id
          WHERE i.child_user_id = $1
          ORDER BY i.acquired_at DESC`,
        [req.authUser!.id],
      );
      return res.rows;
    },
  );

  app.post<{ Body: { inventoryItemId?: string | null } }>(
    "/pet/equip",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: bodySchema({ inventoryItemId: { type: ["string", "null"], format: "uuid" } }),
    },
    async (req) => {
      const childUserId = req.authUser!.id;
      const inventoryItemId = req.body?.inventoryItemId ?? null;

      if (inventoryItemId) {
        const owns = await pool.query(
          `SELECT 1 FROM inventory_items WHERE id = $1 AND child_user_id = $2`,
          [inventoryItemId, childUserId],
        );
        if (owns.rowCount === 0) throw new HttpError(403, "item_not_owned");
      }

      await pool.query(
        `UPDATE pets SET equipped_inventory_item_id = $1, updated_at = now() WHERE child_user_id = $2`,
        [inventoryItemId, childUserId],
      );
      return { ok: true };
    },
  );
}
