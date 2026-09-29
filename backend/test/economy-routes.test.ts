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
    if (text.includes("FROM child_profiles")) {
      return { rows: [{ mode: "STANDARD" }], rowCount: 1 };
    }
    if (text.includes("UPDATE financial_goals")) {
      return { rows: [], rowCount: 0 };
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
    if (text.includes("FROM game_periods gp")) {
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
    if (text.includes("FROM insurance_policies")) {
      return { rows: [], rowCount: 0 };
    }
    if (text.includes("FROM frost_chests")) {
      return { rows: [], rowCount: 0 };
    }
    if (text.includes("FROM shop_items")) {
      return { rows: [], rowCount: 0 };
    }
    if (text.includes("FROM inventory_items")) {
      return { rows: [{ name: "Гусли-самогуды" }], rowCount: 1 };
    }
    if (
      text.includes("FROM transactions") ||
      text.includes("FROM period_results") ||
      text.includes("FROM quest_definitions") ||
      text.includes("FROM assignments")
    ) {
      return { rows: [], rowCount: 0 };
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
      mode: "STANDARD",
      rules: {
        dailyIncome: 30,
        foodReserve: 10,
        daysPerWeek: 7,
        questRewards: [10, 12, 15],
        dailyQuestLimit: 3,
        bootsQuestLimit: 4,
        parentRewardLimit: 10,
        savingsTransferAmounts: [5, 10],
        eventProbability: 0.7,
        firstEventDay: 2,
        minimumEventCost: 2,
        maximumEventCost: 20,
        insurancePremium: 5,
        frostMinimum: 10,
        frostMaximum: 50,
        frostStep: 10,
        frostDays: 5,
        frostBonusPercent: 10,
      },
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
        week: 1,
        day_of_week: 4,
      },
      activeGoal: {
        name: "Воздушный змей",
        target_amount: 100,
        saved_amount: 12,
      },
      activeEvent: null,
      activeInsurance: null,
      activeFrostChest: null,
      shopItems: [],
      artifacts: [],
      inventory: [{ name: "Гусли-самогуды" }],
      quests: [],
      parentTasks: [],
      recentTransactions: [],
      recentDays: [],
      savingsHistory: [],
    });
  } finally {
    pool.query = originalQuery;
    await app.close();
  }
});
