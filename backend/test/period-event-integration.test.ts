import assert from "node:assert/strict";
import test from "node:test";
import Fastify from "fastify";

test("starting a period rolls one event atomically and protects its reserve", {
  skip: !process.env["ECONOMY_TEST_DATABASE_URL"],
}, async () => {
  process.env["APP_DATABASE_URL"] = process.env["ECONOMY_TEST_DATABASE_URL"]!;
  const { pool } = await import("../src/lib/db.js");
  const { HttpError } = await import("../src/lib/errors.js");
  const { authRoutes } = await import("../src/auth/routes.js");
  const { petRoutes } = await import("../src/modules/pet/routes.js");
  const { goalRoutes } = await import("../src/modules/goals/routes.js");
  const { periodRoutes } = await import("../src/modules/periods/routes.js");
  const { shopRoutes } = await import("../src/modules/shop/routes.js");
  const { petEventRoutes } = await import("../src/modules/petEvents/routes.js");
  const { economyRoutes } = await import("../src/modules/economy/routes.js");

  const app = Fastify({ ajv: { customOptions: { removeAdditional: false } } });
  app.setErrorHandler((error, _req, reply) => {
    if (error instanceof HttpError) {
      reply.code(error.statusCode).send({ error: error.code, details: error.details });
    } else {
      reply.code((error as { statusCode?: number }).statusCode ?? 500).send({ error: String(error) });
    }
  });
  for (const routes of [
    authRoutes,
    petRoutes,
    goalRoutes,
    periodRoutes,
    shopRoutes,
    petEventRoutes,
    economyRoutes,
  ]) {
    await app.register(routes);
  }

  const originalRandom = Math.random;
  Math.random = () => 0;
  try {
    const registration = await app.inject({
      method: "POST",
      url: "/auth/child/register",
      payload: {},
    });
    assert.equal(registration.statusCode, 201, registration.body);
    const { token, userId } = registration.json();
    const headers = { authorization: `Bearer ${token}` };
    const request = (method: "GET" | "POST" | "PUT", url: string, payload: object = {}) =>
      app.inject({ method, url, headers, payload });

    assert.equal((await request("PUT", "/pet", {
      petName: "Барсик",
      furOptionId: "FUR_GRAY",
    })).statusCode, 200);
    assert.equal((await request("POST", "/goals", {
      targetItemId: "saucer",
    })).statusCode, 201);

    const startAndPlan = async (needAmount: number) => {
      const started = await request("POST", "/periods");
      assert.equal(started.statusCode, 201, started.body);
      const periodId = started.json().periodId as string;
      const draft = await request("PUT", `/periods/${periodId}/budget-plan`, {
        needAmount,
        wantAmount: 30 - needAmount,
        savingsAmount: 0,
      });
      assert.equal(draft.statusCode, 200, draft.body);
      const confirmed = await request("POST", `/periods/${periodId}/budget-plan/confirm`);
      assert.equal(confirmed.statusCode, 200, confirmed.body);
      return { periodId, started: started.json() };
    };
    const buy = (key: string) => request("POST", "/purchases", {
      itemId: "PET_MEAL",
      idempotencyKey: key,
    });

    const first = await startAndPlan(10);
    assert.equal(first.started.eventTriggered, false);
    for (let index = 0; index < 3; index++) {
      assert.equal((await buy(`first-day-${index}`)).statusCode, 201);
    }
    assert.equal((await request("POST", `/periods/${first.periodId}/close`)).statusCode, 200);

    const secondStart = await request("POST", "/periods");
    assert.equal(secondStart.statusCode, 201, secondStart.body);
    assert.equal(secondStart.json().eventTriggered, true);
    const secondId = secondStart.json().periodId as string;

    let state = (await request("GET", "/economy/state")).json();
    const event = state.activeEvent as { id: string; amount_due: number };
    assert.ok(event?.id);
    assert.equal(state.pet.health_level, 55);
    assert.equal(state.activeDay.required_need_amount, 10 + event.amount_due);

    // Replays and old clients cannot obtain another random chance that day.
    const replay = await request("POST", "/pet-events/roll");
    assert.equal(replay.statusCode, 200, replay.body);
    assert.deepEqual(replay.json(), { triggered: false });
    const count = await pool.query<{ count: string }>(
      `SELECT COUNT(*) FROM pet_event_occurrences WHERE child_user_id = $1 AND period_id = $2`,
      [userId, secondId],
    );
    assert.equal(Number(count.rows[0]!.count), 1);

    const draft = await request("PUT", `/periods/${secondId}/budget-plan`, {
      needAmount: 10 + event.amount_due,
      wantAmount: 20 - event.amount_due,
      savingsAmount: 0,
    });
    assert.equal(draft.statusCode, 200, draft.body);
    assert.equal((await request("POST", `/periods/${secondId}/budget-plan/confirm`)).statusCode, 200);

    let blocked = false;
    for (let index = 0; index < 4; index++) {
      const purchase = await buy(`second-day-${index}`);
      if (purchase.statusCode === 409) {
        assert.equal(
          purchase.json().error,
          "active_event_reserve_is_unavailable_for_purchases",
        );
        blocked = true;
        break;
      }
      assert.equal(purchase.statusCode, 201, purchase.body);
    }
    assert.equal(blocked, true, "a NEED purchase must eventually stop at the event reserve");

    assert.equal((await request("POST", `/pet-events/${event.id}/resolve`)).statusCode, 200);
    state = (await request("GET", "/economy/state")).json();
    assert.equal(state.activeEvent, null);
    assert.equal(state.pet.health_level, 100);
    assert.equal(state.activeDay.remaining_reserve, 0);
    assert.equal((await request("POST", `/periods/${secondId}/close`)).statusCode, 200);
  } finally {
    Math.random = originalRandom;
    await app.close();
    await pool.end();
  }
});
