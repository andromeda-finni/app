import assert from "node:assert/strict";
import test from "node:test";
import Fastify from "fastify";
import { QUEST_TRACKS } from "../src/modules/quests/dailySelection.js";

test("daily snapshots, carry-over, zero-energy resume, reward replay and ownership", {
  skip: !process.env["DAILY_QUEST_TEST_DATABASE_URL"],
}, async () => {
  process.env["APP_DATABASE_URL"] = process.env["DAILY_QUEST_TEST_DATABASE_URL"]!;
  const { pool } = await import("../src/lib/db.js");
  const { HttpError } = await import("../src/lib/errors.js");
  const { authRoutes } = await import("../src/auth/routes.js");
  const { petRoutes } = await import("../src/modules/pet/routes.js");
  const { goalRoutes } = await import("../src/modules/goals/routes.js");
  const { periodRoutes } = await import("../src/modules/periods/routes.js");
  const { questRoutes } = await import("../src/modules/quests/routes.js");
  const app = Fastify({ ajv: { customOptions: { removeAdditional: false } } });
  app.setErrorHandler((error, _req, reply) => {
    if (error instanceof HttpError) reply.code(error.statusCode).send({ error: error.code, details: error.details });
    else reply.code(500).send({ error: String(error) });
  });
  for (const routes of [authRoutes, petRoutes, goalRoutes, periodRoutes, questRoutes]) await app.register(routes);
  const child = async (difficulty = "SIMPLE") => {
    const registered = await app.inject({ method: "POST", url: "/auth/child/register", payload: { difficulty } });
    assert.equal(registered.statusCode, 201, registered.body);
    const headers = { authorization: `Bearer ${registered.json().token as string}` };
    const userId = registered.json().userId as string;
    const send = (method: "GET" | "POST" | "PUT", url: string, payload?: object) => app.inject({ method, url, headers, ...(payload ? { payload } : {}) });
    assert.equal((await send("PUT", "/pet", { petName: "Тест", furOptionId: "FUR_GRAY" })).statusCode, 200);
    assert.equal((await send("POST", "/goals", { targetItemId: "saucer" })).statusCode, 201);
    const day = async () => {
      const opened = await send("POST", "/periods");
      assert.equal(opened.statusCode, 201, opened.body);
      const id = opened.json().periodId as string;
      assert.equal((await send("PUT", `/periods/${id}/budget-plan`, { needAmount: Number(opened.json().grantAmount), wantAmount: 0, savingsAmount: 0 })).statusCode, 200);
      const confirmed = await send("POST", `/periods/${id}/budget-plan/confirm`);
      assert.equal(confirmed.statusCode, 200, confirmed.body);
      return id;
    };
    await day();
    return { send, userId, day };
  };
  type Offer = {
    trackId: string; questId: string; status: string; assignmentId: string | null; stepCount: number;
  };
  try {
    assert.equal((await app.inject({ method: "GET", url: "/quests/day" })).statusCode, 401);
    const a = await child();
    const results = await Promise.all(Array.from({ length: 5 }, () => a.send("GET", "/quests/day")));
    for (const result of results) assert.equal(result.statusCode, 200, result.body);
    const snapshot = results[0]!.json();
    for (const result of results) assert.deepEqual(result.json(), snapshot);
    const offers = snapshot.offers as Offer[];
    assert.equal(offers.length, 3);
    assert.equal(new Set(offers.map(row => row.trackId)).size, 3);
    // The offline app pays the reward on the last step, so it must know it.
    const { pool } = await import("../src/lib/db.js");
    for (const offer of offers) {
      const steps = await pool.query<{ count: number }>(
        `SELECT COUNT(*)::int AS count FROM quest_steps WHERE quest_id = $1`, [offer.questId],
      );
      assert.equal(offer.stepCount, steps.rows[0]!.count, offer.questId);
    }
    const excluded = QUEST_TRACKS.flatMap(track => track.simple).find(id => !offers.some(row => row.questId === id))!;
    const refused = await a.send("POST", `/quests/${excluded}/start`);
    assert.equal(refused.statusCode, 409, refused.body);
    const first = offers[0]!;
    const starts = await Promise.all([a.send("POST", `/quests/${first.questId}/start`), a.send("POST", `/quests/${first.questId}/start`)]);
    for (const start of starts) assert.ok([200, 201].includes(start.statusCode), start.body);
    const assignmentId = starts[0]!.json().assignmentId as string;
    assert.equal(starts[1]!.json().assignmentId, assignmentId);
    const energy = await pool.query<{ energy_level: number }>("SELECT energy_level FROM pets WHERE child_user_id = $1", [a.userId]);
    assert.equal(energy.rows[0]!.energy_level, 80);
    await pool.query("UPDATE pets SET energy_level = 0, last_energy_tick_at = statement_timestamp() WHERE child_user_id = $1", [a.userId]);
    const resumed = await a.send("POST", `/quests/${first.questId}/start`);
    assert.equal(resumed.statusCode, 200, resumed.body);
    assert.equal(resumed.json().resumed, true);
    const tired = await a.send("POST", `/quests/${offers[1]!.questId}/start`);
    assert.equal(tired.statusCode, 409, tired.body);
    assert.equal(tired.json().error, "pet_energy_insufficient");
    // Move only the isolated fixture's game period, never wall-clock time.
    await pool.query("UPDATE game_periods SET status = 'COMPLETED', closed_at = now() WHERE id = $1 AND child_user_id = $2", [snapshot.periodId, a.userId]);
    await a.day();
    const tomorrowResponse = await a.send("GET", "/quests/day");
    assert.equal(tomorrowResponse.statusCode, 200, tomorrowResponse.body);
    const tomorrow = tomorrowResponse.json();
    assert.notEqual(tomorrow.periodId, snapshot.periodId);
    assert.deepEqual(new Set((tomorrow.offers as Offer[]).map(row => row.questId)), new Set(offers.map(row => row.questId)));
    assert.equal((tomorrow.offers as Offer[]).find(row => row.questId === first.questId)!.status, "IN_PROGRESS");
    const b = await child();
    const other = await b.send("POST", `/assignments/${assignmentId}/answer`, { stepNo: 1, selectedOptionCode: "VERIFIED" });
    assert.equal(other.statusCode, 404, other.body);

    // Exercise a complete reward through the real route; seed selection is irrelevant.
    const rewardChild = await child();
    await rewardChild.send("GET", "/quests/day");
    await pool.query("UPDATE quest_day_offers SET track_id = 'turnip', quest_id = 'Q_TURNIP_HARVEST' WHERE child_user_id = $1 AND slot = 1 AND NOT EXISTS (SELECT 1 FROM quest_day_offers WHERE child_user_id = $1 AND quest_id = 'Q_TURNIP_HARVEST')", [rewardChild.userId]);
    const startReward = await rewardChild.send("POST", "/quests/Q_TURNIP_HARVEST/start");
    assert.equal(startReward.statusCode, 201, startReward.body);
    const rewardAssignment = startReward.json().assignmentId as string;
    const payload = { stepNo: 1, selectedOptionCode: "grandmother,granddaughter,zhuchka,cat,mouse" };
    const paid = await rewardChild.send("POST", `/assignments/${rewardAssignment}/answer`, payload);
    assert.equal(paid.statusCode, 200, paid.body);
    assert.equal(paid.json().questCompleted, true);
    const replay = await rewardChild.send("POST", `/assignments/${rewardAssignment}/answer`, payload);
    assert.equal(replay.json().rewardAlreadyGranted, true);
    const ledger = await pool.query<{ count: string }>("SELECT COUNT(*) FROM transactions WHERE reference_id = $1 AND event_type = 'QUEST_REWARD'", [rewardAssignment]);
    assert.equal(Number(ledger.rows[0]!.count), 1);
    await pool.query("UPDATE pets SET energy_level = 0, last_energy_tick_at = statement_timestamp() WHERE child_user_id = $1", [rewardChild.userId]);
    assert.equal((await rewardChild.send("POST", "/quests/Q_TURNIP_HARVEST/start")).json().completed, true);
    const afterPaid = (await rewardChild.send("GET", "/quests/day")).json();
    assert.equal(afterPaid.offers.length, 3);
    assert.equal(afterPaid.offers.find((offer: Offer) => offer.questId === "Q_TURNIP_HARVEST").status, "COMPLETED");
    // Only a new game day replaces the completed slot; pending requests survive.
    await pool.query("UPDATE game_periods SET status = 'COMPLETED', closed_at = now() WHERE id = $1 AND child_user_id = $2", [afterPaid.periodId, rewardChild.userId]);
    await rewardChild.day();
    const nextRewardDay = (await rewardChild.send("GET", "/quests/day")).json();
    assert.notEqual(nextRewardDay.periodId, afterPaid.periodId);
    assert.equal(nextRewardDay.offers.length, 3);
    assert.ok(!nextRewardDay.offers.some((offer: Offer) => offer.questId === "Q_TURNIP_HARVEST"));
    const pending = (afterPaid.offers as Offer[]).filter(offer => offer.status !== "COMPLETED");
    for (const offer of pending) {
      assert.ok(nextRewardDay.offers.some((next: Offer) => next.questId === offer.questId));
    }
    assert.equal((nextRewardDay.offers as Offer[]).filter(offer => !pending.some(old => old.questId === offer.questId)).length, 1);
  } finally {
    await app.close();
    await pool.end();
  }
});
