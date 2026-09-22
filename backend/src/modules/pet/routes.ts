import type { FastifyInstance } from "fastify";
import { pool } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";

// Minimal placeholder profanity/PII guard for the free-text pet name. Not a
// production moderation system — swap for a proper service later; this just
// demonstrates that every pet_name write is checked before it's stored.
const BLOCKED_SUBSTRINGS = ["дурак", "идиот"];

function screenPetName(name: string): { status: "APPROVED" | "FLAGGED"; reason: string | null } {
  const lowered = name.toLowerCase();
  const hit = BLOCKED_SUBSTRINGS.find((word) => lowered.includes(word));
  return hit ? { status: "FLAGGED", reason: "blocked_word" } : { status: "APPROVED", reason: null };
}

export async function petRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/cosmetic-options",
    { preHandler: [requireAuth] },
    async () => {
      const res = await pool.query(
        `SELECT id, kind, display_name, asset_code FROM cosmetic_options WHERE active ORDER BY kind, id`,
      );
      return res.rows;
    },
  );

  app.get(
    "/pet",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query(
        `SELECT id, pet_name, pet_name_status, fur_option_id, accessory_option_id,
                energy_level, joy_level, evolution_stage, successful_period_streak,
                equipped_inventory_item_id, created_at, updated_at
           FROM pets WHERE child_user_id = $1`,
        [req.authUser!.id],
      );
      const pet = res.rows[0];
      if (!pet) throw new HttpError(404, "pet_not_created");
      return pet;
    },
  );

  app.post<{ Body: { petName?: string; furOptionId?: string; accessoryOptionId?: string | null } }>(
    "/pet",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req, reply) => {
      const { petName, furOptionId } = req.body ?? {};
      const accessoryOptionId = req.body?.accessoryOptionId ?? null;
      if (!petName || petName.trim().length < 1 || petName.trim().length > 24) {
        throw new HttpError(400, "pet_name_must_be_1_to_24_chars");
      }
      if (!furOptionId) {
        throw new HttpError(400, "fur_option_id_required");
      }

      const screening = screenPetName(petName.trim());

      try {
        const res = await pool.query<{ id: string }>(
          `INSERT INTO pets
             (child_user_id, pet_name, pet_name_status, pet_name_flag_reason, fur_option_id, accessory_option_id)
           VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING id`,
          [
            req.authUser!.id,
            petName.trim(),
            screening.status,
            screening.reason,
            furOptionId,
            accessoryOptionId,
          ],
        );
        reply.code(201).send({ id: res.rows[0]!.id, petNameStatus: screening.status });
      } catch (err) {
        const pgErr = err as { code?: string; constraint?: string };
        if (pgErr.code === "23505") throw new HttpError(409, "pet_already_exists");
        if (pgErr.code === "23503") throw new HttpError(400, "invalid_cosmetic_option");
        throw err;
      }
    },
  );
}
