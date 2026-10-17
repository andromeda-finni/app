import assert from "node:assert/strict";
import test from "node:test";
import Fastify from "fastify";

import { isQuestRewardAllowed, MOLE_QUEST_REWARD } from "../src/modules/economy/rules.js";

test("twenty coins are reserved for the five-step Mole quest", () => {
  assert.equal(MOLE_QUEST_REWARD, 20);
  assert.equal(isQuestRewardAllowed("Q_MOLE_FINE_PRINT", 20), true);
  // Existing assignment snapshots remain payable during rollout.
  assert.equal(isQuestRewardAllowed("Q_MOLE_FINE_PRINT", 15), true);
  assert.equal(isQuestRewardAllowed("Q_BAKERY_PROFIT", 20), false);
  assert.equal(isQuestRewardAllowed("Q_MOLE_FINE_PRINT", 21), false);
  assert.equal(isQuestRewardAllowed("Q_MOLE_FINE_PRINT", -20), false);
});

test("the final Mole answer credits twenty coins once and reports the same balance on retry", async () => {
  process.env["APP_DATABASE_URL"] = "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { questRoutes }] = await Promise.all([
    import("../src/lib/db.js"),
    import("../src/modules/quests/routes.js"),
  ]);
  const app = Fastify();
  const originalQuery = pool.query;
  const originalConnect = pool.connect;
  const assignmentId = "a5d41435-0bca-4396-8cf3-268c29a59ee4";
  let completed = false;
  let balance = 30;
  let credits = 0;
  let priorSuccesses = 3;
  const statements: string[] = [];

  pool.query = (async (sql: string) => {
    if (sql.includes("FROM auth_credentials")) {
      return { rows: [{ user_id: "child-1", role: "CHILD" }], rowCount: 1 };
    }
    if (sql.startsWith("UPDATE auth_credentials")) return { rows: [], rowCount: 1 };
    throw new Error(`Unexpected pool query: ${sql}`);
  }) as typeof pool.query;
  const transactionClient = {
    query: async (sql: string, args: unknown[] = []) => {
      statements.push(sql);
      if (["BEGIN", "COMMIT", "ROLLBACK"].includes(sql)) return { rows: [], rowCount: null };
      if (sql.includes("FROM assignments a")) {
        assert.match(sql, /FOR UPDATE OF a/);
        return { rows: [{ quest_id: "Q_MOLE_FINE_PRINT", reward_amount: 20,
          status: completed ? "COMPLETED" : "IN_PROGRESS", balance_after: completed ? balance : null }], rowCount: 1 };
      }
      if (sql.includes("SELECT COUNT(*) FROM quest_step_progress")) return { rows: [{ count: String(priorSuccesses) }], rowCount: 1 };
      if (sql.includes("SELECT success_feedback")) return { rows: [{ success_feedback: "Верно", recovery_feedback: "Попробуй ещё", ui_spec: { correctOptionCode: "seller" } }], rowCount: 1 };
      if (sql.includes("SELECT outcome FROM quest_step_progress")) return { rows: [], rowCount: 0 };
      if (sql.includes("INSERT INTO quest_step_progress")) return { rows: [], rowCount: 1 };
      if (sql.includes("SELECT MAX(step_no)")) return { rows: [{ max_step: 5 }], rowCount: 1 };
      if (sql.includes("SELECT gp.id")) return { rows: [{ id: "period-1" }], rowCount: 1 };
      if (sql.includes("SELECT 1 FROM pets") || sql.includes("FROM inventory_items")) return { rows: [], rowCount: 0 };
      if (sql.includes("SELECT COUNT(*) AS paid")) return { rows: [{ paid: "0" }], rowCount: 1 };
      if (sql.includes("SELECT balance FROM wallets")) {
        assert.match(sql, /FOR UPDATE/);
        return { rows: [{ balance }], rowCount: 1 };
      }
      if (sql.includes("INSERT INTO transactions")) {
        assert.equal(args[2], "QUEST_REWARD");
        assert.equal(args[3], 20);
        assert.equal(args[4], 50);
        assert.equal(args[7], `quest-reward:${assignmentId}`);
        credits++;
        return { rows: [{ id: "reward-1" }], rowCount: 1 };
      }
      if (sql.includes("UPDATE wallets")) { balance = args[0] as number; return { rows: [], rowCount: 1 }; }
      if (sql.includes("UPDATE assignments")) { completed = true; return { rows: [], rowCount: 1 }; }
      throw new Error(`Unexpected transaction query: ${sql}`);
    },
    release: () => undefined,
  };
  pool.connect = (async () => transactionClient) as unknown as typeof pool.connect;

  try {
    await app.register(questRoutes);
    const answer = () => app.inject({ method: "POST", url: `/assignments/${assignmentId}/answer`,
      headers: { authorization: "Bearer token" }, payload: { stepNo: 5, selectedOptionCode: "seller" } });
    // Four successful predecessors are required even with the new reward.
    const premature = await answer();
    assert.equal(premature.statusCode, 409, premature.body);
    assert.equal(credits, 0);
    priorSuccesses = 4;
    const success = await answer();
    assert.equal(success.statusCode, 200, success.body);
    assert.equal(success.json().rewardAmount, 20);
    assert.equal(success.json().balanceAfter, 50);
    assert.equal(success.json().questCompleted, true);
    assert.equal(statements.at(-1), "COMMIT");
    const retry = await answer();
    assert.equal(retry.statusCode, 200, retry.body);
    assert.equal(retry.json().rewardAlreadyGranted, true);
    assert.equal(retry.json().balanceAfter, 50);
    assert.equal(credits, 1);
    assert.equal(balance, 50);
  } finally {
    pool.query = originalQuery;
    pool.connect = originalConnect;
    await app.close();
    await pool.end();
  }
});
