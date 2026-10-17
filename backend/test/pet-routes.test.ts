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
  let completed = false;

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
      if (text.includes('FOR UPDATE OF cp')) {
        assert.equal(params[0], 'child-1');
        return { rows: [{ onboarding_completed_at: completed ? new Date() : null, fur_option_id: 'FUR_ORANGE', accessory_option_id: 'ACC_COLLAR_BLUE' }], rowCount: 1 };
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
      payload: { petName: "Рыжик", furOptionId: "FUR_ORANGE", accessoryOptionId: 'ACC_COLLAR_BLUE' },
    });

    assert.equal(first.statusCode, 200);
    assert.equal(second.statusCode, 200);
    assert.equal(writes.length, 2);
    assert.equal(writes[0]?.[0], "child-1");
    assert.equal(writes[1]?.[0], "child-1");
    assert.equal(writes[1]?.[1], "Рыжик");
    assert.equal(writes[1]?.[4], "FUR_ORANGE");
    assert.equal(profileProgressUpdates, 2);
    assert.equal(writes[1]?.[5], 'ACC_COLLAR_BLUE');

    completed = true;
    for (const appearance of [
      { furOptionId: 'FUR_GRAY', accessoryOptionId: 'ACC_COLLAR_BLUE' },
    ]) {
      const locked = await app.inject({
        method: 'PUT', url: '/pet', headers: { authorization: 'Bearer token' },
        payload: { petName: 'Рыжик', ...appearance },
      });
      assert.equal(locked.statusCode, 409);
    }
    assert.equal(writes.length, 2);
    const changeCollar = await app.inject({
      method: 'PUT', url: '/pet', headers: { authorization: 'Bearer token' },
      payload: { petName: 'Рыжик', furOptionId: 'FUR_ORANGE', accessoryOptionId: 'ACC_COLLAR_GREEN' },
    });
    assert.equal(changeCollar.statusCode, 200);
    assert.equal(writes[2]?.[5], 'ACC_COLLAR_GREEN');
    const invalidCollar = await app.inject({
      method: 'PUT', url: '/pet', headers: { authorization: 'Bearer token' },
      payload: { petName: 'Рыжик', furOptionId: 'FUR_ORANGE', accessoryOptionId: 'ACC_FAKE' },
    });
    assert.equal(invalidCollar.statusCode, 400);
    const rename = await app.inject({
      method: 'PUT', url: '/pet', headers: { authorization: 'Bearer token' },
      payload: { petName: 'Мурзик', furOptionId: 'FUR_ORANGE', accessoryOptionId: 'ACC_COLLAR_BLUE' },
    });
    assert.equal(rename.statusCode, 200);
    assert.equal(writes.length, 4);
  } finally {
    pool.query = originalQuery;
    pool.connect = originalConnect;
    await app.close();
  }
});
