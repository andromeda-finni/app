import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction } from "../../lib/ledger.js";
import { assertActiveLink, requireAuth, requireRole } from "../../auth/plugin.js";
import { bodySchema, paramsSchema, uuidSchema } from "../../lib/schema.js";

// Real-life chores assigned by the parent (вынес мусор, помыл посуду, ...),
// confirmed by the parent — from behind the app's parent-gate (PIN/math
// captcha) on the client — before the reward is ever paid.
export async function parentTaskRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: { childUserId: string; title: string; rewardAmount: number } }>(
    "/parent/tasks",
    {
      preHandler: [requireAuth, requireRole("PARENT")],
      schema: bodySchema(
        {
          childUserId: uuidSchema,
          title: { type: "string", minLength: 1, maxLength: 160 },
          rewardAmount: { type: "integer", minimum: 1 },
        },
        ["childUserId", "title", "rewardAmount"],
      ),
    },
    async (req, reply) => {
      const parentUserId = req.authUser!.id;
      const { childUserId, title, rewardAmount } = req.body;
      await assertActiveLink(parentUserId, childUserId);

      const linkRes = await pool.query<{ id: string }>(
        `SELECT id FROM parent_child_links WHERE parent_user_id = $1 AND child_user_id = $2 AND status = 'ACTIVE'`,
        [parentUserId, childUserId],
      );

      const res = await pool.query<{ id: string }>(
        `INSERT INTO assignments (child_user_id, origin, assigned_by_parent_link_id, title, reward_amount, status)
         VALUES ($1, 'PARENT', $2, $3, $4, 'AVAILABLE') RETURNING id`,
        [childUserId, linkRes.rows[0]!.id, title.trim(), rewardAmount],
      );
      reply.code(201).send({ id: res.rows[0]!.id });
    },
  );

  app.get(
    "/child/tasks",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query(
        `SELECT id, title, reward_amount, status, created_at
           FROM assignments WHERE child_user_id = $1 AND origin = 'PARENT'
          ORDER BY created_at DESC`,
        [req.authUser!.id],
      );
      return res.rows;
    },
  );

  app.post<{ Params: { assignmentId: string } }>(
    "/child/tasks/:assignmentId/submit",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: paramsSchema({ assignmentId: uuidSchema }, ["assignmentId"]),
    },
    async (req) => {
      const res = await pool.query(
        `UPDATE assignments SET status = 'AWAITING_PARENT', updated_at = now()
          WHERE id = $1 AND child_user_id = $2 AND origin = 'PARENT' AND status IN ('AVAILABLE', 'IN_PROGRESS')
          RETURNING id`,
        [req.params.assignmentId, req.authUser!.id],
      );
      if (res.rowCount === 0) throw new HttpError(404, "task_not_found_or_not_submittable");
      return { ok: true };
    },
  );

  app.get(
    "/parent/tasks/pending",
    { preHandler: [requireAuth, requireRole("PARENT")] },
    async (req) => {
      const res = await pool.query(
        `SELECT a.id, a.child_user_id, a.title, a.reward_amount, a.updated_at
           FROM assignments a
           JOIN parent_child_links l ON l.id = a.assigned_by_parent_link_id
          WHERE l.parent_user_id = $1 AND l.status = 'ACTIVE' AND a.status = 'AWAITING_PARENT'
          ORDER BY a.updated_at`,
        [req.authUser!.id],
      );
      return res.rows;
    },
  );

  // The client is expected to have already passed the PIN/math parent-gate
  // before calling this — the backend's guarantee is that only a PARENT
  // token holding the ACTIVE link to this exact child can verify/pay it.
  app.post<{ Params: { assignmentId: string } }>(
    "/parent/tasks/:assignmentId/verify",
    {
      preHandler: [requireAuth, requireRole("PARENT")],
      schema: paramsSchema({ assignmentId: uuidSchema }, ["assignmentId"]),
    },
    async (req) => {
      const parentUserId = req.authUser!.id;
      const { assignmentId } = req.params;

      return withTransaction(async (client) => {
        const res = await client.query<{ child_user_id: string; reward_amount: number }>(
          `SELECT a.child_user_id, a.reward_amount
             FROM assignments a
             JOIN parent_child_links l ON l.id = a.assigned_by_parent_link_id
            WHERE a.id = $1 AND l.parent_user_id = $2 AND l.status = 'ACTIVE'
              AND a.origin = 'PARENT' AND a.status = 'AWAITING_PARENT'
            FOR UPDATE OF a`,
          [assignmentId, parentUserId],
        );
        const task = res.rows[0];
        if (!task) throw new HttpError(404, "task_not_found_or_not_awaiting_parent");

        const txn = await postTransaction(client, {
          childUserId: task.child_user_id,
          walletKind: "SPENDABLE",
          eventType: "PARENT_TASK_REWARD",
          deltaAmount: task.reward_amount,
          referenceType: "assignment",
          referenceId: assignmentId,
          idempotencyKey: `parent-task-reward:${assignmentId}`,
        });

        await client.query(
          `UPDATE assignments SET status = 'VERIFIED', reward_transaction_id = $1, updated_at = now() WHERE id = $2`,
          [txn.id, assignmentId],
        );

        return { ok: true, balanceAfter: txn.balanceAfter };
      });
    },
  );
}
