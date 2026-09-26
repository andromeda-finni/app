import assert from "node:assert/strict";
import test from "node:test";
import Fastify from "fastify";

// Opt in with a disposable, migrated and seeded DB. Never uses the app's .env.
test("quest prerequisites, resume position and daily reward limit are enforced by the server", {
  skip: !process.env["ECONOMY_TEST_DATABASE_URL"],
}, async () => {
  process.env["APP_DATABASE_URL"] = process.env["ECONOMY_TEST_DATABASE_URL"]!;
  const { pool } = await import("../src/lib/db.js");
  const { HttpError } = await import("../src/lib/errors.js");
  const { authRoutes } = await import("../src/auth/routes.js");
  const { petRoutes } = await import("../src/modules/pet/routes.js");
  const { goalRoutes } = await import("../src/modules/goals/routes.js");
  const { periodRoutes } = await import("../src/modules/periods/routes.js");
  const { questRoutes } = await import("../src/modules/quests/routes.js");

  const app = Fastify({ ajv: { customOptions: { removeAdditional: false } } });
  app.setErrorHandler((error, _req, reply) => {
    if (error instanceof HttpError) {
      reply.code(error.statusCode).send({ error: error.code, details: error.details });
    } else {
      reply.code((error as { statusCode?: number }).statusCode ?? 500).send({ error: String(error) });
    }
  });
  for (const routes of [authRoutes, petRoutes, goalRoutes, periodRoutes, questRoutes]) {
    await app.register(routes);
  }

  const request = async (
    method: "GET" | "POST" | "PUT",
    url: string,
    headers: Record<string, string>,
    payload: object = {},
  ) => app.inject({ method, url, headers, payload });

  const createReadyChild = async () => {
    const registration = await app.inject({
      method: "POST",
      url: "/auth/child/register",
      payload: {},
    });
    assert.equal(registration.statusCode, 201, registration.body);
    const { token, userId } = registration.json();
    const headers = { authorization: `Bearer ${token}` };

    assert.equal((await request("PUT", "/pet", headers, {
      petName: "Тест",
      furOptionId: "FUR_GRAY",
    })).statusCode, 200);
    assert.equal((await request("POST", "/goals", headers, {
      targetItemId: "saucer",
    })).statusCode, 201);
    const period = await request("POST", "/periods", headers);
    assert.equal(period.statusCode, 201, period.body);
    const periodId = period.json().periodId as string;
    assert.equal((await request("PUT", `/periods/${periodId}/budget-plan`, headers, {
      needAmount: 10,
      wantAmount: 20,
      savingsAmount: 0,
    })).statusCode, 200);
    assert.equal((await request("POST", `/periods/${periodId}/budget-plan/confirm`, headers)).statusCode, 200);

    return { headers, userId: userId as string, periodId };
  };

  const start = (questId: string, headers: Record<string, string>) =>
    request("POST", `/quests/${questId}/start`, headers);
  const answer = (
    assignmentId: string,
    stepNo: number,
    selectedOptionCode: string,
    headers: Record<string, string>,
  ) => request("POST", `/assignments/${assignmentId}/answer`, headers, {
    stepNo,
    selectedOptionCode,
  });

  try {
    const unreadyRegistration = await app.inject({
      method: "POST",
      url: "/auth/child/register",
      payload: {},
    });
    assert.equal(unreadyRegistration.statusCode, 201, unreadyRegistration.body);
    const unreadyHeaders = {
      authorization: `Bearer ${unreadyRegistration.json().token as string}`,
    };
    assert.equal((await request("PUT", "/pet", unreadyHeaders, {
      petName: "Без плана",
      furOptionId: "FUR_GRAY",
    })).statusCode, 200);
    const unreadyStart = await start("Q_MOLE_FINE_PRINT", unreadyHeaders);
    assert.equal(unreadyStart.statusCode, 409, unreadyStart.body);
    assert.equal(unreadyStart.json().error, "active_day_with_confirmed_plan_required");

    const progression = await createReadyChild();

    const locked = await start("Q_TUGRIKI_CURRENCY", progression.headers);
    assert.equal(locked.statusCode, 409, locked.body);
    assert.equal(locked.json().error, "quest_prerequisite_not_completed");

    const firstStart = await start("Q_MOLE_FINE_PRINT", progression.headers);
    assert.equal(firstStart.statusCode, 201, firstStart.body);
    assert.equal(firstStart.json().nextStepNo, 1);
    const moleAssignmentId = firstStart.json().assignmentId as string;

    assert.equal((await answer(moleAssignmentId, 1, "VERIFIED", progression.headers)).statusCode, 200);
    const resumed = await start("Q_MOLE_FINE_PRINT", progression.headers);
    assert.equal(resumed.statusCode, 200, resumed.body);
    assert.equal(resumed.json().assignmentId, moleAssignmentId);
    assert.equal(resumed.json().resumed, true);
    assert.equal(resumed.json().nextStepNo, 2);

    for (let stepNo = 2; stepNo <= 5; stepNo++) {
      const result = await answer(moleAssignmentId, stepNo, "VERIFIED", progression.headers);
      assert.equal(result.statusCode, 200, result.body);
      if (stepNo === 5) {
        assert.equal(result.json().questCompleted, true);
        assert.equal(result.json().rewardAmount, 15);
      }
    }

    const unlocked = await start("Q_TUGRIKI_CURRENCY", progression.headers);
    assert.equal(unlocked.statusCode, 201, unlocked.body);

    const limited = await createReadyChild();
    const questCodes = [
      ["Q_FIRST_BUDGET", "A"],
      ["Q_SAVING_JAR", "B"],
      ["Q_SAFE_CHOICE", "B"],
      ["Q_MOLE_FINE_PRINT", "VERIFIED"],
    ] as const;
    const assignments = new Map<string, string>();
    for (const [questId] of questCodes) {
      const response = await start(questId, limited.headers);
      assert.equal(response.statusCode, 201, response.body);
      assignments.set(questId, response.json().assignmentId as string);
    }
    const limitMoleId = assignments.get("Q_MOLE_FINE_PRINT")!;
    for (let stepNo = 1; stepNo <= 4; stepNo++) {
      const result = await answer(limitMoleId, stepNo, "VERIFIED", limited.headers);
      assert.equal(result.statusCode, 200, result.body);
    }

    const finishes = await Promise.all(questCodes.map(([questId, code]) =>
      answer(
        assignments.get(questId)!,
        questId === "Q_MOLE_FINE_PRINT" ? 5 : 1,
        code,
        limited.headers,
      )
    ));
    assert.deepEqual(finishes.map((response) => response.statusCode).sort(), [200, 200, 200, 409]);
    const refused = finishes.find((response) => response.statusCode === 409)!;
    assert.equal(refused.json().error, "daily_quest_reward_limit_reached");

    const paid = await pool.query<{ count: number }>(
      `SELECT COUNT(*)::int AS count FROM transactions
        WHERE child_user_id = $1 AND event_type = 'QUEST_REWARD'`,
      [limited.userId],
    );
    assert.equal(paid.rows[0]!.count, 3);
    const completed = await pool.query<{ count: number }>(
      `SELECT COUNT(*)::int AS count FROM assignments
        WHERE child_user_id = $1 AND origin = 'SYSTEM' AND status = 'COMPLETED'`,
      [limited.userId],
    );
    assert.equal(completed.rows[0]!.count, 3);
  } finally {
    await app.close();
    await pool.end();
  }
});
