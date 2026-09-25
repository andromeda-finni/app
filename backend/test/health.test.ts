import assert from "node:assert/strict";
import test from "node:test";

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
          latest: "0022_generic_pet_copy.sql",
        },
      ],
      rowCount: 1,
    };
  }) as typeof pool.query;

  const app = await buildApp();
  try {
    const response = await app.inject({ method: "GET", url: "/health" });

    assert.equal(response.statusCode, 200);
    assert.equal(requiredVersion, "0022_generic_pet_copy.sql");
    assert.deepEqual(response.json(), {
      ok: true,
      schemaVersion: "0022_generic_pet_copy.sql",
    });
  } finally {
    pool.query = originalQuery;
    await app.close();
  }
});
