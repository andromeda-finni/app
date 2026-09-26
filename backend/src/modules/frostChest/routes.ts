import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction, transferBetweenWallets } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { bodySchema, idempotencyKeySchema, paramsSchema, uuidSchema } from "../../lib/schema.js";
import { withIdempotency } from "../../lib/idempotency.js";
import { assertFrostPrincipal, ECONOMY_RULES, frostBonus } from "../economy/rules.js";

// "Сундук Морозко": freeze wallet coins for the configured number of completed
// game days, then return principal plus the configured bonus in SPENDABLE.
export async function frostChestRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/frost-chests/active",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query(
        `SELECT fc.id, fc.principal_amount, fc.bonus_amount, fc.opened_at,
                fc.required_active_days AS maturity_days,
                COUNT(gp.id)::int AS completed_days,
                COUNT(gp.id) >= fc.required_active_days AS matured
           FROM frost_chests fc
           LEFT JOIN game_periods gp ON gp.child_user_id = fc.child_user_id
            AND gp.status = 'COMPLETED' AND gp.closed_at >= fc.opened_at
          WHERE fc.child_user_id = $1 AND fc.status = 'ACTIVE'
          GROUP BY fc.id`,
        [req.authUser!.id],
      );
      return res.rows[0] ?? null;
    },
  );

  app.post<{ Body: { principalAmount: number; idempotencyKey: string } }>(
    "/frost-chests",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: bodySchema(
        {
          principalAmount: {
            type: "integer",
            minimum: ECONOMY_RULES.frostMinimum,
            maximum: ECONOMY_RULES.frostMaximum,
            multipleOf: ECONOMY_RULES.frostStep,
          },
          idempotencyKey: idempotencyKeySchema,
        },
        ["principalAmount", "idempotencyKey"],
      ),
    },
    async (req, reply) => {
      const childUserId = req.authUser!.id;
      const principalAmount = req.body.principalAmount;
      const bonusAmount = frostBonus(principalAmount);
      try {
        assertFrostPrincipal(principalAmount);
      } catch {
        throw new HttpError(400, "invalid_frost_principal");
      }

      const outcome = await withTransaction((client) =>
        withIdempotency(
          client,
          {
            childUserId,
            scope: "frost-open",
            key: req.body.idempotencyKey,
            params: { principalAmount },
          },
          async () => {
            const periodRes = await client.query<{
              id: string;
              opened_at: Date;
              required_need_amount: number;
            }>(
              `SELECT gp.id, gp.opened_at, gp.required_need_amount FROM game_periods gp
                JOIN budget_plans bp ON bp.period_id = gp.id AND bp.status = 'CONFIRMED'
               WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE'`,
              [childUserId],
            );
            if (!periodRes.rows[0]) {
              throw new HttpError(409, "active_day_with_confirmed_plan_required");
            }
            const period = periodRes.rows[0];
            const reserveRes = await client.query<{ balance: number; need_spent: string }>(
              `SELECT w.balance,
                      COALESCE((SELECT SUM(p.total_price)
                                  FROM purchases p
                                  JOIN transactions t ON t.id = p.transaction_id
                                 WHERE p.child_user_id = $1 AND p.item_kind = 'NEED'
                                   AND t.occurred_at >= $2), 0)
                      + COALESCE((SELECT SUM(-t.delta_amount)
                                    FROM transactions t
                                   WHERE t.child_user_id = $1
                                     AND t.event_type = 'PET_EVENT_PAYMENT'
                                     AND t.occurred_at >= $2), 0) AS need_spent
                 FROM wallets w
                WHERE w.child_user_id = $1 AND w.kind = 'SPENDABLE' FOR UPDATE`,
              [childUserId, period.opened_at],
            );
            const reserveState = reserveRes.rows[0];
            const remainingReserve = Math.max(
              period.required_need_amount - Number(reserveState?.need_spent ?? 0),
              0,
            );
            if ((reserveState?.balance ?? 0) - principalAmount < remainingReserve) {
              throw new HttpError(409, "food_reserve_is_unavailable_for_frost");
            }

            const transfer = await transferBetweenWallets(client, {
              childUserId,
              fromWallet: "SPENDABLE",
              toWallet: "FROZEN",
              amount: principalAmount,
              eventType: "FROST_DEPOSIT",
              idempotencyKeyPrefix: `frost-open:${req.body.idempotencyKey}`,
            });

            try {
              const chestRes = await client.query<{ id: string }>(
                `INSERT INTO frost_chests
                   (child_user_id, principal_amount, bonus_amount,
                    required_active_days, deposit_transaction_id)
                 VALUES ($1, $2, $3, $4, $5) RETURNING id`,
                [
                  childUserId,
                  principalAmount,
                  bonusAmount,
                  ECONOMY_RULES.frostDays,
                  transfer.toTxnId,
                ],
              );
              return {
                id: chestRes.rows[0]!.id,
                principalAmount,
                bonusAmount,
                maturityDays: ECONOMY_RULES.frostDays,
              };
            } catch (err) {
              const pgErr = err as { code?: string };
              if (pgErr.code === "23505") throw new HttpError(409, "chest_already_active");
              throw err;
            }
          },
        ),
      );

      reply.code(outcome.replayed ? 200 : 201).send({
        ...outcome.result,
        replayed: outcome.replayed,
      });
    },
  );

  app.post<{ Params: { chestId: string } }>(
    "/frost-chests/:chestId/withdraw-early",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: paramsSchema({ chestId: uuidSchema }, ["chestId"]),
    },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { chestId } = req.params;

      return withTransaction(async (client) => {
        const res = await client.query<{
          principal_amount: number;
          opened_at: Date;
          required_active_days: number;
        }>(
          `SELECT principal_amount, opened_at, required_active_days FROM frost_chests
            WHERE id = $1 AND child_user_id = $2 AND status = 'ACTIVE' FOR UPDATE`,
          [chestId, childUserId],
        );
        const chest = res.rows[0];
        if (!chest) throw new HttpError(404, "active_chest_not_found");
        const daysRes = await client.query<{ completed_days: number }>(
          `SELECT COUNT(*)::int AS completed_days FROM game_periods
            WHERE child_user_id = $1 AND status = 'COMPLETED' AND closed_at >= $2`,
          [childUserId, chest.opened_at],
        );
        if ((daysRes.rows[0]?.completed_days ?? 0) >= chest.required_active_days) {
          throw new HttpError(400, "chest_already_matured_use_collect");
        }

        const transfer = await transferBetweenWallets(client, {
          childUserId,
          fromWallet: "FROZEN",
          toWallet: "SPENDABLE",
          eventType: "FROST_WITHDRAWAL",
          amount: chest.principal_amount,
          idempotencyKeyPrefix: `frost-withdraw:${chestId}`,
        });

        await client.query(
          `UPDATE frost_chests SET status = 'WITHDRAWN_EARLY', withdrawal_transaction_id = $1, closed_at = now() WHERE id = $2`,
          [transfer.fromTxnId, chestId],
        );

        return { ok: true, principalReturned: chest.principal_amount, bonusForfeited: true };
      });
    },
  );

  app.post<{ Params: { chestId: string } }>(
    "/frost-chests/:chestId/collect",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: paramsSchema({ chestId: uuidSchema }, ["chestId"]),
    },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { chestId } = req.params;

      return withTransaction(async (client) => {
        const res = await client.query<{
          principal_amount: number;
          bonus_amount: number;
          opened_at: Date;
          required_active_days: number;
        }>(
          `SELECT principal_amount, bonus_amount, opened_at, required_active_days
             FROM frost_chests
            WHERE id = $1 AND child_user_id = $2 AND status = 'ACTIVE' FOR UPDATE`,
          [chestId, childUserId],
        );
        const chest = res.rows[0];
        if (!chest) throw new HttpError(404, "active_chest_not_found");
        const daysRes = await client.query<{ completed_days: number }>(
          `SELECT COUNT(*)::int AS completed_days FROM game_periods
            WHERE child_user_id = $1 AND status = 'COMPLETED' AND closed_at >= $2`,
          [childUserId, chest.opened_at],
        );
        if ((daysRes.rows[0]?.completed_days ?? 0) < chest.required_active_days) {
          throw new HttpError(400, "chest_not_matured_yet");
        }

        const transfer = await transferBetweenWallets(client, {
          childUserId,
          fromWallet: "FROZEN",
          toWallet: "SPENDABLE",
          eventType: "FROST_WITHDRAWAL",
          amount: chest.principal_amount,
          idempotencyKeyPrefix: `frost-collect:${chestId}`,
        });
        const bonusTxn = await postTransaction(client, {
          childUserId,
          walletKind: "SPENDABLE",
          eventType: "FROST_BONUS",
          deltaAmount: chest.bonus_amount,
          idempotencyKey: `frost-collect-bonus:${chestId}`,
        });

        await client.query(
          `UPDATE frost_chests
              SET status = 'COLLECTED', withdrawal_transaction_id = $1, bonus_transaction_id = $2, closed_at = now()
            WHERE id = $3`,
          [transfer.fromTxnId, bonusTxn.id, chestId],
        );

        return { ok: true, principalReturned: chest.principal_amount, bonusAwarded: chest.bonus_amount };
      });
    },
  );
}
