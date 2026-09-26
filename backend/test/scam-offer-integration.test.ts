import assert from "node:assert/strict";
import test from "node:test";

import Fastify from "fastify";

// Opt in with the same disposable, migrated and seeded DB as the other
// integration tests. The application database configured in .env is ignored.
test("concurrent scam rolls create at most one active offer", {
  skip: !process.env["ECONOMY_TEST_DATABASE_URL"],
}, async () => {
  process.env["APP_DATABASE_URL"] = process.env["ECONOMY_TEST_DATABASE_URL"]!;
  const { pool } = await import("../src/lib/db.js");
  const { authRoutes } = await import("../src/auth/routes.js");
  const { scamOfferRoutes } = await import("../src/modules/scamOffers/routes.js");

  const app = Fastify({ ajv: { customOptions: { removeAdditional: false } } });
  await app.register(authRoutes);
  await app.register(scamOfferRoutes);
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

    const rolls = await Promise.all(Array.from({ length: 8 }, () =>
      app.inject({ method: "POST", url: "/scam-offers/roll", headers }),
    ));
    assert.ok(rolls.every((response) => response.statusCode === 200));
    assert.equal(
      rolls.filter((response) => response.json().triggered === true).length,
      1,
    );

    const active = await pool.query<{ count: number }>(
      `SELECT COUNT(*)::int AS count FROM scam_offer_occurrences
        WHERE child_user_id = $1 AND status = 'ACTIVE'`,
      [userId],
    );
    assert.equal(active.rows[0]!.count, 1);
  } finally {
    Math.random = originalRandom;
    await app.close();
    await pool.end();
  }
});
