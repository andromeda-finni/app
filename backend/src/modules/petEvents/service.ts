import type { PoolClient } from "pg";
import { pickWeighted } from "../../lib/random.js";
import { ECONOMY_RULES } from "../economy/rules.js";

const PET_EVENT_HEALTH_DROP = 45;

export interface PetEventRollResult {
  triggered: boolean;
  occurrenceId?: string;
}

/**
 * Performs the active period's one and only pet-event roll.
 *
 * The period row is both the durable idempotency marker and the concurrency
 * lock. Callers must already be inside a transaction; the marker, occurrence,
 * increased needs reserve and health change therefore commit or roll back as
 * one domain operation.
 */
export async function rollActivePeriodPetEvent(
  client: PoolClient,
  childUserId: string,
  random: () => number = Math.random,
): Promise<PetEventRollResult> {
  const periodRes = await client.query<{
    id: string;
    sequence_no: number;
    event_rolled_at: Date | null;
  }>(
    `SELECT id, sequence_no, event_rolled_at
       FROM game_periods
      WHERE child_user_id = $1 AND status = 'ACTIVE'
      FOR UPDATE`,
    [childUserId],
  );
  const period = periodRes.rows[0];
  if (!period || period.event_rolled_at) return { triggered: false };

  await client.query(
    `UPDATE game_periods SET event_rolled_at = now() WHERE id = $1`,
    [period.id],
  );

  if (period.sequence_no < ECONOMY_RULES.firstEventDay) {
    return { triggered: false };
  }

  const petRes = await client.query<{ id: string }>(
    `SELECT id FROM pets WHERE child_user_id = $1 FOR UPDATE`,
    [childUserId],
  );
  const pet = petRes.rows[0];
  if (!pet) return { triggered: false };

  // A legacy unpaid event may belong to an older period. It still blocks a
  // new occurrence even though this period's roll is now durably consumed.
  const blockingRes = await client.query(
    `SELECT 1 FROM pet_event_occurrences
      WHERE child_user_id = $1 AND status = 'ACTIVE'
      LIMIT 1`,
    [childUserId],
  );
  if ((blockingRes.rowCount ?? 0) > 0) return { triggered: false };

  if (random() >= ECONOMY_RULES.eventProbability) return { triggered: false };

  const defsRes = await client.query<{
    id: string;
    cost_amount: number;
    trigger_weight: number;
  }>(
    `SELECT id, cost_amount, trigger_weight
       FROM pet_event_definitions
      WHERE active AND cost_amount BETWEEN $1 AND $2
        AND id IS DISTINCT FROM (
          SELECT peo.event_definition_id
            FROM pet_event_occurrences peo
            JOIN game_periods gp ON gp.id = peo.period_id
           WHERE peo.child_user_id = $3 AND gp.sequence_no = $4 - 1
           LIMIT 1
        )`,
    [
      ECONOMY_RULES.minimumEventCost,
      ECONOMY_RULES.maximumEventCost,
      childUserId,
      period.sequence_no,
    ],
  );
  const chosen = pickWeighted(defsRes.rows, (definition) => definition.trigger_weight, random);
  if (!chosen) return { triggered: false };

  const occurrenceRes = await client.query<{ id: string }>(
    `INSERT INTO pet_event_occurrences
       (child_user_id, pet_id, event_definition_id, period_id, amount_due)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id`,
    [childUserId, pet.id, chosen.id, period.id, chosen.cost_amount],
  );

  // The bill is visible before the plan is approved, so it becomes part of
  // the amount the child must reserve for needs.
  await client.query(
    `UPDATE game_periods
        SET required_need_amount = required_need_amount + $1
      WHERE id = $2`,
    [chosen.cost_amount, period.id],
  );
  await client.query(
    `UPDATE pets
        SET health_level = GREATEST(0, health_level - $1), updated_at = now()
      WHERE child_user_id = $2`,
    [PET_EVENT_HEALTH_DROP, childUserId],
  );

  return {
    triggered: true,
    occurrenceId: occurrenceRes.rows[0]!.id,
  };
}
