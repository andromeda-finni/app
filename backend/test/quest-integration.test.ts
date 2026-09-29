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

  const createReadyChild = async (difficulty: "SIMPLE" | "ADVANCED" = "SIMPLE") => {
    const registration = await app.inject({
      method: "POST",
      url: "/auth/child/register",
      payload: { difficulty },
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
    const unreadyStart = await start("Q_TURNIP_HARVEST", unreadyHeaders);
    assert.equal(unreadyStart.statusCode, 409, unreadyStart.body);
    assert.equal(unreadyStart.json().error, "active_day_with_confirmed_plan_required");

    const tired = await createReadyChild();
    await pool.query(
      `UPDATE pets
          SET energy_level = 0,
              energy_depleted_at = statement_timestamp(),
              last_energy_tick_at = statement_timestamp()
        WHERE child_user_id = $1`,
      [tired.userId],
    );
    const tiredStart = await start("Q_TURNIP_HARVEST", tired.headers);
    assert.equal(tiredStart.statusCode, 409, tiredStart.body);
    assert.equal(tiredStart.json().error, "pet_energy_insufficient");
    assert.deepEqual(tiredStart.json().details, {
      energyLevel: 0,
      requiredEnergy: 20,
    });

    const progression = await createReadyChild();

    const locked = await start("Q_TUGRIKI_CURRENCY", progression.headers);
    assert.equal(locked.statusCode, 409, locked.body);
    assert.equal(locked.json().error, "quest_prerequisite_not_completed");

    // The map starts in the village: the mole's market opens after the turnip.
    const moleLocked = await start("Q_MOLE_FINE_PRINT", progression.headers);
    assert.equal(moleLocked.statusCode, 409, moleLocked.body);
    assert.equal(moleLocked.json().error, "quest_prerequisite_not_completed");

    const turnipStart = await start("Q_TURNIP_HARVEST", progression.headers);
    assert.equal(turnipStart.statusCode, 201, turnipStart.body);
    assert.equal(turnipStart.json().pet.energy_level, 80);
    const turnipDone = await answer(
      turnipStart.json().assignmentId as string,
      1,
      "grandmother,granddaughter,zhuchka,cat,mouse",
      progression.headers,
    );
    assert.equal(turnipDone.statusCode, 200, turnipDone.body);
    assert.equal(turnipDone.json().questCompleted, true);
    assert.equal(turnipDone.json().rewardAmount, 10);
    const turnipReplay = await answer(
      turnipStart.json().assignmentId as string,
      1,
      "grandmother,granddaughter,zhuchka,cat,mouse",
      progression.headers,
    );
    assert.equal(turnipReplay.statusCode, 200, turnipReplay.body);
    assert.equal(turnipReplay.json().rewardAlreadyGranted, true);
    assert.equal(turnipReplay.json().balanceAfter, turnipDone.json().balanceAfter);

    const completedTurnipStart = await start("Q_TURNIP_HARVEST", progression.headers);
    assert.equal(completedTurnipStart.statusCode, 200, completedTurnipStart.body);
    assert.equal(completedTurnipStart.json().completed, true);
    assert.equal(completedTurnipStart.json().rewardAlreadyGranted, true);
    const afterReplay = await pool.query<{ energy_level: number }>(
      `SELECT energy_level FROM pets WHERE child_user_id = $1`,
      [progression.userId],
    );
    assert.equal(afterReplay.rows[0]!.energy_level, 80);

    const firstStart = await start("Q_MOLE_FINE_PRINT", progression.headers);
    assert.equal(firstStart.statusCode, 201, firstStart.body);
    assert.equal(firstStart.json().nextStepNo, 1);
    assert.equal(firstStart.json().pet.energy_level, 60);
    const moleAssignmentId = firstStart.json().assignmentId as string;

    assert.equal((await answer(moleAssignmentId, 1, "12", progression.headers)).statusCode, 200);
    // A late duplicate with stale/wrong input cannot erase a success that the
    // child already earned, otherwise resume would send them backwards.
    const staleDuplicate = await answer(moleAssignmentId, 1, "8", progression.headers);
    assert.equal(staleDuplicate.statusCode, 200, staleDuplicate.body);
    assert.equal(staleDuplicate.json().outcome, "SUCCESS");
    const resumed = await start("Q_MOLE_FINE_PRINT", progression.headers);
    assert.equal(resumed.statusCode, 200, resumed.body);
    assert.equal(resumed.json().assignmentId, moleAssignmentId);
    assert.equal(resumed.json().resumed, true);
    assert.equal(resumed.json().nextStepNo, 2);
    const afterResume = await pool.query<{ energy_level: number }>(
      `SELECT energy_level FROM pets WHERE child_user_id = $1`,
      [progression.userId],
    );
    assert.equal(afterResume.rows[0]!.energy_level, 60);

    const moleAnswerCodes = ["", "12", "9", "ask", "19", "seller"];
    for (let stepNo = 2; stepNo <= 5; stepNo++) {
      const result = await answer(
        moleAssignmentId,
        stepNo,
        moleAnswerCodes[stepNo]!,
        progression.headers,
      );
      assert.equal(result.statusCode, 200, result.body);
      if (stepNo === 5) {
        assert.equal(result.json().questCompleted, true);
        assert.equal(result.json().rewardAmount, 15);
      }
    }

    const tugrikiStillLocked = await start("Q_TUGRIKI_CURRENCY", progression.headers);
    assert.equal(tugrikiStillLocked.statusCode, 409, tugrikiStillLocked.body);
    assert.equal(tugrikiStillLocked.json().error, "quest_prerequisite_not_completed");

    const bakeryStart = await start("Q_BAKERY_PROFIT", progression.headers);
    assert.equal(bakeryStart.statusCode, 201, bakeryStart.body);
    assert.equal(bakeryStart.json().rewardAmount, 12);
    const bakeryMistake = await answer(
      bakeryStart.json().assignmentId as string,
      1,
      "20",
      progression.headers,
    );
    assert.equal(bakeryMistake.statusCode, 200, bakeryMistake.body);
    assert.equal(bakeryMistake.json().outcome, "RECOVERABLE_ERROR");
    const bakeryDone = await answer(
      bakeryStart.json().assignmentId as string,
      1,
      "8",
      progression.headers,
    );
    assert.equal(bakeryDone.statusCode, 200, bakeryDone.body);
    assert.equal(bakeryDone.json().questCompleted, true);
    assert.equal(bakeryDone.json().rewardAmount, 12);

    const unlocked = await start("Q_TUGRIKI_CURRENCY", progression.headers);
    assert.equal(unlocked.statusCode, 201, unlocked.body);

    const advanced = await createReadyChild("ADVANCED");
    const advancedTurnip = await start("Q_TURNIP_HARVEST", advanced.headers);
    await answer(
      advancedTurnip.json().assignmentId as string,
      1,
      "grandmother,granddaughter,zhuchka,cat,mouse",
      advanced.headers,
    );
    const advancedMole = await start("Q_MOLE_FINE_PRINT", advanced.headers);
    const advancedMoleCodes = ["", "12", "9", "ask", "19", "seller"];
    for (let stepNo = 1; stepNo <= 5; stepNo++) {
      await answer(
        advancedMole.json().assignmentId as string,
        stepNo,
        advancedMoleCodes[stepNo]!,
        advanced.headers,
      );
    }
    const advancedBakery = await start("Q_BAKERY_PROFIT", advanced.headers);
    assert.equal(advancedBakery.statusCode, 201, advancedBakery.body);
    assert.equal(advancedBakery.json().rewardAmount, 15);

    const limited = await createReadyChild();
    const questCodes = [
      ["Q_FIRST_BUDGET", "A"],
      ["Q_SAVING_JAR", "B"],
      ["Q_SAFE_CHOICE", "B"],
      ["Q_TURNIP_HARVEST", "grandmother,granddaughter,zhuchka,cat,mouse"],
    ] as const;
    const assignments = new Map<string, string>();
    for (const [questId] of questCodes) {
      const response = await start(questId, limited.headers);
      assert.equal(response.statusCode, 201, response.body);
      assignments.set(questId, response.json().assignmentId as string);
    }

    const finishes = await Promise.all(questCodes.map(([questId, code]) =>
      answer(assignments.get(questId)!, 1, code, limited.headers)
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
