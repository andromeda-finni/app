import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { withIdempotency } from "../../lib/idempotency.js";
import { bodySchema, idempotencyKeySchema, shortIdSchema } from "../../lib/schema.js";

const IMPULSE_ENERGY_PENALTY = 5;
const IMPULSE_JOY_PENALTY = 5;

export async function shopRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/shop-items",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async () => {
          const res = await pool.query(
            `SELECT id, kind, name, price, rarity, effect_code
               FROM shop_items WHERE active AND kind IN ('NEED', 'WANT') ORDER BY kind, price`,
          );
          return res.rows;
        },
      );

      // Feeding / playing with / caring for the pet are all just NEED/WANT
      // purchases from the child's point of view — spend earned coins on
      // something that helps (or merely delights) the pet.
      app.post<{ Body: { itemId: string; quantity?: number; idempotencyKey: string } }>(
        "/purchases",
        {
          preHandler: [requireAuth, requireRole("CHILD")],
          schema: bodySchema(
            {
              itemId: shortIdSchema,
              quantity: { type: "integer", minimum: 1, maximum: 20 },
              idempotencyKey: idempotencyKeySchema,
            },
            ["itemId", "idempotencyKey"],
          ),
        },
        async (req, reply) => {
          const childUserId = req.authUser!.id;
          const { itemId, idempotencyKey } = req.body;
          const quantity = req.body.quantity ?? 1;

          // Claiming the key and spending the money share one transaction, so a
          // retry (e.g. after a timeout that hid a successful commit from the
          // client) replays the original result instead of charging twice — and
          // two simultaneous retries can't both get through.
          const outcome = await withTransaction((client) =>
            withIdempotency(
              client,
              {
                childUserId,
                scope: "purchase",
                key: idempotencyKey,
                params: { itemId, quantity },
              },
              async () => {
            const itemRes = await client.query<{ kind: "NEED" | "WANT"; price: number }>(
              `SELECT kind, price FROM shop_items WHERE id = $1 AND active AND kind IN ('NEED', 'WANT')`,
              [itemId],
            );
            const item = itemRes.rows[0];
            if (!item) throw new HttpError(404, "item_not_found");

            const totalPrice = item.price * quantity;

            const periodRes = await client.query<{
              id: string;
              need_amount: number;
              required_need_amount: number;
            }>(
              `SELECT gp.id, gp.required_need_amount, bp.need_amount
                 FROM game_periods gp
                 JOIN budget_plans bp ON bp.period_id = gp.id AND bp.status = 'CONFIRMED'
                WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE'`,
              [childUserId],
            );
            const period = periodRes.rows[0];
            if (!period) throw new HttpError(409, "active_day_with_confirmed_plan_required");

            const needSpentRes = await client.query<{ spent: string }>(
              `SELECT
                 COALESCE((SELECT SUM(p.total_price)
                             FROM purchases p
                             JOIN transactions t ON t.id = p.transaction_id
                            WHERE p.child_user_id = $1 AND p.item_kind = 'NEED'
                              AND t.occurred_at >= gp.opened_at), 0)
                 + COALESCE((SELECT SUM(-t.delta_amount)
                               FROM transactions t
                              WHERE t.child_user_id = $1
                                AND t.event_type = 'PET_EVENT_PAYMENT'
                                AND t.occurred_at >= gp.opened_at), 0) AS spent
                 FROM game_periods gp WHERE gp.id = $2`,
              [childUserId, period.id],
            );
            const needSpent = Number(needSpentRes.rows[0]?.spent ?? 0);

            // Impulse check: buying a WANT while this period's NEED commitment
            // isn't covered yet by actual NEED spending — the game's concrete,
            // non-punishing signal for "you spent on a want before a need".
            let impulsive = false;
            if (item.kind === "WANT") {
              const remainingReserve = Math.max(
                period.required_need_amount - needSpent,
                0,
              );
              const walletRes = await client.query<{ balance: number }>(
                `SELECT balance FROM wallets
                  WHERE child_user_id = $1 AND kind = 'SPENDABLE' FOR UPDATE`,
                [childUserId],
              );
              const balance = walletRes.rows[0]?.balance ?? 0;
              if (balance - totalPrice < remainingReserve) {
                throw new HttpError(409, "food_reserve_is_unavailable_for_wants", {
                  reserve: remainingReserve,
                });
              }
              impulsive = needSpent < period.need_amount;
            }

            const txn = await postTransaction(client, {
              childUserId,
              walletKind: "SPENDABLE",
              eventType: "PURCHASE",
              deltaAmount: -totalPrice,
              referenceType: "shop_item",
              referenceId: itemId,
              idempotencyKey: `purchase:${idempotencyKey}`,
            });

            const purchaseRes = await client.query<{ id: string }>(
              `INSERT INTO purchases (child_user_id, item_id, item_kind, transaction_id, quantity, unit_price, total_price)
               VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
              [childUserId, itemId, item.kind, txn.id, quantity, item.price, totalPrice],
            );

            if (impulsive) {
              await client.query(
                `UPDATE pets
                    SET energy_level = GREATEST(0, energy_level - $1),
                        joy_level = GREATEST(0, joy_level - $2),
                        updated_at = now()
                  WHERE child_user_id = $3`,
                [IMPULSE_ENERGY_PENALTY, IMPULSE_JOY_PENALTY, childUserId],
              );
            }

            return {
              purchaseId: purchaseRes.rows[0]!.id,
              balanceAfter: txn.balanceAfter,
              impulsive,
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
