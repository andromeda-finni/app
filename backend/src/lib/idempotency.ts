import { createHash } from "node:crypto";
import type { PoolClient } from "pg";
import { HttpError } from "./errors.js";

/**
 * Stable fingerprint of the parameters a request was made with, so a key
 * replayed with a *different* payload is rejected instead of silently
 * returning the first request's answer. Keys are sorted so property order in
 * the incoming JSON can't change the fingerprint.
 */
export function fingerprintOf(params: Record<string, unknown>): string {
  const canonical = JSON.stringify(params, Object.keys(params).sort());
  return createHash("sha256").update(canonical).digest("hex");
}

export interface IdempotentOutcome<T> {
  result: T;
  replayed: boolean;
}

/**
 * Runs `operation` at most once per (child, scope, key), even under concurrent
 * retries, and returns the original result for every subsequent call.
 *
 * Must be called with a client already inside a transaction: claiming the key
 * and performing the work have to commit together, or a crash between them
 * would burn the key without doing the work.
 *
 * Concurrency is delegated to Postgres rather than to an application-level
 * check. `INSERT ... ON CONFLICT DO NOTHING` blocks while a competing
 * transaction holds an uncommitted row for the same key, so the loser resumes
 * only once the winner has committed (and then replays its stored response) or
 * rolled back (and then wins the claim itself). No window exists in which both
 * callers believe the key is unused.
 */
export async function withIdempotency<T>(
  client: PoolClient,
  args: {
    childUserId: string;
    scope: string;
    key: string;
    params: Record<string, unknown>;
  },
  operation: () => Promise<T>,
): Promise<IdempotentOutcome<T>> {
  const fingerprint = fingerprintOf(args.params);

  const claim = await client.query(
    `INSERT INTO idempotency_keys (child_user_id, scope, idempotency_key, request_fingerprint)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (child_user_id, scope, idempotency_key) DO NOTHING
     RETURNING 1`,
    [args.childUserId, args.scope, args.key, fingerprint],
  );

  if (claim.rowCount === 0) {
    const prior = await client.query<{ request_fingerprint: string; response_json: T | null }>(
      `SELECT request_fingerprint, response_json
         FROM idempotency_keys
        WHERE child_user_id = $1 AND scope = $2 AND idempotency_key = $3
        FOR UPDATE`,
      [args.childUserId, args.scope, args.key],
    );
    const row = prior.rows[0]!;

    if (row.request_fingerprint !== fingerprint) {
      throw new HttpError(409, "idempotency_key_reused_with_different_params");
    }
    return { result: row.response_json as T, replayed: true };
  }

  const result = await operation();

  await client.query(
    `UPDATE idempotency_keys
        SET response_json = $4::jsonb, completed_at = now()
      WHERE child_user_id = $1 AND scope = $2 AND idempotency_key = $3`,
    [args.childUserId, args.scope, args.key, JSON.stringify(result)],
  );

  return { result, replayed: false };
}
