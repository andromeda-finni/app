import assert from "node:assert/strict";
import test from "node:test";

import Fastify from "fastify";

test("rolling a pet event changes health atomically and rolls back on failure", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { petEventRoutes }] = await Promise.all([
    import("../src/lib/db.js"),
    import("../src/modules/petEvents/routes.js"),
  ]);
  const app = Fastify();
  const originalQuery = pool.query;
  const originalConnect = pool.connect;
  const originalRandom = Math.random;
  let failHealthUpdate = false;
  let statements: string[] = [];

  pool.query = (async (text: string) => {
    if (text.includes("FROM auth_credentials")) {
      return { rows: [{ user_id: "child-1", role: "CHILD" }], rowCount: 1 };
    }
    if (text.startsWith("UPDATE auth_credentials")) {
      return { rows: [], rowCount: 1 };
    }
    throw new Error(`Unexpected pool query in test: ${text}`);
  }) as typeof pool.query;

  const transactionClient = {
    query: async (text: string) => {
      statements.push(text);
      if (text === "BEGIN" || text === "COMMIT" || text === "ROLLBACK") {
        return { rows: [], rowCount: null };
      }
      if (text.includes("SELECT id FROM pets")) {
        assert.match(text, /FOR UPDATE/);
        return { rows: [{ id: "pet-1" }], rowCount: 1 };
      }
      if (text.includes("SELECT 1 FROM pet_event_occurrences")) {
        return { rows: [], rowCount: 0 };
      }
      if (text.includes("FROM pet_event_definitions")) {
        return {
          rows: [{ id: "SICK", cost_amount: 15, trigger_weight: 10 }],
          rowCount: 1,
        };
      }
      if (text.includes("FROM game_periods")) {
        return { rows: [], rowCount: 0 };
      }
      if (text.includes("INSERT INTO pet_event_occurrences")) {
        return { rows: [{ id: "event-1" }], rowCount: 1 };
      }
      if (text.includes("UPDATE pets SET health_level")) {
        if (failHealthUpdate) throw new Error("health update failed");
        return { rows: [], rowCount: 1 };
      }
      throw new Error(`Unexpected transaction query in test: ${text}`);
    },
    release: () => undefined,
  };
  pool.connect = (async () => transactionClient) as unknown as typeof pool.connect;
  Math.random = () => 0;

  try {
    await app.register(petEventRoutes);

    const success = await app.inject({
      method: "POST",
      url: "/pet-events/roll",
      headers: { authorization: "Bearer token" },
    });
    assert.equal(success.statusCode, 200);
    assert.deepEqual(success.json(), { triggered: true, occurrenceId: "event-1" });
    assert.equal(statements[0], "BEGIN");
    assert.equal(statements.at(-1), "COMMIT");
    assert.ok(
      statements.findIndex((sql) => sql.includes("INSERT INTO pet_event_occurrences")) <
        statements.findIndex((sql) => sql.includes("UPDATE pets SET health_level")),
    );

    statements = [];
    failHealthUpdate = true;
    const failed = await app.inject({
      method: "POST",
      url: "/pet-events/roll",
      headers: { authorization: "Bearer token" },
    });
    assert.equal(failed.statusCode, 500);
    assert.equal(statements.at(-1), "ROLLBACK");
    assert.ok(!statements.includes("COMMIT"));
  } finally {
    Math.random = originalRandom;
    pool.query = originalQuery;
    pool.connect = originalConnect;
    await app.close();
  }
});
