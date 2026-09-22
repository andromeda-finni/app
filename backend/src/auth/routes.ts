import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../lib/db.js";
import { HttpError } from "../lib/errors.js";
import { postTransaction } from "../lib/ledger.js";
import { bodySchema } from "../lib/schema.js";
import {
  generateInviteCode,
  generateOpaqueToken,
  hashInviteCode,
  hashToken,
} from "./tokens.js";
import { requireAuth, requireRole } from "./plugin.js";

const INVITE_TTL_MS = 24 * 60 * 60 * 1000;
const START_GRANT_SPENDABLE = 50;

export async function authRoutes(app: FastifyInstance): Promise<void> {
  // A parent account is just an anonymous identity — no name/email/phone.
  app.post("/auth/parent/register", async (_req, reply) => {
    const result = await withTransaction(async (client) => {
      const userRes = await client.query<{ id: string }>(
        `INSERT INTO users (role) VALUES ('PARENT') RETURNING id`,
      );
      const userId = userRes.rows[0]!.id;
      await client.query(`INSERT INTO parent_profiles (user_id) VALUES ($1)`, [userId]);

      const token = generateOpaqueToken();
      await client.query(
        `INSERT INTO auth_credentials (user_id, token_hash) VALUES ($1, $2)`,
        [userId, hashToken(token)],
      );
      return { userId, token };
    });
    reply.code(201).send({ userId: result.userId, token: result.token });
  });

  // Parent generates a one-time invite code to hand to the child (spoken,
  // written down, or QR — transport is a client concern). No child identity
  // exists yet; the link row starts PENDING and only gets a child_user_id
  // once redeemed — either during child registration in the past, or later
  // via POST /child/parent-link/redeem now that a child can self-register
  // without a parent at all (see that route below).
  app.post(
    "/auth/parent/invites",
    { preHandler: [requireAuth, requireRole("PARENT")] },
    async (req, reply) => {
      const parentUserId = req.authUser!.id;
      const code = generateInviteCode();
      const expiresAt = new Date(Date.now() + INVITE_TTL_MS);

      const res = await pool.query<{ id: string }>(
        `INSERT INTO parent_child_links (parent_user_id, invite_code_hash, expires_at)
         VALUES ($1, $2, $3) RETURNING id`,
        [parentUserId, hashInviteCode(code), expiresAt],
      );

      reply.code(201).send({
        linkId: res.rows[0]!.id,
        inviteCode: code,
        expiresAt: expiresAt.toISOString(),
      });
    },
  );

  // Child self-registers standalone — no parent or invite code required at
  // account-creation time (product decision: a parent link is optional and
  // attached later, see POST /child/parent-link/redeem). Provisions wallets
  // and grants a small starting balance atomically with the account.
  app.post<{ Body: { difficulty?: "SIMPLE" | "ADVANCED" } }>(
    "/auth/child/register",
    {
      schema: bodySchema({
        difficulty: { type: "string", enum: ["SIMPLE", "ADVANCED"] },
      }),
    },
    async (req, reply) => {
      const difficulty = req.body?.difficulty ?? "SIMPLE";

      const result = await withTransaction(async (client) => {
        const userRes = await client.query<{ id: string }>(
          `INSERT INTO users (role) VALUES ('CHILD') RETURNING id`,
        );
        const childUserId = userRes.rows[0]!.id;

        await client.query(
          `INSERT INTO child_profiles (user_id, difficulty) VALUES ($1, $2)`,
          [childUserId, difficulty],
        );

        await client.query(
          `INSERT INTO wallets (child_user_id, kind) VALUES ($1, 'SPENDABLE'), ($1, 'SAVINGS'), ($1, 'FROZEN')`,
          [childUserId],
        );

        await postTransaction(client, {
          childUserId,
          walletKind: "SPENDABLE",
          eventType: "START_GRANT",
          deltaAmount: START_GRANT_SPENDABLE,
          idempotencyKey: "start-grant",
        });

        const token = generateOpaqueToken();
        await client.query(
          `INSERT INTO auth_credentials (user_id, token_hash) VALUES ($1, $2)`,
          [childUserId, hashToken(token)],
        );

        return { childUserId, token };
      });

      reply.code(201).send({ userId: result.childUserId, token: result.token });
    },
  );

  // Attaches an existing, already-authenticated child to a parent's invite —
  // the "link a parent later from settings" path. Unlike the old
  // register-and-redeem flow, the child account already exists here.
  app.post<{ Body: { inviteCode: string } }>(
    "/child/parent-link/redeem",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: bodySchema(
        { inviteCode: { type: "string", minLength: 1, maxLength: 32 } },
        ["inviteCode"],
      ),
    },
    async (req, reply) => {
      const childUserId = req.authUser!.id;
      const inviteCode = req.body.inviteCode.trim();

      const result = await withTransaction(async (client) => {
        const linkRes = await client.query<{ id: string; parent_user_id: string }>(
          `SELECT id, parent_user_id FROM parent_child_links
             WHERE invite_code_hash = $1 AND status = 'PENDING' AND expires_at > now()
             FOR UPDATE`,
          [hashInviteCode(inviteCode)],
        );
        const link = linkRes.rows[0];
        if (!link) {
          throw new HttpError(400, "invite_code_invalid_or_expired");
        }

        try {
          await client.query(
            `UPDATE parent_child_links
                SET status = 'ACTIVE', child_user_id = $1, linked_at = now()
              WHERE id = $2`,
            [childUserId, link.id],
          );
        } catch (err) {
          const pgErr = err as { code?: string };
          // uq_link_active_pair: this exact (parent, child) pair is already linked.
          if (pgErr.code === "23505") throw new HttpError(409, "already_linked_to_this_parent");
          throw err;
        }

        return { linkId: link.id, parentUserId: link.parent_user_id };
      });

      reply.code(200).send(result);
    },
  );
}
