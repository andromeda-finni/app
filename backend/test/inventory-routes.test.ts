import assert from "node:assert/strict";
import test from "node:test";

import Fastify from "fastify";

test("broken wearables cannot be equipped and an empty vial refills for 100 coins", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { inventoryRoutes }] = await Promise.all([
    import("../src/lib/db.js"),
    import("../src/modules/inventory/routes.js"),
  ]);
  const app = Fastify();
  const originalQuery = pool.query;
  const originalConnect = pool.connect;
  let mode: "equip" | "repair" = "equip";
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
      if (mode === "equip" && text.includes("FROM inventory_items")) {
        return {
          rows: [{ item_id: "shield", durability_current: 0, is_broken: true }],
          rowCount: 1,
        };
      }
      if (mode === "repair" && text.includes("JOIN shop_items")) {
        return {
          rows: [
            {
              item_id: "vial",
              durability_current: 0,
              durability_max: 1,
              repair_cost_per_point: "100.00",
            },
          ],
          rowCount: 1,
        };
      }
      if (text.includes("SELECT balance FROM wallets")) {
        return { rows: [{ balance: 150 }], rowCount: 1 };
      }
      if (text.includes("INSERT INTO transactions")) {
        return { rows: [{ id: "repair-transaction" }], rowCount: 1 };
      }
      return { rows: [], rowCount: 1 };
    },
    release: () => undefined,
  };
  pool.connect = (async () => client) as unknown as typeof pool.connect;

  try {
    await app.register(inventoryRoutes);
    const equip = await app.inject({
      method: "POST",
      url: "/pet/equip",
      headers: { authorization: "Bearer token" },
      payload: { inventoryItemId: "11111111-1111-1111-1111-111111111111" },
    });
    assert.equal(equip.statusCode, 409);

    mode = "repair";
    statements.length = 0;
    const repair = await app.inject({
      method: "POST",
      url: "/inventory/22222222-2222-2222-2222-222222222222/repair",
      headers: { authorization: "Bearer token" },
    });
    assert.equal(repair.statusCode, 200);
    assert.equal(repair.json().repairCost, 100);
    assert.equal(repair.json().durabilityCurrent, 1);
    assert.ok(statements.some((sql) => sql.includes("event_type")));
    assert.ok(statements.some((sql) => sql.includes("SET durability_current = durability_max")));
  } finally {
    pool.query = originalQuery;
    pool.connect = originalConnect;
    await app.close();
  }
});
