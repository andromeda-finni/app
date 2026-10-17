import type pg from "pg";
import { HttpError } from "../../lib/errors.js";
import { presentPet, recoverPetEnergy, spendPetEnergy } from "../pet/energy.js";
import { CATCH_FOOD_RULES, validateCatchFoodResult, type CatchFoodResult } from "./rules.js";

type Client = Pick<pg.PoolClient, "query">;
interface SessionRow extends pg.QueryResultRow {
  id: string;
  energy_cost: number;
  score: number;
  misses: number;
  elapsed_ms: number;
  finish_reason: string | null;
  created_at: Date;
  finished_at: Date | null;
  server_now: Date;
}

function presentSession(row: SessionRow) {
  return {
    id: row.id,
    energyCost: row.energy_cost,
    finished: row.finished_at !== null,
    score: row.score,
    misses: row.misses,
    elapsedMs: row.elapsed_ms,
    reason: row.finish_reason,
  };
}

export async function catchFoodBest(client: Client, childId: string): Promise<number> {
  const result = await client.query<{ best: number }>(
    `SELECT COALESCE(MAX(score), 0)::int AS best
       FROM catch_food_sessions WHERE child_user_id = $1 AND finished_at IS NOT NULL`,
    [childId],
  );
  return result.rows[0]?.best ?? 0;
}

export async function startCatchFood(client: Client, childId: string, sessionId: string) {
  // The same order as quest starts: child, then pet. Concurrent HTTP retries
  // converge on the stored session and can never charge the same attempt twice.
  const child = await client.query(
    `SELECT user_id FROM child_profiles WHERE user_id = $1 FOR UPDATE`, [childId],
  );
  if (!child.rowCount) throw new HttpError(404, "child_profile_not_found");
  const existing = await client.query<SessionRow>(
    `SELECT *, statement_timestamp() AS server_now FROM catch_food_sessions
      WHERE child_user_id = $1 AND id = $2`, [childId, sessionId],
  );
  const pet = await recoverPetEnergy(client, childId);
  if (!pet) throw new HttpError(404, "pet_not_created");
  if (existing.rows[0]) {
    return {
      session: presentSession(existing.rows[0]), pet: presentPet(pet),
      config: CATCH_FOOD_RULES, bestScore: await catchFoodBest(client, childId),
    };
  }
  if (pet.energy_level < CATCH_FOOD_RULES.energyCost) {
    throw new HttpError(409, "pet_energy_insufficient", {
      energyLevel: pet.energy_level, requiredEnergy: CATCH_FOOD_RULES.energyCost,
    });
  }
  const spent = await spendPetEnergy(client, childId, CATCH_FOOD_RULES.energyCost);
  if (!spent) throw new HttpError(409, "pet_energy_insufficient");
  const inserted = await client.query<SessionRow>(
    `INSERT INTO catch_food_sessions (child_user_id, id, energy_cost)
     VALUES ($1, $2, $3) RETURNING *, statement_timestamp() AS server_now`,
    [childId, sessionId, CATCH_FOOD_RULES.energyCost],
  );
  return {
    session: presentSession(inserted.rows[0]!), pet: presentPet(spent),
    config: CATCH_FOOD_RULES, bestScore: await catchFoodBest(client, childId),
  };
}

export async function finishCatchFood(
  client: Client, childId: string, sessionId: string, result: CatchFoodResult,
) {
  const selected = await client.query<SessionRow>(
    `SELECT *, statement_timestamp() AS server_now FROM catch_food_sessions
      WHERE child_user_id = $1 AND id = $2 FOR UPDATE`, [childId, sessionId],
  );
  let row = selected.rows[0];
  if (!row) throw new HttpError(404, "catch_food_session_not_found");
  if (row.finished_at === null) {
    validateCatchFoodResult(result, row.server_now.getTime() - row.created_at.getTime());
    const updated = await client.query<SessionRow>(
      `UPDATE catch_food_sessions
          SET score = $3, misses = $4, elapsed_ms = $5, finish_reason = $6,
              finished_at = statement_timestamp()
        WHERE child_user_id = $1 AND id = $2
        RETURNING *, statement_timestamp() AS server_now`,
      [childId, sessionId, result.score, result.misses, result.elapsedMs, result.reason],
    );
    row = updated.rows[0]!;
  }
  return { session: presentSession(row), bestScore: await catchFoodBest(client, childId) };
}
