import assert from "node:assert/strict";
import test from "node:test";

import Fastify from "fastify";

test("boots expose four quest slots and saucer exposes the reward forecast", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { questRoutes }] = await Promise.all([
    import("../src/lib/db.js"),
    import("../src/modules/quests/routes.js"),
  ]);
  const app = Fastify();
  const originalQuery = pool.query;
  let requestedLimit: unknown;

  pool.query = (async (text: string, params: unknown[] = []) => {
    if (text.includes("FROM auth_credentials")) {
      return { rows: [{ user_id: "child-1", role: "CHILD" }], rowCount: 1 };
    }
    if (text.startsWith("UPDATE auth_credentials")) {
      return { rows: [], rowCount: 1 };
    }
    if (text.includes("SELECT difficulty FROM child_profiles")) {
      return { rows: [{ difficulty: "SIMPLE" }], rowCount: 1 };
    }
    if (text.includes("AS boots_active")) {
      return {
        rows: [{ boots_active: true, saucer_active: true }],
        rowCount: 1,
      };
    }
    if (text.includes("FROM quest_definitions")) {
      requestedLimit = params[1];
      return {
        rows: [{ id: "quest-1", title: "Quest", reward_amount: 15 }],
        rowCount: 1,
      };
    }
    throw new Error(`Unexpected query: ${text}`);
  }) as typeof pool.query;

  try {
    await app.register(questRoutes);
    const response = await app.inject({
      method: "GET",
      url: "/quests",
      headers: { authorization: "Bearer token" },
    });

    assert.equal(response.statusCode, 200);
    assert.equal(requestedLimit, 4);
    assert.deepEqual(response.json()[0].forecast, {
      rewardAmount: 15,
      energyCost: null,
    });
  } finally {
    pool.query = originalQuery;
    await app.close();
  }
});
