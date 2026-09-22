import type { FastifyReply, FastifyRequest } from "fastify";
import { query } from "../lib/db.js";
import { hashToken } from "./tokens.js";
import { HttpError } from "../lib/errors.js";

export interface AuthUser {
  id: string;
  role: "PARENT" | "CHILD";
}

declare module "fastify" {
  interface FastifyRequest {
    authUser?: AuthUser;
  }
}

/**
 * preHandler hook: reads `Authorization: Bearer <token>`, hashes it, and
 * looks up an active credential. Never compares the raw token against
 * anything stored — the DB only ever holds token_hash (see
 * db/migrations/0013_auth_credentials.sql).
 */
export async function requireAuth(req: FastifyRequest, _reply: FastifyReply): Promise<void> {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    throw new HttpError(401, "missing_bearer_token");
  }
  const token = header.slice("Bearer ".length).trim();
  if (!token) {
    throw new HttpError(401, "missing_bearer_token");
  }

  const tokenHash = hashToken(token);
  const res = await query<{ user_id: string; role: "PARENT" | "CHILD" }>(
    `SELECT ac.user_id, u.role
       FROM auth_credentials ac
       JOIN users u ON u.id = ac.user_id
      WHERE ac.token_hash = $1 AND ac.revoked_at IS NULL`,
    [tokenHash],
  );
  const row = res.rows[0];
  if (!row) {
    throw new HttpError(401, "invalid_or_revoked_token");
  }

  req.authUser = { id: row.user_id, role: row.role };

  // Best-effort freshness marker; failure here must never fail the request.
  void query(`UPDATE auth_credentials SET last_used_at = now() WHERE token_hash = $1`, [
    tokenHash,
  ]).catch(() => undefined);
}

export function requireRole(role: "PARENT" | "CHILD") {
  return async function (req: FastifyRequest): Promise<void> {
    if (req.authUser?.role !== role) {
      throw new HttpError(403, `requires_${role.toLowerCase()}_role`);
    }
  };
}

/** Confirms an ACTIVE parent_child_links row exists for (parentUserId, childUserId). */
export async function assertActiveLink(parentUserId: string, childUserId: string): Promise<void> {
  const res = await query(
    `SELECT 1 FROM parent_child_links
      WHERE parent_user_id = $1 AND child_user_id = $2 AND status = 'ACTIVE'`,
    [parentUserId, childUserId],
  );
  if (res.rowCount === 0) {
    throw new HttpError(403, "no_active_parent_link");
  }
}
