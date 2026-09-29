import assert from "node:assert/strict";
import test from "node:test";

import Fastify from "fastify";

test("horseshoe returns rounded-up cashback and loses durability on NEED purchases", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { shopRoutes }] = await Promise.all([
    import("../src/lib/db.js"),
    import("../src/modules/shop/routes.js"),
  ]);
  const app = Fastify();
  const originalQuery = pool.query;
  const originalConnect = pool.connect;
  let balance = 100;
  let transactionCount = 0;

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
    query: async (text: string, params: unknown[] = []) => {
      if (text === "BEGIN" || text === "COMMIT" || text === "ROLLBACK") {
        return { rows: [], rowCount: null };
      }
      if (text.includes("INSERT INTO idempotency_keys")) {
        return { rows: [{ "?column?": 1 }], rowCount: 1 };
      }
      if (text.includes("SELECT kind, price") && text.includes("FROM shop_items")) {
        return {
          rows: [{ kind: "NEED", price: 11, energy_delta: 10, joy_delta: 0 }],
          rowCount: 1,
        };
      }
      if (text.includes("JOIN budget_plans bp")) {
        return {
          rows: [{ id: "day-1", need_amount: 10, required_need_amount: 10 }],
          rowCount: 1,
        };
      }
      if (text.includes("SELECT balance FROM wallets")) {
        return { rows: [{ balance }], rowCount: 1 };
      }
      if (text.includes("INSERT INTO transactions")) {
        transactionCount++;
        return { rows: [{ id: `transaction-${transactionCount}` }], rowCount: 1 };
      }
      if (text.includes("UPDATE wallets SET balance")) {
        balance = Number(params[0]);
        return { rows: [], rowCount: 1 };
      }
      if (text.includes("INSERT INTO purchases")) {
        return { rows: [{ id: "purchase-1" }], rowCount: 1 };
      }
      if (text.includes("WITH locked_pet AS")) {
        const now = new Date("2026-09-29T12:00:00.000Z");
        return {
          rows: [
            {
              id: "pet-1",
              child_user_id: "child-1",
              pet_name: "Финни",
              pet_name_status: "APPROVED",
              fur_option_id: "FUR_GRAY",
              accessory_option_id: null,
              energy_level: 80,
              joy_level: 70,
              health_level: 100,
              evolution_stage: 2,
              successful_period_streak: 0,
              equipped_inventory_item_id: null,
              energy_depleted_at: null,
              last_energy_tick_at: now,
              created_at: now,
              updated_at: now,
              mode: "STANDARD",
              server_now: now,
            },
          ],
          rowCount: 1,
        };
      }
      if (text.includes("FROM inventory_items i")) {
        return {
          rows: [
            {
              id: "inventory-horseshoe",
              item_id: "horseshoe",
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
    await app.register(shopRoutes);
    const response = await app.inject({
      method: "POST",
      url: "/purchases",
      headers: { authorization: "Bearer token" },
      payload: { itemId: "FOOD_APPLE", idempotencyKey: "purchase-1" },
    });

    assert.equal(response.statusCode, 201);
    assert.equal(response.json().cashbackAmount, 2);
    assert.equal(response.json().balanceAfter, 91);
    assert.equal(response.json().artifactEffect.durabilityCurrent, 95);
  } finally {
    pool.query = originalQuery;
    pool.connect = originalConnect;
    await app.close();
  }
});
