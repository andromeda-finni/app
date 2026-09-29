import type pg from "pg";

export const MAX_ENERGY = 100;
export const ACTIVITY_ENERGY_COST = 20;
export const ENERGY_PER_TICK = 20;
export const ENERGY_TICK_SECONDS = 3 * 60;
export const RESTORE_ENERGY_EFFECT = "RESTORE_ENERGY_FULL";

export interface PetEnergyRow extends pg.QueryResultRow {
  id: string;
  child_user_id: string;
  pet_name: string;
  pet_name_status: string;
  fur_option_id: string;
  accessory_option_id: string | null;
  energy_level: number;
  joy_level: number;
  health_level: number;
  evolution_stage: number;
  successful_period_streak: number;
  equipped_inventory_item_id: string | null;
  energy_depleted_at: Date | null;
  last_energy_tick_at: Date;
  created_at: Date;
  updated_at: Date;
  mode: "STANDARD" | "DEMO";
  server_now: Date;
}

type QueryClient = Pick<pg.Pool | pg.PoolClient, "query">;

/**
 * Applies every complete recovery interval in one row-locked statement.
 * Keeping incomplete seconds in last_energy_tick_at avoids losing progress
 * when the endpoint is polled, the app closes, or two requests race.
 */
export async function recoverPetEnergy(
  client: QueryClient,
  childUserId: string,
): Promise<PetEnergyRow | null> {
  const result = await client.query<PetEnergyRow>(
    `WITH locked_pet AS (
       SELECT p.id,
              CASE
                WHEN p.energy_level < $2 THEN GREATEST(
                  0,
                  FLOOR(EXTRACT(EPOCH FROM (statement_timestamp() - p.last_energy_tick_at)) / $3::double precision)::int
                )
                ELSE 0
              END AS elapsed_ticks,
              statement_timestamp() AS server_now
         FROM pets p
        WHERE p.child_user_id = $1
        FOR UPDATE
     ), recovered AS (
       UPDATE pets p
          SET energy_level = LEAST($2, p.energy_level + locked_pet.elapsed_ticks * $4),
              last_energy_tick_at = CASE
                WHEN LEAST($2, p.energy_level + locked_pet.elapsed_ticks * $4) >= $2
                  THEN locked_pet.server_now
                ELSE p.last_energy_tick_at
                     + locked_pet.elapsed_ticks * ($3::double precision * INTERVAL '1 second')
              END,
              energy_depleted_at = CASE
                WHEN LEAST($2, p.energy_level + locked_pet.elapsed_ticks * $4) > 0
                  THEN NULL
                ELSE p.energy_depleted_at
              END,
              updated_at = CASE
                WHEN locked_pet.elapsed_ticks > 0 THEN locked_pet.server_now
                ELSE p.updated_at
              END
         FROM locked_pet
        WHERE p.id = locked_pet.id
       RETURNING p.*, locked_pet.server_now
     )
     SELECT recovered.*, cp.mode
       FROM recovered
       JOIN child_profiles cp ON cp.user_id = recovered.child_user_id`,
    [childUserId, MAX_ENERGY, ENERGY_TICK_SECONDS, ENERGY_PER_TICK],
  );
  return result.rows[0] ?? null;
}

/** Deducts one activity cost after recovery has been applied in the same transaction. */
export async function spendPetEnergy(
  client: QueryClient,
  childUserId: string,
  amount = ACTIVITY_ENERGY_COST,
): Promise<PetEnergyRow | null> {
  const result = await client.query<PetEnergyRow>(
    `WITH spent AS (
       UPDATE pets
          SET energy_level = energy_level - $2,
              last_energy_tick_at = CASE
                WHEN energy_level = $3 OR energy_level - $2 = 0
                  THEN statement_timestamp()
                ELSE last_energy_tick_at
              END,
              energy_depleted_at = CASE
                WHEN energy_level - $2 = 0 THEN statement_timestamp()
                ELSE energy_depleted_at
              END,
              updated_at = statement_timestamp()
        WHERE child_user_id = $1 AND energy_level >= $2
       RETURNING *, statement_timestamp() AS server_now
     )
     SELECT spent.*, cp.mode
       FROM spent
       JOIN child_profiles cp ON cp.user_id = spent.child_user_id`,
    [childUserId, amount, MAX_ENERGY],
  );
  return result.rows[0] ?? null;
}

export async function restorePetEnergy(
  client: QueryClient,
  childUserId: string,
): Promise<PetEnergyRow | null> {
  const result = await client.query<PetEnergyRow>(
    `WITH restored AS (
       UPDATE pets
          SET energy_level = $2,
              energy_depleted_at = NULL,
              last_energy_tick_at = statement_timestamp(),
              updated_at = statement_timestamp()
        WHERE child_user_id = $1
       RETURNING *, statement_timestamp() AS server_now
     )
     SELECT restored.*, cp.mode
       FROM restored
       JOIN child_profiles cp ON cp.user_id = restored.child_user_id`,
    [childUserId, MAX_ENERGY],
  );
  return result.rows[0] ?? null;
}

export function presentPet(row: PetEnergyRow): Record<string, unknown> {
  const ticksUntilFull = Math.ceil((MAX_ENERGY - row.energy_level) / ENERGY_PER_TICK);
  const nextTickAt = row.energy_level < MAX_ENERGY
    ? new Date(row.last_energy_tick_at.getTime() + ENERGY_TICK_SECONDS * 1000)
    : null;
  const fullAt = row.energy_level < MAX_ENERGY
    ? new Date(row.last_energy_tick_at.getTime() + ticksUntilFull * ENERGY_TICK_SECONDS * 1000)
    : null;

  return {
    id: row.id,
    pet_name: row.pet_name,
    pet_name_status: row.pet_name_status,
    fur_option_id: row.fur_option_id,
    accessory_option_id: row.accessory_option_id,
    energy_level: row.energy_level,
    joy_level: row.joy_level,
    health_level: row.health_level,
    evolution_stage: row.evolution_stage,
    successful_period_streak: row.successful_period_streak,
    equipped_inventory_item_id: row.equipped_inventory_item_id,
    energy_depleted_at: row.energy_depleted_at,
    last_energy_tick_at: row.last_energy_tick_at,
    created_at: row.created_at,
    updated_at: row.updated_at,
    mode: row.mode,
    server_time: row.server_now,
    energy_recovery: {
      max_energy: MAX_ENERGY,
      activity_cost: ACTIVITY_ENERGY_COST,
      energy_per_tick: ENERGY_PER_TICK,
      tick_seconds: ENERGY_TICK_SECONDS,
      next_tick_at: nextTickAt,
      full_at: fullAt,
    },
  };
}
