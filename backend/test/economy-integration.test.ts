import assert from "node:assert/strict";
import test from "node:test";
import Fastify from "fastify";

// Opt in with a disposable, migrated and seeded DB. Never uses the app's .env.
test("goal lifecycle, protected savings, replay, frost and ledger reconciliation", {
  skip: !process.env["ECONOMY_TEST_DATABASE_URL"],
}, async () => {
  process.env["APP_DATABASE_URL"] = process.env["ECONOMY_TEST_DATABASE_URL"]!;
  const { pool, withTransaction } = await import("../src/lib/db.js");
  const { postTransaction } = await import("../src/lib/ledger.js");
  const { HttpError } = await import("../src/lib/errors.js");
  const { authRoutes } = await import("../src/auth/routes.js");
  const { goalRoutes } = await import("../src/modules/goals/routes.js");
  const { walletRoutes } = await import("../src/modules/wallet/routes.js");
  const { periodRoutes } = await import("../src/modules/periods/routes.js");
  const { shopRoutes } = await import("../src/modules/shop/routes.js");
  const { frostChestRoutes } = await import("../src/modules/frostChest/routes.js");
  const { economyRoutes } = await import("../src/modules/economy/routes.js");
  const { questRoutes } = await import("../src/modules/quests/routes.js");
  const { petRoutes } = await import("../src/modules/pet/routes.js");
  const { childSettingsRoutes } = await import("../src/modules/childSettings/routes.js");
  const originalRandom = Math.random;
  // This test exercises the base economy lifecycle. Event behavior has its
  // own integration test and must not make this one probabilistic.
  Math.random = () => 1;
  const app = Fastify({ ajv: { customOptions: { removeAdditional: false } } });
  app.setErrorHandler((error, _req, reply) => {
    if (error instanceof HttpError) reply.code(error.statusCode).send({ error: error.code });
    else reply.code((error as { statusCode?: number }).statusCode ?? 500).send({ error: String(error) });
  });
  for (const routes of [
    authRoutes,
    goalRoutes,
    walletRoutes,
    periodRoutes,
    shopRoutes,
    frostChestRoutes,
    economyRoutes,
    petRoutes,
    childSettingsRoutes,
    questRoutes,
  ]) {
    await app.register(routes);
  }
  try {
    const registration = await app.inject({
      method: "POST",
      url: "/auth/child/register",
      payload: { difficulty: "ADVANCED" },
    });
    assert.equal(registration.statusCode, 201);
    const { token, userId } = registration.json();
    const headers = { authorization: `Bearer ${token}` };
    const advancedQuests = await app.inject({
      method: "GET",
      url: "/quests",
      headers,
    });
    assert.equal(advancedQuests.statusCode, 200, advancedQuests.body);
    assert.ok(
      advancedQuests
        .json()
        .some((quest: { id?: string }) => quest.id === "Q_TURNIP_HARVEST"),
      "advanced guidance must keep the shared quest map available",
    );
    const initialSettings = await app.inject({ method: 'GET', url: '/child/settings', headers });
    assert.equal(initialSettings.statusCode, 200, initialSettings.body);
    assert.equal(initialSettings.json().difficulty, 'ADVANCED');
    assert.equal(initialSettings.json().largeTextEnabled, false);
    const savedSettings = await app.inject({
      method: 'PUT',
      url: '/child/settings',
      headers,
      payload: {
        difficulty: 'SIMPLE',
        soundEnabled: false,
        musicEnabled: true,
        largeTextEnabled: true,
      },
    });
    assert.equal(savedSettings.statusCode, 200, savedSettings.body);
    assert.deepEqual(
      {
        difficulty: savedSettings.json().difficulty,
        soundEnabled: savedSettings.json().soundEnabled,
        musicEnabled: savedSettings.json().musicEnabled,
        largeTextEnabled: savedSettings.json().largeTextEnabled,
      },
      {
        difficulty: 'SIMPLE',
        soundEnabled: false,
        musicEnabled: true,
        largeTextEnabled: true,
      },
    );
    const post = async (url: string, payload: object = {}, expected = 200) => {
      if ('idempotencyKey' in payload) payload = { ...payload, idempotencyKey: `integration-${payload.idempotencyKey}` };
      const response = await app.inject({ method: "POST", url, headers, payload });
      assert.equal(response.statusCode, expected, `${url}: ${response.body}`);
      return response.json();
    };
    const state = async () => {
      const response = await app.inject({ method: "GET", url: "/economy/state", headers });
      assert.equal(response.statusCode, 200, response.body);
      return response.json();
    };
    const plan = async (id: string, savings = 0) => {
      const response = await app.inject({ method: "PUT", url: `/periods/${id}/budget-plan`, headers,
        payload: { needAmount: 10, wantAmount: 20 - savings, savingsAmount: savings } });
      assert.equal(response.statusCode, 200, response.body);
      await post(`/periods/${id}/budget-plan/confirm`);
    };
    assert.equal((await state()).wallets.SPENDABLE, 0);
    assert.equal((await post('/periods', {}, 409)).error, 'financial_goal_required');
    assert.equal((await state()).wallets.SPENDABLE, 0);
    const selection = await Promise.all([
      app.inject({ method: 'POST', url: '/goals', headers, payload: { targetItemId: 'saucer' } }),
      app.inject({ method: 'POST', url: '/goals', headers, payload: { targetItemId: 'vial' } }),
    ]);
    assert.deepEqual(selection.map(r => r.statusCode).sort(), [201, 409]);
    const chosen = (await state()).activeGoal;
    await post(`/goals/${chosen.id}/cancel`, {}, 409);
    await post(`/goals/${chosen.id}/pause`, {}, 409);
    const day = await post('/periods', {}, 201);
    assert.equal(day.balanceAfter, 30);
    await plan(day.periodId, 15);
    await post('/savings/deposit', { amount: 10, idempotencyKey: 'reserve' }, 409);
    assert.equal((await state()).wallets.SAVINGS, 15);
    await post('/purchases', { itemId: 'PET_MEAL', idempotencyKey: 'food-first' }, 201);
    assert.equal((await state()).activeDay.remaining_reserve, 0);
    const deposit = { amount: 5, idempotencyKey: 'deposit-once' };
    await Promise.all([post('/savings/deposit', deposit), post('/savings/deposit', deposit)]);
    assert.equal((await state()).wallets.SAVINGS, 20);
    await post('/savings/withdraw', { amount: -5, idempotencyKey: 'negative' }, 400);
    // Only the published transfer steps are accepted.
    await post('/savings/deposit', { amount: 3, idempotencyKey: 'odd-step' }, 400);
    await post('/savings/withdraw', { amount: 100, idempotencyKey: 'not-a-step' }, 400);
    await post('/savings/withdraw', { amount: 10, idempotencyKey: 'more-than-saved-1' });
    await post('/savings/withdraw', { amount: 10, idempotencyKey: 'more-than-saved-2' });
    await post('/savings/withdraw', { amount: 5, idempotencyKey: 'more-than-saved' }, 409);
    await post('/savings/deposit', { amount: 10, idempotencyKey: 'refill-1' });
    await post('/savings/deposit', { amount: 10, idempotencyKey: 'refill-2' });
    // Fixture credit is also a real ledger entry, never a direct balance edit.
    await withTransaction(client => postTransaction(client, { childUserId: userId, walletKind: 'SPENDABLE', eventType: 'QUEST_REWARD', deltaAmount: 300, idempotencyKey: 'test-funding' }));
    // Two different transfers at once must both apply, not deadlock on the
    // child row that the idempotency key's foreign key also locks.
    await Promise.all([
      post('/savings/deposit', { amount: 10, idempotencyKey: 'parallel-a' }),
      post('/savings/deposit', { amount: 10, idempotencyKey: 'parallel-b' }),
    ]);
    assert.equal((await state()).wallets.SAVINGS, 40);
    for (let saved = 40, step = 0; saved < chosen.target_amount; saved += 10, step++) {
      await post('/savings/deposit', { amount: 10, idempotencyKey: `reach-${step}` });
    }
    assert.equal((await state()).activeGoal.status, 'ACHIEVED');
    await post('/savings/withdraw', { amount: 5, idempotencyKey: 'withdraw' });
    assert.equal((await state()).activeGoal.status, 'ACTIVE');
    await post(`/goals/${chosen.id}/redeem`, {}, 409);
    await post('/savings/deposit', { amount: 10, idempotencyKey: 'overflow' });
    await Promise.all([post(`/goals/${chosen.id}/redeem`), post(`/goals/${chosen.id}/redeem`)]);
    const redeemed = await state();
    assert.equal(redeemed.wallets.SAVINGS, 5);
    assert.equal(redeemed.inventory.length, 1);
    assert.equal(redeemed.activeGoal, null);
    assert.ok(!redeemed.artifacts.some((item: { id: string }) => item.id === chosen.target_item_id));
    await post('/savings/deposit', { amount: 5, idempotencyKey: 'without-goal' }, 409);
    await post('/goals', { targetItemId: chosen.target_item_id }, 409);
    await post('/goals', { targetItemId: 'boots' }, 201);
    assert.equal((await state()).wallets.SAVINGS, 5);
    const earlyBefore = (await state()).wallets;
    const early = await post('/frost-chests', { principalAmount: 20, idempotencyKey: 'early' }, 201);
    const other = (await app.inject({ method: 'POST', url: '/auth/child/register', payload: {} })).json();
    const forbidden = await app.inject({ method: 'POST', url: `/frost-chests/${early.id}/withdraw-early`,
      headers: { authorization: `Bearer ${other.token}` }, payload: {} });
    assert.equal(forbidden.statusCode, 404);
    await post(`/frost-chests/${early.id}/withdraw-early`);
    assert.deepEqual((await state()).wallets, earlyBefore);
    const chest = await post('/frost-chests', { principalAmount: 20, idempotencyKey: 'mature' }, 201);
    await post(`/frost-chests/${chest.id}/collect`, {}, 400);
    // Create a pet for actual day closure, then complete five real days.
    await pool.query(`INSERT INTO pets (child_user_id, pet_name, fur_option_id) VALUES ($1, 'Тест', 'FUR_GRAY')`, [userId]);
    let dayId = day.periodId;
    for (let i = 0; i < 5; i++) {
      if (i > 0) {
        dayId = (await post('/periods', {}, 201)).periodId;
        await plan(dayId);
        await post('/purchases', { itemId: 'PET_MEAL', idempotencyKey: `food-${i}` }, 201);
      }
      const closed = await post(`/periods/${dayId}/close`);
      if (i === 0) {
        assert.equal(closed.netSavings, chosen.target_amount + 5);
        assert.equal(closed.earnedAmount, 330);
        assert.deepEqual(closed.plan, { need: 10, want: 5, savings: 15 });
        assert.deepEqual(closed.actual, {
          need: 10,
          want: 0,
          savings: chosen.target_amount + 5,
        });
        // A lost response is safe: replaying close returns the persisted
        // result. Artifact effects fired on the first close only, so a replay
        // reports none instead of pretending they fired twice.
        const { artifactEffects: _fired, ...summary } = closed;
        const replay = await post(`/periods/${dayId}/close`);
        assert.deepEqual(replay.artifactEffects, []);
        const { artifactEffects: _none, ...replayed } = replay;
        assert.deepEqual(replayed, summary);
      }
    }
    const before = (await state()).wallets;
    await post(`/frost-chests/${chest.id}/collect`);
    const after = (await state()).wallets;
    assert.equal(after.SPENDABLE, before.SPENDABLE + 22);
    assert.equal(after.SAVINGS, before.SAVINGS);
    assert.equal(after.FROZEN, 0);
    const reflectiveDay = (await post('/periods', {}, 201)).periodId;
    await plan(reflectiveDay);
    const missedNeed = await post(`/periods/${reflectiveDay}/close`);
    assert.equal(missedNeed.needCovered, false);
    assert.equal(missedNeed.planFollowed, false);
    assert.equal(missedNeed.actual.need, 0);
    assert.match(missedNeed.feedback, /завтра попробуем ещё раз/);
    await post(`/frost-chests/${chest.id}/collect`, {}, 404);

    // Catalog effects and the gentle impulse consequence are applied by the
    // server in the same idempotent purchase transaction.
    await pool.query(
      `UPDATE pets SET energy_level = 50, joy_level = 50 WHERE child_user_id = $1`,
      [userId],
    );
    const careDay = (await post('/periods', {}, 201)).periodId;
    await plan(careDay);
    const food = await post('/purchases', {
      itemId: 'FOOD_APPLE',
      idempotencyKey: 'pet-effect-food',
    }, 201);
    assert.deepEqual(food.pet, { energy_level: 60, joy_level: 50 });
    const play = await post('/purchases', {
      itemId: 'TOY_BALL',
      idempotencyKey: 'pet-effect-play',
    }, 201);
    assert.equal(play.impulsive, true);
    assert.deepEqual(play.pet, { energy_level: 55, joy_level: 65 });

    const ledger = await pool.query(`SELECT w.kind, w.balance, COALESCE(SUM(t.delta_amount), 0)::int AS total FROM wallets w LEFT JOIN transactions t ON t.child_user_id = w.child_user_id AND t.wallet_kind = w.kind WHERE w.child_user_id = $1 GROUP BY w.kind, w.balance`, [userId]);
    for (const row of ledger.rows) assert.equal(row.balance, row.total);
    assert.equal((await app.inject({ method: 'POST', url: '/goals', payload: { targetItemId: 'shield' } })).statusCode, 401);
    const parent = (await app.inject({ method: 'POST', url: '/auth/parent/register', payload: {} })).json();
    assert.equal((await app.inject({ method: 'POST', url: '/goals', headers: { authorization: `Bearer ${parent.token}` }, payload: { targetItemId: 'shield' } })).statusCode, 403);
  } finally {
    Math.random = originalRandom;
    await app.close();
    await pool.end();
  }
});
