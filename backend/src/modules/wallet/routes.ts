import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { transferBetweenWallets } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";

export async function walletRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/wallets",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query(
        `SELECT kind, balance, updated_at FROM wallets WHERE child_user_id = $1 ORDER BY kind`,
        [req.authUser!.id],
      );
      return res.rows;
    },
  );

  app.get(
    "/transactions",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query(
        `SELECT id, wallet_kind, event_type, delta_amount, balance_after, occurred_at
           FROM transactions WHERE child_user_id = $1
          ORDER BY occurred_at DESC LIMIT 50`,
        [req.authUser!.id],
      );
      return res.rows;
    },
  );

  // Voluntary extra saving/un-saving beyond the period's confirmed plan
  // (e.g. putting leftover spendable coins aside toward a goal).
  for (const [path, from, to] of [
    ["deposit", "SPENDABLE", "SAVINGS"],
    ["withdraw", "SAVINGS", "SPENDABLE"],
  ] as const) {
    app.post<{ Body: { amount?: number } }>(
      `/savings/${path}`,
      { preHandler: [requireAuth, requireRole("CHILD")] },
      async (req) => {
        const amount = req.body?.amount;
        if (!Number.isInteger(amount) || (amount as number) < 1) {
          throw new HttpError(400, "amount_must_be_a_positive_integer");
        }
        const childUserId = req.authUser!.id;
        const result = await withTransaction((client) =>
          transferBetweenWallets(client, {
            childUserId,
            fromWallet: from,
            toWallet: to,
            amount: amount as number,
            eventType: path === "deposit" ? "SAVINGS_DEPOSIT" : "SAVINGS_WITHDRAWAL",
            idempotencyKeyPrefix: `manual-${path}:${childUserId}:${Date.now()}`,
          }),
        );
        return { ok: true, fromTransactionId: result.fromTxnId, toTransactionId: result.toTxnId };
      },
    );
  }
}
