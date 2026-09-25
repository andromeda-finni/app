import type { FastifyInstance } from "fastify";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { pool } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { ECONOMY_RULES, dayOfWeek, weekForDay } from "./rules.js";

/**
 * Read model for the real child-facing economy screen. Mutations stay in the
 * focused route modules; this endpoint hides their storage layout from Flutter.
 */
export async function economyRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/economy/state",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const childUserId = req.authUser!.id;
      const profileRes = await pool.query<{ mode: "STANDARD" | "DEMO" }>(
        `SELECT mode FROM child_profiles WHERE user_id = $1`,
        [childUserId],
      );
      const profile = profileRes.rows[0];
      if (!profile) throw new HttpError(404, "child_profile_not_found");
      if (profile.mode !== "STANDARD") {
        throw new HttpError(409, "standard_profile_required");
      }

      await pool.query(
        `UPDATE financial_goals g
            SET status = 'ACHIEVED', achieved_at = now()
          WHERE g.child_user_id = $1 AND g.status = 'ACTIVE'
            AND g.target_amount <= (
              SELECT balance FROM wallets
               WHERE child_user_id = $1 AND kind = 'SAVINGS'
            )`,
        [childUserId],
      );

      const [petRes, walletsRes, dayRes, eventRes, goalRes, frostRes, shopRes, artifactRes, inventoryRes, transactionsRes, historyRes, questsRes, tasksRes] =
        await Promise.all([
          pool.query(
            `SELECT id, pet_name, fur_option_id, energy_level, joy_level, health_level, evolution_stage
               FROM pets WHERE child_user_id = $1`,
            [childUserId],
          ),
          pool.query<{ kind: string; balance: number }>(
            `SELECT kind, balance FROM wallets WHERE child_user_id = $1`,
            [childUserId],
          ),
          pool.query(
            `SELECT gp.id, gp.sequence_no, gp.required_need_amount,
                    bp.id AS budget_plan_id, bp.status AS budget_plan_status, bp.available_amount,
                    bp.need_amount, bp.want_amount, bp.savings_amount,
                    GREATEST(0, gp.required_need_amount
                      - COALESCE((SELECT SUM(p.total_price) FROM purchases p
                          JOIN transactions t ON t.id = p.transaction_id
                          WHERE p.child_user_id = $1 AND p.item_kind = 'NEED' AND t.occurred_at >= gp.opened_at), 0)
                      - COALESCE((SELECT SUM(-t.delta_amount) FROM transactions t
                          WHERE t.child_user_id = $1 AND t.event_type = 'PET_EVENT_PAYMENT' AND t.occurred_at >= gp.opened_at), 0)
                    )::int AS remaining_reserve
               FROM game_periods gp
               JOIN budget_plans bp ON bp.period_id = gp.id
              WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE'`,
            [childUserId],
          ),
          pool.query(
            `SELECT peo.id, peo.amount_due, ped.title, ped.description
               FROM pet_event_occurrences peo
               JOIN pet_event_definitions ped ON ped.id = peo.event_definition_id
              WHERE peo.child_user_id = $1 AND peo.status = 'ACTIVE'`,
            [childUserId],
          ),
          pool.query(
            `SELECT g.id, g.target_item_id, g.target_amount, g.status,
                    s.name,
                    GREATEST(g.target_amount - w.balance, 0) AS remaining_amount
               FROM financial_goals g
               JOIN shop_items s ON s.id = g.target_item_id
               JOIN wallets w ON w.child_user_id = g.child_user_id AND w.kind = 'SAVINGS'
              WHERE g.child_user_id = $1 AND g.status IN ('ACTIVE','PAUSED','ACHIEVED')`,
            [childUserId],
          ),
          pool.query(
            `SELECT fc.id, fc.principal_amount, fc.bonus_amount, fc.opened_at,
                    COUNT(gp.id)::int AS completed_days
               FROM frost_chests fc
               LEFT JOIN game_periods gp ON gp.child_user_id = fc.child_user_id
                AND gp.status = 'COMPLETED' AND gp.closed_at >= fc.opened_at
              WHERE fc.child_user_id = $1 AND fc.status = 'ACTIVE'
              GROUP BY fc.id`,
            [childUserId],
          ),
          pool.query(
            `SELECT id, kind, name, price FROM shop_items
              WHERE active AND kind IN ('NEED','WANT') ORDER BY kind, price`,
          ),
          pool.query(
            `SELECT id, name, price, rarity FROM shop_items s
              WHERE active AND kind = 'ARTIFACT'
                AND NOT EXISTS (SELECT 1 FROM inventory_items i WHERE i.child_user_id = $1 AND i.item_id = s.id)
              ORDER BY price`,
            [childUserId],
          ),
          pool.query(
            `SELECT i.id, i.item_id, s.name, s.rarity,
                    (p.equipped_inventory_item_id = i.id) AS equipped
               FROM inventory_items i
               JOIN shop_items s ON s.id = i.item_id
               LEFT JOIN pets p ON p.child_user_id = i.child_user_id
              WHERE i.child_user_id = $1 ORDER BY i.acquired_at DESC`,
            [childUserId],
          ),
          pool.query(
            `SELECT wallet_kind, event_type, delta_amount, balance_after, occurred_at
               FROM transactions WHERE child_user_id = $1
              ORDER BY occurred_at DESC LIMIT 12`,
            [childUserId],
          ),
          pool.query<{
            sequence_no: number;
            actual_need_amount: number;
            actual_want_amount: number;
            net_savings_contribution: number;
            plan_followed: boolean;
            feedback_text: string;
          }>(
            `SELECT gp.sequence_no, pr.actual_need_amount, pr.actual_want_amount,
                    pr.net_savings_contribution, pr.plan_followed, pr.feedback_text
               FROM period_results pr
               JOIN game_periods gp ON gp.id = pr.period_id
              WHERE pr.child_user_id = $1 ORDER BY gp.sequence_no DESC LIMIT 7`,
            [childUserId],
          ),
          pool.query(
            `SELECT q.id, q.title, q.reward_amount,
                    a.id AS assignment_id, a.status AS assignment_status
               FROM quest_definitions q
               JOIN child_profiles cp ON cp.user_id = $1 AND cp.difficulty = q.difficulty
               LEFT JOIN LATERAL (
                 SELECT id, status FROM assignments
                  WHERE child_user_id = $1 AND origin = 'SYSTEM' AND quest_id = q.id
                  ORDER BY created_at DESC LIMIT 1
               ) a ON true
              WHERE q.active ORDER BY q.id`,
            [childUserId],
          ),
          pool.query(
            `SELECT id, title, reward_amount, status
               FROM assignments WHERE child_user_id = $1 AND origin = 'PARENT'
              ORDER BY created_at DESC LIMIT 10`,
            [childUserId],
          ),
        ]);

      const day = dayRes.rows[0] as Record<string, unknown> | undefined;
      if (day) {
        const sequence = Number(day.sequence_no);
        day.week = weekForDay(sequence);
        day.day_of_week = dayOfWeek(sequence);
      }

      const frost = frostRes.rows[0] as Record<string, unknown> | undefined;
      if (frost) {
        const completedDays = Number(frost.completed_days);
        frost.maturity_days = ECONOMY_RULES.frostDays;
        frost.days_remaining = Math.max(0, ECONOMY_RULES.frostDays - completedDays);
        frost.matured = completedDays >= ECONOMY_RULES.frostDays;
      }

      const history = historyRes.rows.map((row) => ({
        ...row,
        week: weekForDay(row.sequence_no),
        dayOfWeek: dayOfWeek(row.sequence_no),
      }));

      return {
        mode: profile.mode,
        rules: ECONOMY_RULES,
        pet: petRes.rows[0] ?? null,
        wallets: Object.fromEntries(walletsRes.rows.map((row) => [row.kind, row.balance])),
        activeDay: day ?? null,
        activeEvent: eventRes.rows[0] ?? null,
        activeGoal: goalRes.rows[0] ?? null,
        activeFrostChest: frost ?? null,
        shopItems: shopRes.rows,
        artifacts: artifactRes.rows,
        inventory: inventoryRes.rows,
        quests: questsRes.rows,
        parentTasks: tasksRes.rows,
        recentTransactions: transactionsRes.rows,
        recentDays: history,
      };
    },
  );
}
