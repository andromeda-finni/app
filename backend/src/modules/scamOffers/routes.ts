import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { pickWeighted } from "../../lib/random.js";

const TRIGGER_PROBABILITY = 0.15;
const DECLINE_JOY_REWARD = 2;
const ACCEPT_JOY_PENALTY = 3;

// "Вредные советы": a sly NPC periodically pitches a too-good-to-be-true
// deal. Declining is (almost always) correct and is rewarded; accepting
// costs a small, bounded amount and explains why it was a trick — a
// comedic, non-punishing consequence, never the promised payout (it's a
// scam — the promise was never real).
export async function scamOfferRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/scam-offers/active",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query(
        `SELECT so.id, so.triggered_at, sod.npc_character_code, sod.pitch_text, sod.promised_amount
           FROM scam_offer_occurrences so
           JOIN scam_offer_definitions sod ON sod.id = so.offer_definition_id
          WHERE so.child_user_id = $1 AND so.status = 'ACTIVE'`,
        [req.authUser!.id],
      );
      return res.rows[0] ?? null;
    },
  );

  app.post(
    "/scam-offers/roll",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const childUserId = req.authUser!.id;

      const activeRes = await pool.query(
        `SELECT 1 FROM scam_offer_occurrences WHERE child_user_id = $1 AND status = 'ACTIVE'`,
        [childUserId],
      );
      if ((activeRes.rowCount ?? 0) > 0) return { triggered: false };
      if (Math.random() > TRIGGER_PROBABILITY) return { triggered: false };

      const defsRes = await pool.query<{ id: string; trigger_weight: number }>(
        `SELECT id, trigger_weight FROM scam_offer_definitions WHERE active`,
      );
      const chosen = pickWeighted(defsRes.rows, (d) => d.trigger_weight);
      if (!chosen) return { triggered: false };

      const periodRes = await pool.query<{ id: string }>(
        `SELECT id FROM game_periods WHERE child_user_id = $1 AND status = 'ACTIVE'`,
        [childUserId],
      );

      const occRes = await pool.query<{ id: string }>(
        `INSERT INTO scam_offer_occurrences (child_user_id, period_id, offer_definition_id)
         VALUES ($1, $2, $3) RETURNING id`,
        [childUserId, periodRes.rows[0]?.id ?? null, chosen.id],
      );

      return { triggered: true, occurrenceId: occRes.rows[0]!.id };
    },
  );

  app.post<{ Params: { occurrenceId: string }; Body: { decision?: "ACCEPTED" | "DECLINED" } }>(
    "/scam-offers/:occurrenceId/respond",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { occurrenceId } = req.params;
      const decision = req.body?.decision;
      if (decision !== "ACCEPTED" && decision !== "DECLINED") {
        throw new HttpError(400, "decision_must_be_ACCEPTED_or_DECLINED");
      }

      return withTransaction(async (client) => {
        const res = await client.query<{
          cost_if_accepted: number;
          decline_feedback: string;
          accept_feedback: string;
        }>(
          `SELECT sod.cost_if_accepted, sod.decline_feedback, sod.accept_feedback
             FROM scam_offer_occurrences so
             JOIN scam_offer_definitions sod ON sod.id = so.offer_definition_id
            WHERE so.id = $1 AND so.child_user_id = $2 AND so.status = 'ACTIVE'
            FOR UPDATE OF so`,
          [occurrenceId, childUserId],
        );
        const offer = res.rows[0];
        if (!offer) throw new HttpError(404, "active_offer_not_found");

        if (decision === "DECLINED") {
          await client.query(
            `UPDATE scam_offer_occurrences SET status = 'RESOLVED', decision = 'DECLINED', resolved_at = now() WHERE id = $1`,
            [occurrenceId],
          );
          await client.query(
            `UPDATE pets SET joy_level = LEAST(100, joy_level + $1), updated_at = now() WHERE child_user_id = $2`,
            [DECLINE_JOY_REWARD, childUserId],
          );
          return { decision, feedback: offer.decline_feedback, costPaid: 0 };
        }

        const txn = await postTransaction(client, {
          childUserId,
          walletKind: "SPENDABLE",
          eventType: "SCAM_OFFER_LOSS",
          deltaAmount: -offer.cost_if_accepted,
          referenceType: "scam_offer_occurrence",
          referenceId: occurrenceId,
          idempotencyKey: `scam-offer-loss:${occurrenceId}`,
        });

        await client.query(
          `UPDATE scam_offer_occurrences
              SET status = 'RESOLVED', decision = 'ACCEPTED', resolved_at = now(), cost_transaction_id = $1
            WHERE id = $2`,
          [txn.id, occurrenceId],
        );
        await client.query(
          `UPDATE pets SET joy_level = GREATEST(0, joy_level - $1), updated_at = now() WHERE child_user_id = $2`,
          [ACCEPT_JOY_PENALTY, childUserId],
        );

        return { decision, feedback: offer.accept_feedback, costPaid: offer.cost_if_accepted, balanceAfter: txn.balanceAfter };
      });
    },
  );
}
