import type { FastifyInstance } from "fastify";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { withIdempotency } from "../../lib/idempotency.js";
import { postTransaction } from "../../lib/ledger.js";
import { bodySchema, idempotencyKeySchema } from "../../lib/schema.js";
import { ECONOMY_RULES } from "../economy/rules.js";

export async function insuranceRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: { idempotencyKey: string } }>(
    "/insurance/purchase",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: bodySchema(
        { idempotencyKey: idempotencyKeySchema },
        ["idempotencyKey"],
      ),
    },
    async (req, reply) => {
      const childUserId = req.authUser!.id;
      const { idempotencyKey } = req.body;

      const outcome = await withTransaction((client) =>
        withIdempotency(
          client,
          {
            childUserId,
            scope: "insurance-purchase",
            key: idempotencyKey,
            params: {},
          },
          async () => {
            // The period lock serialises two purchases made with different
            // idempotency keys before either can observe the other's policy.
            const periodRes = await client.query<{
              id: string;
              sequence_no: number;
            }>(
              `SELECT gp.id, gp.sequence_no
                 FROM game_periods gp
                 JOIN budget_plans bp ON bp.period_id = gp.id AND bp.status = 'CONFIRMED'
                WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE'
                FOR UPDATE OF gp`,
              [childUserId],
            );
            const period = periodRes.rows[0];
            if (!period) {
              throw new HttpError(409, "active_day_with_confirmed_plan_required");
            }

            const coverageSequence = period.sequence_no + 1;
            // If the optional event roll was unavailable when the covered day
            // began, do not let its stale ACTIVE row block protection for the
            // following day forever. No event was recorded, so it expires.
            await client.query(
              `UPDATE insurance_policies
                  SET status = 'EXPIRED', resolved_at = now()
                WHERE child_user_id = $1 AND status = 'ACTIVE'
                  AND coverage_sequence_no <= $2`,
              [childUserId, period.sequence_no],
            );
            const prior = await client.query(
              `SELECT 1 FROM insurance_policies
                WHERE child_user_id = $1 AND coverage_sequence_no = $2`,
              [childUserId, coverageSequence],
            );
            if ((prior.rowCount ?? 0) > 0) {
              throw new HttpError(409, "insurance_already_purchased_for_next_day");
            }

            // Reserve the domain id before posting the ledger entry so the
            // append-only transaction can point at the policy it pays for.
            const policyRes = await client.query<{ id: string }>(
              `SELECT gen_random_uuid() AS id`,
            );
            const policyId = policyRes.rows[0]!.id;

            const transaction = await postTransaction(client, {
              childUserId,
              walletKind: "SPENDABLE",
              eventType: "INSURANCE_PREMIUM",
              deltaAmount: -ECONOMY_RULES.insurancePremium,
              referenceType: "insurance_policy",
              referenceId: policyId,
              idempotencyKey: `insurance-premium:${policyId}`,
            });

            await client.query(
              `INSERT INTO insurance_policies
                 (id, child_user_id, purchased_period_id, coverage_sequence_no,
                  premium_amount, purchase_transaction_id)
               VALUES ($1, $2, $3, $4, $5, $6)`,
              [
                policyId,
                childUserId,
                period.id,
                coverageSequence,
                ECONOMY_RULES.insurancePremium,
                transaction.id,
              ],
            );

            return {
              policyId,
              coverageSequence,
              premium: ECONOMY_RULES.insurancePremium,
              balanceAfter: transaction.balanceAfter,
            };
          },
        ),
      );

      reply
        .code(outcome.replayed ? 200 : 201)
        .send({ ...outcome.result, replayed: outcome.replayed });
    },
  );
}
