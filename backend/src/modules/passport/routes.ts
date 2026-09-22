import type { FastifyInstance } from "fastify";
import { pool } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";

// "Цифровой паспорт" — a shareable read-only summary card the child can show
// off to friends, instead of a real-time PvP mode (out of scope by design —
// see brief's antipattern list). Purely computed from existing data, no
// dedicated table: nothing here can be forged or drifts out of sync.
export async function passportRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/child/passport",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const childUserId = req.authUser!.id;

      const petRes = await pool.query(
        `SELECT pet_name, evolution_stage, successful_period_streak, fur_option_id, accessory_option_id
           FROM pets WHERE child_user_id = $1`,
        [childUserId],
      );
      const pet = petRes.rows[0];
      if (!pet) throw new HttpError(404, "pet_not_created");

      const questsRes = await pool.query<{ count: string }>(
        `SELECT COUNT(*) FROM assignments WHERE child_user_id = $1 AND origin = 'SYSTEM' AND status = 'COMPLETED'`,
        [childUserId],
      );
      const periodsRes = await pool.query<{ count: string }>(
        `SELECT COUNT(*) FROM period_results WHERE child_user_id = $1 AND plan_followed = true`,
        [childUserId],
      );
      const inventoryRes = await pool.query<{ count: string }>(
        `SELECT COUNT(*) FROM inventory_items WHERE child_user_id = $1`,
        [childUserId],
      );

      return {
        petName: pet.pet_name,
        evolutionStage: pet.evolution_stage,
        currentStreak: pet.successful_period_streak,
        furOptionId: pet.fur_option_id,
        accessoryOptionId: pet.accessory_option_id,
        questsCompleted: Number(questsRes.rows[0]?.count ?? 0),
        successfulPeriods: Number(periodsRes.rows[0]?.count ?? 0),
        artifactsCollected: Number(inventoryRes.rows[0]?.count ?? 0),
      };
    },
  );
}
