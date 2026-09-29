import assert from "node:assert/strict";
import { readdirSync } from "node:fs";
import test from "node:test";

// The newest file in db/migrations must be among the versions /health
// demands; pinning a name here would let a new migration ship without
// REQUIRED_SCHEMA_VERSIONS moving.
const LATEST_MIGRATION = readdirSync(new URL("../../db/migrations/", import.meta.url))
  .filter((name) => name.endsWith(".sql"))
  .sort()
  .at(-1)!;

async function healthWith(missing: string[]) {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { buildApp }] = await Promise.all([
    import("../src/lib/db.js"),
    import("../src/app.js"),
  ]);
  const originalQuery = pool.query;
  let requiredVersions: unknown;

  pool.query = (async (_text: string, params: unknown[] = []) => {
    requiredVersions = params[0];
    return { rows: [{ missing, latest: LATEST_MIGRATION }], rowCount: 1 };
  }) as typeof pool.query;

  const app = await buildApp();
  try {
    const response = await app.inject({ method: "GET", url: "/health" });
    return { response, requiredVersions };
  } finally {
    pool.query = originalQuery;
    await app.close();
  }
}

test("health requires the latest migration used by this build", async () => {
  const { response, requiredVersions } = await healthWith([]);

  assert.equal(response.statusCode, 200);
  assert.ok(Array.isArray(requiredVersions));
  assert.ok((requiredVersions as string[]).includes(LATEST_MIGRATION));
  assert.deepEqual(response.json(), { ok: true, schemaVersion: LATEST_MIGRATION });
});

test("health is not ready while any required migration is missing", async () => {
  const { response } = await healthWith(["0027_artifact_durability.sql"]);

  assert.equal(response.statusCode, 503);
  assert.deepEqual(response.json().missing, ["0027_artifact_durability.sql"]);
});
