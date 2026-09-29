import assert from "node:assert/strict";
import test from "node:test";

import Fastify from "fastify";

test("equipped shield blocks an accepted scam without spending coins", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { scamOfferRoutes }] = await Promise.all([
    import("../src/lib/db.js"),
    import("../src/modules/scamOffers/routes.js"),
  ]);
  const app = Fastify();
  const originalQuery = pool.query;
  const originalConnect = pool.connect;
  const statements: string[] = [];

  pool.query = (async (text: string) => {
    if (text.includes("FROM auth_credentials")) {
      return { rows: [{ user_id: "child-1", role: "CHILD" }], rowCount: 1 };
    }
    if (text.startsWith("UPDATE auth_credentials")) {
      return { rows: [], rowCount: 1 };
    }
    throw new Error(`Unexpected pool query: ${text}`);
  }) as typeof pool.query;

  const client = {
    query: async (text: string) => {
      statements.push(text);
      if (text === "BEGIN" || text === "COMMIT" || text === "ROLLBACK") {
        return { rows: [], rowCount: null };
      }
      if (text.includes("FROM scam_offer_occurrences")) {
        return {
          rows: [
            {
              cost_if_accepted: 10,
              decline_feedback: "declined",
              accept_feedback: "accepted",
            },
          ],
          rowCount: 1,
        };
      }
      if (text.includes("FROM inventory_items i")) {
        return {
          rows: [
            {
              id: "inventory-shield",
              item_id: "shield",
              durability_current: 100,
              durability_max: 100,
            },
          ],
          rowCount: 1,
        };
      }
      if (text.includes("FROM artifact_effect_events")) {
        return { rows: [], rowCount: 0 };
      }
      return { rows: [], rowCount: 1 };
    },
    release: () => undefined,
  };
  pool.connect = (async () => client) as unknown as typeof pool.connect;

  try {
    await app.register(scamOfferRoutes);
    const response = await app.inject({
      method: "POST",
      url: "/scam-offers/11111111-1111-1111-1111-111111111111/respond",
      headers: { authorization: "Bearer token" },
      payload: { decision: "ACCEPTED" },
    });

    assert.equal(response.statusCode, 200);
    assert.equal(response.json().status, "BLOCKED_BY_SHIELD");
    assert.equal(response.json().costPaid, 0);
    assert.equal(response.json().artifactEffect.durabilityCurrent, 80);
    assert.ok(!statements.some((sql) => sql.includes("INSERT INTO transactions")));
  } finally {
    pool.query = originalQuery;
    pool.connect = originalConnect;
    await app.close();
  }
});
