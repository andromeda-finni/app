import pg from "pg";
import { validateAppDatabaseUrl } from "./database-config.js";

const configuredConnectionString = process.env["APP_DATABASE_URL"];
if (!configuredConnectionString) {
  throw new Error("APP_DATABASE_URL is not set — copy .env.example to .env and fill it in");
}
const connectionString = validateAppDatabaseUrl(configuredConnectionString);

// Single pool for the whole process, connected as the least-privilege
// groshik_app role (see db/migrations/0011_roles_and_grants.sql) — it has no
// DDL rights, so even a hypothetical injection cannot alter the schema.
export const pool = new pg.Pool({ connectionString });

/**
 * Every query in this codebase MUST go through this function (or a client
 * acquired from withTransaction) with values passed as the `params` array.
 * Never build SQL by concatenating/interpolating request data — that is how
 * SQL injection happens. Parameterized queries ($1, $2, ...) are what
 * actually prevents it; this wrapper exists so that rule is impossible to
 * miss in code review (grep for string concatenation next to `query(`).
 */
export function query<T extends pg.QueryResultRow = pg.QueryResultRow>(
  text: string,
  params: ReadonlyArray<unknown> = [],
): Promise<pg.QueryResult<T>> {
  return pool.query<T>(text, params as unknown[]);
}

/**
 * Runs `fn` inside a BEGIN/COMMIT block on a dedicated client, rolling back
 * on any thrown error. Use this for every mutation that touches more than
 * one table (e.g. writing a transactions row AND updating wallets.balance)
 * so the ledger can never drift out of sync with the cached balance.
 */
export async function withTransaction<T>(
  fn: (client: pg.PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await fn(client);
    await client.query("COMMIT");
    return result;
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}
