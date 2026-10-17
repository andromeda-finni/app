import assert from "node:assert/strict";
import test from "node:test";
import Fastify from "fastify";

// Opt in with a disposable, migrated and seeded DB. Never uses the app's .env.
test("onboarding tutorial budget becomes the first day, later days use the regular income", {
  skip: !process.env["ECONOMY_TEST_DATABASE_URL"],
}, async () => {
  process.env["APP_DATABASE_URL"] = process.env["ECONOMY_TEST_DATABASE_URL"]!;
  const { pool } = await import("../src/lib/db.js");
  const { HttpError } = await import("../src/lib/errors.js");
  const { authRoutes } = await import("../src/auth/routes.js");
  const { onboardingRoutes } = await import("../src/modules/onboarding/routes.js");
  const { petRoutes } = await import("../src/modules/pet/routes.js");
  const { goalRoutes } = await import("../src/modules/goals/routes.js");
  const { periodRoutes } = await import("../src/modules/periods/routes.js");
  const { economyRoutes } = await import("../src/modules/economy/routes.js");
  const originalRandom = Math.random;
  // Keep the second day free of random pet events.
  Math.random = () => 1;
  const app = Fastify({ ajv: { customOptions: { removeAdditional: false } } });
  app.setErrorHandler((error, _req, reply) => {
    if (error instanceof HttpError) reply.code(error.statusCode).send({ error: error.code });
    else reply.code((error as { statusCode?: number }).statusCode ?? 500).send({ error: String(error) });
  });
  for (const routes of [authRoutes, onboardingRoutes, petRoutes, goalRoutes, periodRoutes, economyRoutes]) {
    await app.register(routes);
  }
  try {
    const registration = await app.inject({
      method: "POST",
      url: "/auth/child/register",
      payload: { difficulty: "ADVANCED" },
    });
    assert.equal(registration.statusCode, 201, registration.body);
    const { token, userId } = registration.json();
    const headers = { authorization: `Bearer ${token}` };
    const send = async (method: "POST" | "PUT", url: string, payload: object = {}, expected = 200) => {
      const response = await app.inject({ method, url, headers, payload });
      assert.equal(response.statusCode, expected, `${url}: ${response.body}`);
      return response.json();
    };
    const state = async () => {
      const response = await app.inject({ method: "GET", url: "/economy/state", headers });
      assert.equal(response.statusCode, 200, response.body);
      return response.json();
    };

    await send("PUT", "/pet", { petName: "Мурзик", furOptionId: "FUR_GRAY" });
    await send("PUT", "/onboarding/progress", { completedStep: 2 });
    const tutorialPlan = { needAmount: 4, wantAmount: 3, savingsAmount: 3 };
    await send("PUT", "/onboarding/progress", { completedStep: 3, tutorialPlan });
    assert.equal((await state()).activeDay, null);

    // Completing onboarding, and replaying that completion, opens one day.
    for (let attempt = 0; attempt < 2; attempt++) {
      await send("PUT", "/onboarding/progress", { completedStep: 4 });
    }
    const first = await state();
    assert.equal(first.wallets.SPENDABLE, 7);
    assert.equal(first.wallets.SAVINGS, 3);
    assert.equal(first.activeDay.sequence_no, 1);
    assert.equal(first.activeDay.required_need_amount, 4);
    assert.equal(first.activeDay.budget_plan_status, "CONFIRMED");
    assert.equal(first.activeDay.available_amount, 10);
    assert.deepEqual(
      [first.activeDay.need_amount, first.activeDay.want_amount, first.activeDay.savings_amount],
      [4, 3, 3],
    );
    const days = await pool.query(`SELECT 1 FROM game_periods WHERE child_user_id = $1`, [userId]);
    assert.equal(days.rowCount, 1);

    await send("POST", `/periods/${first.activeDay.id}/close`);
    await send("POST", "/goals", { targetItemId: "boots" }, 201);
    const second = await send("POST", "/periods", {}, 201);
    assert.equal(second.grantAmount, 30);
    const secondState = await state();
    assert.equal(secondState.activeDay.sequence_no, 2);
    assert.equal(secondState.activeDay.available_amount, 30);
    assert.equal(secondState.activeDay.budget_plan_status, "DRAFT");
    assert.equal(secondState.wallets.SPENDABLE, 37);

    const ledger = await pool.query(`SELECT w.balance, COALESCE(SUM(t.delta_amount), 0)::int AS total FROM wallets w LEFT JOIN transactions t ON t.child_user_id = w.child_user_id AND t.wallet_kind = w.kind WHERE w.child_user_id = $1 GROUP BY w.kind, w.balance`, [userId]);
    for (const row of ledger.rows) assert.equal(row.balance, row.total);
  } finally {
    Math.random = originalRandom;
    await app.close();
    await pool.end();
  }
});
