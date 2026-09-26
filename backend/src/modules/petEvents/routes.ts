import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { paramsSchema, uuidSchema } from "../../lib/schema.js";
import { rollActivePeriodPetEvent } from "./service.js";

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

  // Kept as an idempotent compatibility endpoint for older clients. Current
  // clients receive the same roll atomically from POST /periods.
  app.post(
    "/pet-events/roll",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const childUserId = req.authUser!.id;

      return withTransaction((client) =>
        rollActivePeriodPetEvent(client, childUserId),
      );
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
