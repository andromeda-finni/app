import assert from "node:assert/strict";
import { readdirSync } from "node:fs";
import test from "node:test";

// The newest file in db/migrations is what /health must demand; pinning a name
// here would let a new migration ship without REQUIRED_SCHEMA_VERSION moving.
const LATEST_MIGRATION = readdirSync(new URL("../../db/migrations/", import.meta.url))
  .filter((name) => name.endsWith(".sql"))
  .sort()
  .at(-1)!;

test("health requires the latest migration used by this build", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { buildApp }] = await Promise.all([
    import("../src/lib/db.js"),
    import("../src/app.js"),
  ]);
  const originalQuery = pool.query;
  let requiredVersion: unknown;

  pool.query = (async (_text: string, params: unknown[] = []) => {
    requiredVersion = params[0];
    return {
      rows: [
        {
          required_present: true,
          latest: LATEST_MIGRATION,
        },
      ],
      rowCount: 1,
    };
  }) as typeof pool.query;

  const app = await buildApp();
  try {
    const response = await app.inject({ method: "GET", url: "/health" });

    assert.equal(response.statusCode, 200);
    assert.equal(requiredVersion, LATEST_MIGRATION);
    assert.deepEqual(response.json(), {
      ok: true,
      schemaVersion: LATEST_MIGRATION,
    });
  } finally {
    pool.query = originalQuery;
    await app.close();
  }
});
