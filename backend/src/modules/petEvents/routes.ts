import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { pickWeighted } from "../../lib/random.js";
import { paramsSchema, uuidSchema } from "../../lib/schema.js";
import { ECONOMY_RULES } from "../economy/rules.js";

// How far an unresolved event knocks the pet's health down, and where paying
// the bill puts it back.
const PET_EVENT_HEALTH_DROP = 45;
const PET_HEALTH_FULL = 100;

export async function petEventRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/pet-events/active",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query(
        `SELECT peo.id, peo.amount_due, peo.triggered_at, ped.title, ped.description
           FROM pet_event_occurrences peo
           JOIN pet_event_definitions ped ON ped.id = peo.event_definition_id
          WHERE peo.child_user_id = $1 AND peo.status = 'ACTIVE'`,
        [req.authUser!.id],
      );
      return res.rows[0] ?? null;
    },
  );

  // No scheduler/cron in this MVP backend: the client calls this on a
  // natural touchpoint (e.g. opening the pet screen, once per session) and a
  // weighted-random event may fire if none is already active. Replace with a
  // real scheduled job once the deployment has one.
  app.post(
    "/pet-events/roll",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const childUserId = req.authUser!.id;

      return withTransaction(async (client) => {
        // Serialise rolls for one pet: two concurrent calls would otherwise both
        // pass the checks below and race on the single-active-event index.
        const petRes = await client.query<{ id: string }>(
          `SELECT id FROM pets WHERE child_user_id = $1 FOR UPDATE`,
          [childUserId],
        );
        const pet = petRes.rows[0];
        if (!pet) return { triggered: false };

        const periodRes = await client.query<{ id: string; sequence_no: number }>(
          `SELECT id, sequence_no FROM game_periods
            WHERE child_user_id = $1 AND status = 'ACTIVE'`,
          [childUserId],
        );
        const period = periodRes.rows[0];
        if (!period || period.sequence_no < ECONOMY_RULES.firstEventDay) {
          return { triggered: false };
        }

        // Two separate rules: at most one event per game day, and never a new
        // one while an earlier day's bill is still unpaid — the latter is also
        // what uq_pet_event_active_pet enforces, so skipping it here would turn
        // an unpaid yesterday into a raw unique-violation 500 today.
        const blockingRes = await client.query(
          `SELECT 1 FROM pet_event_occurrences
            WHERE child_user_id = $1 AND (period_id = $2 OR status = 'ACTIVE')
            LIMIT 1`,
          [childUserId, period.id],
        );
        if ((blockingRes.rowCount ?? 0) > 0) return { triggered: false };

        if (Math.random() > ECONOMY_RULES.eventProbability) return { triggered: false };

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
        const chosen = pickWeighted(defsRes.rows, (d) => d.trigger_weight);
        if (!chosen) return { triggered: false };

        const occRes = await client.query<{ id: string }>(
          `INSERT INTO pet_event_occurrences (child_user_id, pet_id, event_definition_id, period_id, amount_due)
           VALUES ($1, $2, $3, $4, $5) RETURNING id`,
          [childUserId, pet.id, chosen.id, period.id, chosen.cost_amount],
        );
        // A bill that lands before the plan is approved becomes part of the
        // day's must-haves, so the child plans for it instead of discovering
        // it only after the money is already allocated.
        await client.query(
          `UPDATE game_periods gp
              SET required_need_amount = required_need_amount + $1
            WHERE gp.id = $2
              AND EXISTS (SELECT 1 FROM budget_plans bp
                           WHERE bp.period_id = gp.id AND bp.status = 'DRAFT')`,
          [chosen.cost_amount, period.id],
        );

        // The occurrence and its visible health effect are one domain change:
        // either both commit, or both roll back.
        await client.query(
          `UPDATE pets SET health_level = GREATEST(0, health_level - $1), updated_at = now()
            WHERE child_user_id = $2`,
          [PET_EVENT_HEALTH_DROP, childUserId],
        );

        return { triggered: true, occurrenceId: occRes.rows[0]!.id };
      });
    },
  );

  app.post<{ Params: { occurrenceId: string } }>(
    "/pet-events/:occurrenceId/resolve",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: paramsSchema({ occurrenceId: uuidSchema }, ["occurrenceId"]),
    },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { occurrenceId } = req.params;

      return withTransaction(async (client) => {
        const res = await client.query<{ amount_due: number }>(
          `SELECT amount_due FROM pet_event_occurrences
            WHERE id = $1 AND child_user_id = $2 AND status = 'ACTIVE' FOR UPDATE`,
          [occurrenceId, childUserId],
        );
        const occ = res.rows[0];
        if (!occ) throw new HttpError(404, "active_event_not_found");

        const transaction = await postTransaction(client, {
          childUserId,
          walletKind: "SPENDABLE",
          eventType: "PET_EVENT_PAYMENT",
          deltaAmount: -occ.amount_due,
          referenceType: "pet_event_occurrence",
          referenceId: occurrenceId,
          idempotencyKey: `pet-event:${occurrenceId}`,
        });

        await client.query(
          `UPDATE pet_event_occurrences
              SET status = 'RESOLVED', resolved_at = now(),
                  spendable_transaction_id = $1, savings_transaction_id = NULL
            WHERE id = $2`,
          [transaction.id, occurrenceId],
        );

        // Paying the bill is what makes the pet well again — same transaction,
        // so health can never recover without the money actually moving.
        await client.query(
          `UPDATE pets SET health_level = $1, updated_at = now() WHERE child_user_id = $2`,
          [PET_HEALTH_FULL, childUserId],
        );

        // Bills come out of the day's must-have reserve in SPENDABLE; savings
        // belong to the chosen goal and are never tapped for them.
        return { ok: true, paidFromSavings: false };
      });
    },
  );
}
