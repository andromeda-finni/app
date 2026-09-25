import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { pickWeighted } from "../../lib/random.js";
import { paramsSchema, uuidSchema } from "../../lib/schema.js";
import { ECONOMY_RULES } from "../economy/rules.js";


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

      const periodRes = await pool.query<{ id: string; sequence_no: number }>(
        `SELECT id, sequence_no FROM game_periods
          WHERE child_user_id = $1 AND status = 'ACTIVE'`,
        [childUserId],
      );
      const period = periodRes.rows[0];
      if (!period || period.sequence_no < ECONOMY_RULES.firstEventDay) {
        return { triggered: false };
      }

      const activeRes = await pool.query(
        `SELECT 1 FROM pet_event_occurrences
          WHERE child_user_id = $1 AND period_id = $2`,
        [childUserId, period.id],
      );
      if ((activeRes.rowCount ?? 0) > 0) return { triggered: false };

      if (Math.random() > ECONOMY_RULES.eventProbability) return { triggered: false };

      const defsRes = await pool.query<{ id: string; cost_amount: number; trigger_weight: number }>(
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

      const petRes = await pool.query<{ id: string }>(
        `SELECT id FROM pets WHERE child_user_id = $1`,
        [childUserId],
      );
      const pet = petRes.rows[0];
      if (!pet) return { triggered: false };

      const occRes = await pool.query<{ id: string }>(
        `INSERT INTO pet_event_occurrences (child_user_id, pet_id, event_definition_id, period_id, amount_due)
         VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        [childUserId, pet.id, chosen.id, period.id, chosen.cost_amount],
      );
      await pool.query(
        `UPDATE game_periods gp
            SET required_need_amount = required_need_amount + $1
          WHERE gp.id = $2
            AND EXISTS (SELECT 1 FROM budget_plans bp
                         WHERE bp.period_id = gp.id AND bp.status = 'DRAFT')`,
        [chosen.cost_amount, period.id],
      );

      return { triggered: true, occurrenceId: occRes.rows[0]!.id };
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

        return { ok: true, paidFromSavings: false };
      });
    },
  );
}
