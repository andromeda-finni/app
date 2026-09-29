import assert from "node:assert/strict";
import test from "node:test";
import Fastify from "fastify";

test("park contribution is optional, idempotent and advances over completed days", {
  skip: !process.env["ECONOMY_TEST_DATABASE_URL"],
}, async () => {
  process.env["APP_DATABASE_URL"] = process.env["ECONOMY_TEST_DATABASE_URL"]!;
  const { pool, withTransaction } = await import("../src/lib/db.js");
  const { HttpError } = await import("../src/lib/errors.js");
  const { postTransaction } = await import("../src/lib/ledger.js");
  const { authRoutes } = await import("../src/auth/routes.js");
  const { parkProjectRoutes } = await import("../src/modules/parkProject/routes.js");

  const app = Fastify({ ajv: { customOptions: { removeAdditional: false } } });
  app.setErrorHandler((error, _req, reply) => {
    if (error instanceof HttpError) {
      reply.code(error.statusCode).send({ error: error.code, details: error.details });
    } else {
      reply.code((error as { statusCode?: number }).statusCode ?? 500).send({ error: String(error) });
    }
  });
  await app.register(authRoutes);
  await app.register(parkProjectRoutes);

  try {
    const registration = await app.inject({
      method: "POST",
      url: "/auth/child/register",
      payload: {},
    });
    assert.equal(registration.statusCode, 201, registration.body);
    const { token, userId } = registration.json();
    const headers = { authorization: `Bearer ${token}` };

    const locked = await app.inject({ method: "GET", url: "/park-project", headers });
    assert.equal(locked.statusCode, 409, locked.body);
    assert.equal(locked.json().error, "park_quest_locked");

    await pool.query(
      `INSERT INTO assignments
         (child_user_id, origin, quest_id, reward_amount, status)
       VALUES ($1, 'SYSTEM', 'Q_TUGRIKI_CURRENCY', 15, 'COMPLETED')`,
      [userId],
    );
    await withTransaction((client) => postTransaction(client, {
      childUserId: userId as string,
      walletKind: "SPENDABLE",
      eventType: "QUEST_REWARD",
      deltaAmount: 100,
      idempotencyKey: `park-test-funding:${userId}`,
    }));

    const initial = await app.inject({ method: "GET", url: "/park-project", headers });
    assert.equal(initial.statusCode, 200, initial.body);
    assert.equal(initial.json().stage, "FIRST_OFFER");
    assert.equal(initial.json().collectedAmount, 80);

    const contribution = {
      offer: "FIRST",
      decision: "CONTRIBUTE",
      idempotencyKey: `park-decision-${userId}`,
    };
    const responses = await Promise.all([
      app.inject({ method: "POST", url: "/park-project/decision", headers, payload: contribution }),
      app.inject({ method: "POST", url: "/park-project/decision", headers, payload: contribution }),
    ]);
    assert.ok(responses.every((response) => response.statusCode === 200));
    assert.ok(responses.some((response) => response.json().replayed === true));
    assert.ok(responses.some((response) => response.json().replayed === false));

    const debit = await pool.query<{ count: number; total: number }>(
      `SELECT COUNT(*)::int AS count, COALESCE(SUM(delta_amount), 0)::int AS total
         FROM transactions
        WHERE child_user_id = $1 AND event_type = 'PARK_CONTRIBUTION'`,
      [userId],
    );
    assert.deepEqual(debit.rows[0], { count: 1, total: -20 });

    for (let sequence = 1; sequence <= 3; sequence++) {
      await pool.query(
        `INSERT INTO game_periods
           (child_user_id, sequence_no, status, required_need_amount,
            opening_spendable, opening_savings, opening_frozen, opened_at, closed_at)
         VALUES ($1, $2, 'COMPLETED', 0, 0, 0, 0, now() - interval '2 hours', now())`,
        [userId, sequence],
      );
    }
    const opened = await app.inject({ method: "GET", url: "/park-project", headers });
    assert.equal(opened.statusCode, 200, opened.body);
    assert.equal(opened.json().scene, "OPEN");

    const complete = await app.inject({
      method: "POST",
      url: "/park-project/complete",
      headers,
      payload: { idempotencyKey: `park-complete-${userId}` },
    });
    assert.equal(complete.statusCode, 200, complete.body);
    assert.equal(complete.json().completed, true);

    const protectedRegistration = await app.inject({
      method: "POST",
      url: "/auth/child/register",
      payload: {},
    });
    const protectedChild = protectedRegistration.json();
    const protectedHeaders = { authorization: `Bearer ${protectedChild.token}` };
    await pool.query(
      `INSERT INTO assignments
         (child_user_id, origin, quest_id, reward_amount, status)
       VALUES ($1, 'SYSTEM', 'Q_TUGRIKI_CURRENCY', 15, 'COMPLETED')`,
      [protectedChild.userId],
    );
    await withTransaction((client) => postTransaction(client, {
      childUserId: protectedChild.userId as string,
      walletKind: "SPENDABLE",
      eventType: "QUEST_REWARD",
      deltaAmount: 20,
      idempotencyKey: `park-reserve-funding:${protectedChild.userId}`,
    }));
    await pool.query(
      `INSERT INTO game_periods
         (child_user_id, sequence_no, required_need_amount,
          opening_spendable, opening_savings, opening_frozen)
       VALUES ($1, 1, 10, 20, 0, 0)`,
      [protectedChild.userId],
    );
    const protectedState = await app.inject({
      method: "GET",
      url: "/park-project",
      headers: protectedHeaders,
    });
    assert.equal(protectedState.statusCode, 200, protectedState.body);
    assert.equal(protectedState.json().availableToContribute, 10);
    assert.equal(protectedState.json().canContribute, false);
    const protectedAttempt = await app.inject({
      method: "POST",
      url: "/park-project/decision",
      headers: protectedHeaders,
      payload: {
        offer: "FIRST",
        decision: "CONTRIBUTE",
        idempotencyKey: `park-protected-${protectedChild.userId}`,
      },
    });
    assert.equal(protectedAttempt.statusCode, 409, protectedAttempt.body);
    assert.equal(
      protectedAttempt.json().error,
      "park_contribution_would_use_need_reserve",
    );

    const parent = await app.inject({
      method: "POST",
      url: "/auth/parent/register",
      payload: {},
    });
    const forbidden = await app.inject({
      method: "GET",
      url: "/park-project",
      headers: { authorization: `Bearer ${parent.json().token}` },
    });
    assert.equal(forbidden.statusCode, 403, forbidden.body);

    const malformed = await app.inject({
      method: "POST",
      url: "/park-project/decision",
      headers,
      payload: { ...contribution, amount: 999 },
    });
    assert.equal(malformed.statusCode, 400, malformed.body);
  } finally {
    await app.close();
    await pool.end();
  }
});
