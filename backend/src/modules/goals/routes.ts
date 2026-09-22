import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";

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

  app.post<{ Body: { targetItemId?: string } }>(
    "/goals",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req, reply) => {
      const childUserId = req.authUser!.id;
      const targetItemId = req.body?.targetItemId;
      if (!targetItemId) throw new HttpError(400, "targetItemId_required");

      const itemRes = await pool.query<{ price: number }>(
        `SELECT price FROM shop_items WHERE id = $1 AND kind = 'ARTIFACT' AND active`,
        [targetItemId],
      );
      const item = itemRes.rows[0];
      if (!item) throw new HttpError(404, "artifact_not_found");

      try {
        const res = await pool.query<{ id: string }>(
          `INSERT INTO financial_goals (child_user_id, target_item_id, target_amount)
           VALUES ($1, $2, $3) RETURNING id`,
          [childUserId, targetItemId, item.price],
        );
        reply.code(201).send({ id: res.rows[0]!.id, targetAmount: item.price });
      } catch (err) {
        const pgErr = err as { code?: string };
        if (pgErr.code === "23505") throw new HttpError(409, "goal_already_open");
        throw err;
      }
    },
  );

  for (const [path, toStatus] of [
    ["pause", "PAUSED"],
    ["resume", "ACTIVE"],
    ["cancel", "CANCELLED"],
  ] as const) {
    app.post<{ Params: { goalId: string } }>(
      `/goals/:goalId/${path}`,
      { preHandler: [requireAuth, requireRole("CHILD")] },
      async (req) => {
        const fromStatuses = toStatus === "CANCELLED" ? "('ACTIVE','PAUSED')" : toStatus === "PAUSED" ? "('ACTIVE')" : "('PAUSED')";
        const res = await pool.query(
          `UPDATE financial_goals
              SET status = $1${toStatus === "CANCELLED" ? ", cancelled_at = now()" : ""}
            WHERE id = $2 AND child_user_id = $3 AND status IN ${fromStatuses}
            RETURNING id`,
          [toStatus, req.params.goalId, req.authUser!.id],
        );
        if (res.rowCount === 0) throw new HttpError(409, "goal_not_in_a_valid_state_for_this_action");
        return { ok: true };
      },
    );
  }

  app.post<{ Params: { goalId: string } }>(
    "/goals/:goalId/redeem",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { goalId } = req.params;

      return withTransaction(async (client) => {
        const goalRes = await client.query<{ target_item_id: string; target_amount: number }>(
          `SELECT target_item_id, target_amount FROM financial_goals
            WHERE id = $1 AND child_user_id = $2 AND status = 'ACHIEVED' FOR UPDATE`,
          [goalId, childUserId],
        );
        const goal = goalRes.rows[0];
        if (!goal) throw new HttpError(404, "achieved_goal_not_found");

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
          `UPDATE financial_goals SET status = 'REDEEMED', redeemed_at = now(), redemption_transaction_id = $1 WHERE id = $2`,
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
    { preHandler: [requireAuth, requireRole("CHILD")] },
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
