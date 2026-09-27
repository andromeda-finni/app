import assert from "node:assert/strict";
import test from "node:test";

import Fastify from "fastify";

test("GET /economy/state returns the complete two-screen read model", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { economyRoutes }] = await Promise.all([
    import("../src/lib/db.js"),
    import("../src/modules/economy/routes.js"),
  ]);
  const app = Fastify();
  const originalQuery = pool.query;

  pool.query = (async (text: string) => {
    if (text.includes("FROM auth_credentials")) {
      return { rows: [{ user_id: "child-1", role: "CHILD" }], rowCount: 1 };
    }
    if (text.includes("FROM pets WHERE")) {
      return {
        rows: [
          {
            pet_name: "Финни",
            fur_option_id: "FUR_GRAY",
            energy_level: 80,
            joy_level: 70,
            health_level: 100,
            evolution_stage: 2,
          },
        ],
        rowCount: 1,
      };
    }
    if (text.includes("FROM wallets WHERE")) {
      return {
        rows: [
          { kind: "SPENDABLE", balance: 30 },
          { kind: "SAVINGS", balance: 12 },
        ],
        rowCount: 2,
      };
    }
    if (text.includes("FROM game_periods")) {
      return {
        rows: [
          {
            id: "period-1",
            sequence_no: 4,
            budget_plan_status: "DRAFT",
            remaining_reserve: 10,
          },
        ],
        rowCount: 1,
      };
    }
    if (text.includes("FROM financial_goals")) {
      return {
        rows: [{ name: "Воздушный змей", target_amount: 100, saved_amount: 12 }],
        rowCount: 1,
      };
    }
    if (text.includes("FROM pet_event_occurrences")) {
      return { rows: [], rowCount: 0 };
    }
    if (text.includes("FROM inventory_items")) {
      return { rows: [{ name: "Гусли-самогуды" }], rowCount: 1 };
    }
    throw new Error(`Unexpected query in test: ${text}`);
  }) as typeof pool.query;

  try {
    await app.register(economyRoutes);
    const response = await app.inject({
      method: "GET",
      url: "/economy/state",
      headers: { authorization: "Bearer token" },
    });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json(), {
      pet: {
        pet_name: "Финни",
        fur_option_id: "FUR_GRAY",
        energy_level: 80,
        joy_level: 70,
        health_level: 100,
        evolution_stage: 2,
      },
      wallets: { SPENDABLE: 30, SAVINGS: 12 },
      activeDay: {
        id: "period-1",
        sequence_no: 4,
        budget_plan_status: "DRAFT",
        remaining_reserve: 10,
      },
      activeGoal: {
        name: "Воздушный змей",
        target_amount: 100,
        saved_amount: 12,
      },
      activeEvent: null,
      inventory: [{ name: "Гусли-самогуды" }],
    });
  } finally {
    pool.query = originalQuery;
    await app.close();
  }
});
