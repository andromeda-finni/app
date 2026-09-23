import assert from "node:assert/strict";
import test from "node:test";

import Fastify from "fastify";

test("PUT /pet updates the authenticated child's singleton pet on repeated submits", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { petRoutes }] = await Promise.all([
    import("../src/lib/db.js"),
    import("../src/modules/pet/routes.js"),
  ]);
  const app = Fastify();
  const originalQuery = pool.query;
  const originalConnect = pool.connect;
  const writes: unknown[][] = [];
  let profileProgressUpdates = 0;

  pool.query = (async (text: string, params: unknown[] = []) => {
    if (text.includes("FROM auth_credentials")) {
      return { rows: [{ user_id: "child-1", role: "CHILD" }], rowCount: 1 };
    }
    if (text.startsWith("UPDATE auth_credentials")) {
      return { rows: [], rowCount: 1 };
    }
    throw new Error(`Unexpected query in test: ${text}`);
  }) as typeof pool.query;

  const transactionClient = {
    query: async (text: string, params: unknown[] = []) => {
      if (text === "BEGIN" || text === "COMMIT" || text === "ROLLBACK") {
        return { rows: [], rowCount: null };
      }
      if (text.includes("INSERT INTO pets")) {
        assert.match(text, /ON CONFLICT \(child_user_id\) DO UPDATE/);
        writes.push(params);
        return { rows: [{ id: "pet-1" }], rowCount: 1 };
      }
      if (text.includes("UPDATE child_profiles")) {
        profileProgressUpdates++;
        assert.match(text, /GREATEST\(onboarding_step, 2\)/);
        return { rows: [], rowCount: 1 };
      }
      throw new Error(`Unexpected transaction query in test: ${text}`);
    },
    release: () => undefined,
  };
  pool.connect = (async () => transactionClient) as unknown as typeof pool.connect;

  try {
    await app.register(petRoutes);

    const first = await app.inject({
      method: "PUT",
      url: "/pet",
      headers: { authorization: "Bearer token" },
      payload: { petName: "Мурзик", furOptionId: "FUR_GRAY" },
    });
    const second = await app.inject({
      method: "PUT",
      url: "/pet",
      headers: { authorization: "Bearer token" },
      payload: { petName: "Рыжик", furOptionId: "FUR_ORANGE" },
    });

    assert.equal(first.statusCode, 200);
    assert.equal(second.statusCode, 200);
    assert.equal(writes.length, 2);
    assert.equal(writes[0]?.[0], "child-1");
    assert.equal(writes[1]?.[0], "child-1");
    assert.equal(writes[1]?.[1], "Рыжик");
    assert.equal(writes[1]?.[4], "FUR_ORANGE");
    assert.equal(profileProgressUpdates, 2);
  } finally {
    pool.query = originalQuery;
    pool.connect = originalConnect;
    await app.close();
  }
});
