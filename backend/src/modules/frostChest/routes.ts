import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";

const MATURITY_DAYS = 3;

// "Сундук Морозко" / time capsule: freeze SAVINGS coins for MATURITY_DAYS,
// get back the principal + 10% bonus; withdraw early and keep only the
// principal. NOTE: the brief's ideal version pays out a rare/epic pet item
// on maturity rather than a coin bonus — that random-item-drop mechanic
// isn't implemented yet, this is the coin-bonus version already in the DB
// schema (see db/migrations/0006_purchases_and_frost_chest.sql).
export async function frostChestRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/frost-chests/active",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query(
        `SELECT id, principal_amount, bonus_amount, opened_at, available_at,
                (available_at IS NOT NULL AND now() >= available_at) AS matured
           FROM frost_chests WHERE child_user_id = $1 AND status = 'ACTIVE'`,
        [req.authUser!.id],
      );
      return res.rows[0] ?? null;
    },
  );

  app.post<{ Body: { principalAmount?: number } }>(
    "/frost-chests",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req, reply) => {
      const childUserId = req.authUser!.id;
      const principalAmount = req.body?.principalAmount;
      if (!Number.isInteger(principalAmount) || (principalAmount as number) < 10) {
        throw new HttpError(400, "principalAmount_must_be_at_least_10");
      }
      const bonusAmount = Math.floor((principalAmount as number) / 10);

      const result = await withTransaction(async (client) => {
        await postTransaction(client, {
          childUserId,
          walletKind: "SAVINGS",
          eventType: "FROST_DEPOSIT",
          deltaAmount: -(principalAmount as number),
          idempotencyKey: `frost-deposit-savings:${childUserId}:${Date.now()}`,
        });
        const frozenTxn = await postTransaction(client, {
          childUserId,
          walletKind: "FROZEN",
          eventType: "FROST_DEPOSIT",
          deltaAmount: principalAmount as number,
          idempotencyKey: `frost-deposit-frozen:${childUserId}:${Date.now()}`,
        });

        try {
          const chestRes = await client.query<{ id: string; available_at: string }>(
            `INSERT INTO frost_chests
               (child_user_id, principal_amount, bonus_amount, deposit_transaction_id, available_at)
             VALUES ($1, $2, $3, $4, now() + $5 * interval '1 day')
             RETURNING id, available_at`,
            [childUserId, principalAmount, bonusAmount, frozenTxn.id, MATURITY_DAYS],
          );
          return chestRes.rows[0]!;
        } catch (err) {
          const pgErr = err as { code?: string };
          if (pgErr.code === "23505") throw new HttpError(409, "chest_already_active");
          throw err;
        }
      });

      reply.code(201).send(result);
    },
  );

  app.post<{ Params: { chestId: string } }>(
    "/frost-chests/:chestId/withdraw-early",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { chestId } = req.params;

      return withTransaction(async (client) => {
        const res = await client.query<{ principal_amount: number; available_at: string }>(
          `SELECT principal_amount, available_at FROM frost_chests
            WHERE id = $1 AND child_user_id = $2 AND status = 'ACTIVE' FOR UPDATE`,
          [chestId, childUserId],
        );
        const chest = res.rows[0];
        if (!chest) throw new HttpError(404, "active_chest_not_found");
        if (new Date(chest.available_at) <= new Date()) {
          throw new HttpError(400, "chest_already_matured_use_collect");
        }

        const withdrawTxn = await postTransaction(client, {
          childUserId,
          walletKind: "FROZEN",
          eventType: "FROST_WITHDRAWAL",
          deltaAmount: -chest.principal_amount,
          idempotencyKey: `frost-withdraw-frozen:${chestId}`,
        });
        await postTransaction(client, {
          childUserId,
          walletKind: "SAVINGS",
          eventType: "FROST_WITHDRAWAL",
          deltaAmount: chest.principal_amount,
          idempotencyKey: `frost-withdraw-savings:${chestId}`,
        });

        await client.query(
          `UPDATE frost_chests SET status = 'WITHDRAWN_EARLY', withdrawal_transaction_id = $1, closed_at = now() WHERE id = $2`,
          [withdrawTxn.id, chestId],
        );

        return { ok: true, principalReturned: chest.principal_amount, bonusForfeited: true };
      });
    },
  );

  app.post<{ Params: { chestId: string } }>(
    "/frost-chests/:chestId/collect",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { chestId } = req.params;

      return withTransaction(async (client) => {
        const res = await client.query<{
          principal_amount: number;
          bonus_amount: number;
          available_at: string;
        }>(
          `SELECT principal_amount, bonus_amount, available_at FROM frost_chests
            WHERE id = $1 AND child_user_id = $2 AND status = 'ACTIVE' FOR UPDATE`,
          [chestId, childUserId],
        );
        const chest = res.rows[0];
        if (!chest) throw new HttpError(404, "active_chest_not_found");
        if (new Date(chest.available_at) > new Date()) {
          throw new HttpError(400, "chest_not_matured_yet");
        }

        const withdrawTxn = await postTransaction(client, {
          childUserId,
          walletKind: "FROZEN",
          eventType: "FROST_WITHDRAWAL",
          deltaAmount: -chest.principal_amount,
          idempotencyKey: `frost-collect-frozen:${chestId}`,
        });
        await postTransaction(client, {
          childUserId,
          walletKind: "SAVINGS",
          eventType: "FROST_WITHDRAWAL",
          deltaAmount: chest.principal_amount,
          idempotencyKey: `frost-collect-savings:${chestId}`,
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
          [withdrawTxn.id, bonusTxn.id, chestId],
        );

        return { ok: true, principalReturned: chest.principal_amount, bonusAwarded: chest.bonus_amount };
      });
    },
  );
}
