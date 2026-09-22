import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { transferBetweenWallets } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { bodySchema, idempotencyKeySchema } from "../../lib/schema.js";

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
    app.post<{ Body: { amount: number; idempotencyKey: string } }>(
      `/savings/${path}`,
      {
        preHandler: [requireAuth, requireRole("CHILD")],
        schema: bodySchema(
          {
            amount: { type: "integer", minimum: 1 },
            idempotencyKey: idempotencyKeySchema,
          },
          ["amount", "idempotencyKey"],
        ),
      },
      async (req, reply) => {
        const { amount, idempotencyKey } = req.body;
        const childUserId = req.authUser!.id;
        const keyPrefix = `manual-${path}:${idempotencyKey}`;

        // Same replay guard as /purchases: a retried request with the same
        // client-supplied key returns the original transfer instead of
        // moving the money twice.
        const existing = await pool.query<{ id: string }>(
          `SELECT id FROM transactions WHERE child_user_id = $1 AND idempotency_key = $2`,
          [childUserId, `${keyPrefix}:from`],
        );
        if (existing.rows[0]) {
          reply.code(200).send({ ok: true, fromTransactionId: existing.rows[0].id, replayed: true });
          return;
        }

        const result = await withTransaction((client) =>
          transferBetweenWallets(client, {
            childUserId,
            fromWallet: from,
            toWallet: to,
            amount,
            eventType: path === "deposit" ? "SAVINGS_DEPOSIT" : "SAVINGS_WITHDRAWAL",
            idempotencyKeyPrefix: keyPrefix,
          }),
        );
        return { ok: true, fromTransactionId: result.fromTxnId, toTransactionId: result.toTxnId };
      },
    );
  }
}
