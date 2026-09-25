import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { bodySchema, shortIdSchema } from "../../lib/schema.js";

// Minimal placeholder profanity/PII guard for the free-text pet name. Not a
// production moderation system — swap for a proper service later; this just
// demonstrates that every pet_name write is checked before it's stored.
const BLOCKED_SUBSTRINGS = ["дурак", "идиот"];

interface PetWriteBody {
  petName: string;
  furOptionId: string;
  accessoryOptionId?: string | null;
}

const petWriteSchema = bodySchema(
  {
    petName: { type: "string", minLength: 1, maxLength: 24 },
    furOptionId: shortIdSchema,
    accessoryOptionId: { type: ["string", "null"], minLength: 1, maxLength: 50 },
  },
  ["petName", "furOptionId"],
);

function screenPetName(name: string): { status: "APPROVED" | "FLAGGED"; reason: string | null } {
  const lowered = name.toLowerCase();
  const hit = BLOCKED_SUBSTRINGS.find((word) => lowered.includes(word));
  return hit ? { status: "FLAGGED", reason: "blocked_word" } : { status: "APPROVED", reason: null };
}

function normalizePetWrite(body: PetWriteBody) {
  const petName = body.petName.trim();
  if (petName.length < 1) {
    throw new HttpError(400, "pet_name_must_be_1_to_24_chars");
  }
  return {
    petName,
    furOptionId: body.furOptionId,
    accessoryOptionId: body.accessoryOptionId ?? null,
    screening: screenPetName(petName),
  };
}

function rethrowPetWriteError(err: unknown): never {
  const pgErr = err as { code?: string; constraint?: string };
  if (pgErr.code === "23503") throw new HttpError(400, "invalid_cosmetic_option");
  throw err;
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
                energy_level, joy_level, health_level, evolution_stage,
                successful_period_streak, equipped_inventory_item_id,
                created_at, updated_at
           FROM pets WHERE child_user_id = $1`,
        [req.authUser!.id],
      );
      const pet = res.rows[0];
      if (!pet) throw new HttpError(404, "pet_not_created");
      return pet;
    },
  );

  app.post<{ Body: PetWriteBody }>(
    "/pet",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: petWriteSchema,
    },
    async (req, reply) => {
      const { petName, furOptionId, accessoryOptionId, screening } = normalizePetWrite(req.body);

      try {
        const petId = await withTransaction(async (client) => {
          const res = await client.query<{ id: string }>(
            `INSERT INTO pets
               (child_user_id, pet_name, pet_name_status, pet_name_flag_reason, fur_option_id, accessory_option_id)
             VALUES ($1, $2, $3, $4, $5, $6)
             RETURNING id`,
            [
              req.authUser!.id,
              petName,
              screening.status,
              screening.reason,
              furOptionId,
              accessoryOptionId,
            ],
          );
          await client.query(
            `UPDATE child_profiles
                SET onboarding_step = GREATEST(onboarding_step, 2), updated_at = now()
              WHERE user_id = $1`,
            [req.authUser!.id],
          );
          return res.rows[0]!.id;
        });
        reply.code(201).send({ id: petId, petNameStatus: screening.status });
      } catch (err) {
        const pgErr = err as { code?: string; constraint?: string };
        // The uniqueness rule is one pet per child, never a globally unique
        // pet name. Different children may choose the same name.
        if (pgErr.code === "23505" && pgErr.constraint === "pets_child_user_id_key") {
          throw new HttpError(409, "child_already_has_pet");
        }
        rethrowPetWriteError(err);
      }
    },
  );

  // PUT models the singleton pet resource for a child. It is intentionally
  // idempotent: the first onboarding submit creates the pet, while returning
  // to step 1 and submitting again replaces only the editable identity fields
  // on that same authenticated child's pet. Progress/economy fields remain
  // untouched, and retries cannot create a second row.
  app.put<{ Body: PetWriteBody }>(
    "/pet",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: petWriteSchema,
    },
    async (req, reply) => {
      const { petName, furOptionId, accessoryOptionId, screening } = normalizePetWrite(req.body);

      try {
        const petId = await withTransaction(async (client) => {
          const res = await client.query<{ id: string }>(
            `INSERT INTO pets
               (child_user_id, pet_name, pet_name_status, pet_name_flag_reason, fur_option_id, accessory_option_id)
             VALUES ($1, $2, $3, $4, $5, $6)
             ON CONFLICT (child_user_id) DO UPDATE SET
               pet_name = EXCLUDED.pet_name,
               pet_name_status = EXCLUDED.pet_name_status,
               pet_name_flag_reason = EXCLUDED.pet_name_flag_reason,
               fur_option_id = EXCLUDED.fur_option_id,
               accessory_option_id = EXCLUDED.accessory_option_id,
               updated_at = now()
             RETURNING id`,
            [
              req.authUser!.id,
              petName,
              screening.status,
              screening.reason,
              furOptionId,
              accessoryOptionId,
            ],
          );
          await client.query(
            `UPDATE child_profiles
                SET onboarding_step = GREATEST(onboarding_step, 2), updated_at = now()
              WHERE user_id = $1`,
            [req.authUser!.id],
          );
          return res.rows[0]!.id;
        });
        reply.code(200).send({ id: petId, petNameStatus: screening.status });
      } catch (err) {
        rethrowPetWriteError(err);
      }
    },
  );
}
