import type { FastifyInstance } from "fastify";
import { pool } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { assertActiveLink, requireAuth, requireRole } from "../../auth/plugin.js";
import { paramsSchema, uuidSchema } from "../../lib/schema.js";
import { ECONOMY_RULES } from "../economy/rules.js";

/**
 * Read-only view of a child's progress for a linked parent.
 *
 * Every read is gated on an ACTIVE parent_child_links row, created only when
 * the child redeems the parent's invite code. Nothing here can change the
 * child's money or pet; parents act through /parent/tasks.
 */
export async function parentViewRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/parent/children",
    { preHandler: [requireAuth, requireRole("PARENT")] },
    async (req) => {
      const res = await pool.query<{ child_user_id: string; pet_name: string | null; linked_at: Date }>(
        `SELECT l.child_user_id, p.pet_name, l.linked_at
           FROM parent_child_links l
           LEFT JOIN pets p ON p.child_user_id = l.child_user_id
          WHERE l.parent_user_id = $1 AND l.status = 'ACTIVE'
          ORDER BY l.linked_at`,
        [req.authUser!.id],
      );
      return res.rows.map((row) => ({
        childUserId: row.child_user_id,
        petName: row.pet_name,
        linkedAt: row.linked_at,
      }));
    },
  );

  app.get<{ Params: { childUserId: string } }>(
    "/parent/children/:childUserId/overview",
    {
      preHandler: [requireAuth, requireRole("PARENT")],
      schema: paramsSchema({ childUserId: uuidSchema }, ["childUserId"]),
    },
    async (req) => {
      const { childUserId } = req.params;
      await assertActiveLink(req.authUser!.id, childUserId);

      const [pet, wallets, goal, day, event, quests, days, results, activity, parentTasks] = await Promise.all([
        pool.query(
          `SELECT pet_name, evolution_stage, energy_level, joy_level, health_level
             FROM pets WHERE child_user_id = $1`,
          [childUserId],
        ),
        pool.query<{ kind: string; balance: number }>(
          `SELECT kind, balance FROM wallets WHERE child_user_id = $1`,
          [childUserId],
        ),
        pool.query(
          `SELECT s.name, g.target_amount, w.balance AS saved_amount, g.status
             FROM financial_goals g
             JOIN shop_items s ON s.id = g.target_item_id
             JOIN wallets w ON w.child_user_id = g.child_user_id AND w.kind = 'SAVINGS'
            WHERE g.child_user_id = $1 AND g.status IN ('ACTIVE','PAUSED','ACHIEVED')`,
          [childUserId],
        ),
        pool.query(
          `SELECT gp.sequence_no, bp.status AS plan_status,
                  bp.need_amount, bp.want_amount, bp.savings_amount
             FROM game_periods gp
             JOIN budget_plans bp ON bp.period_id = gp.id
            WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE'`,
          [childUserId],
        ),
        pool.query(
          `SELECT ped.title, peo.amount_due
             FROM pet_event_occurrences peo
             JOIN pet_event_definitions ped ON ped.id = peo.event_definition_id
            WHERE peo.child_user_id = $1 AND peo.status = 'ACTIVE'`,
          [childUserId],
        ),
        pool.query(
          `SELECT q.title, a.updated_at AS completed_at,
                  EXISTS (SELECT 1 FROM quest_step_progress sp
                           WHERE sp.assignment_id = a.id AND sp.outcome = 'RECOVERABLE_ERROR') AS needed_hints
             FROM assignments a
             JOIN quest_definitions q ON q.id = a.quest_id
            WHERE a.child_user_id = $1 AND a.origin = 'SYSTEM' AND a.status = 'COMPLETED'
            ORDER BY a.updated_at DESC`,
          [childUserId],
        ),
        pool.query<{ finished: number; followed: number }>(
          `SELECT COUNT(*)::int AS finished,
                  COUNT(*) FILTER (WHERE plan_followed)::int AS followed
             FROM period_results WHERE child_user_id = $1`,
          [childUserId],
        ),
        pool.query(
          `SELECT gp.sequence_no, r.plan_followed, r.need_covered, r.feedback_text, r.calculated_at
             FROM period_results r
             JOIN game_periods gp ON gp.id = r.period_id
            WHERE r.child_user_id = $1
            ORDER BY r.calculated_at DESC LIMIT 5`,
          [childUserId],
        ),
        pool.query(
          `SELECT event_type, wallet_kind, delta_amount, occurred_at
             FROM transactions WHERE child_user_id = $1
            ORDER BY occurred_at DESC LIMIT 12`,
          [childUserId],
        ),
        pool.query(
          `SELECT a.id, a.title, a.reward_amount, a.status, a.updated_at
             FROM assignments a
             JOIN parent_child_links l ON l.id = a.assigned_by_parent_link_id
            WHERE a.child_user_id = $1 AND a.origin = 'PARENT'
              AND l.parent_user_id = $2 AND l.status = 'ACTIVE'
            ORDER BY a.created_at DESC LIMIT 10`,
          [childUserId, req.authUser!.id],
        ),
      ]);

      // A linked child always has a pet unless onboarding was abandoned; say
      // so explicitly rather than rendering an empty dashboard.
      if (!pet.rows[0]) throw new HttpError(404, "child_has_no_pet_yet");

      return {
        pet: pet.rows[0],
        wallets: Object.fromEntries(wallets.rows.map((row) => [row.kind, row.balance])),
        goal: goal.rows[0] ?? null,
        activeDay: day.rows[0] ?? null,
        activeEvent: event.rows[0] ?? null,
        completedQuests: quests.rows,
        days: days.rows[0] ?? { finished: 0, followed: 0 },
        recentDays: results.rows,
        recentActivity: activity.rows,
        parentTasks: parentTasks.rows,
        rules: { parentRewardLimit: ECONOMY_RULES.parentRewardLimit },
      };
    },
  );

  app.get(
    "/child/parent-link",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query<{ linked_at: Date }>(
        `SELECT linked_at FROM parent_child_links
          WHERE child_user_id = $1 AND status = 'ACTIVE'
          ORDER BY linked_at LIMIT 1`,
        [req.authUser!.id],
      );
      const link = res.rows[0];
      return { linked: Boolean(link), linkedAt: link?.linked_at ?? null };
    },
  );
}
