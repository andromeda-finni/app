import assert from "node:assert/strict";
import test from "node:test";
import Fastify from "fastify";

// Opt in with a disposable, migrated and seeded DB. Never uses the app's .env.
test("stroking persists fractional joy and diminishes within a series", {
  skip: !process.env["ECONOMY_TEST_DATABASE_URL"],
}, async () => {
  process.env["APP_DATABASE_URL"] = process.env["ECONOMY_TEST_DATABASE_URL"]!;
  const { pool } = await import("../src/lib/db.js");
  const { authRoutes } = await import("../src/auth/routes.js");
  const { petRoutes } = await import("../src/modules/pet/routes.js");
  const app = Fastify({ ajv: { customOptions: { removeAdditional: false } } });
  await app.register(authRoutes);
  await app.register(petRoutes);
  try {
    const registration = await app.inject({
      method: "POST",
      url: "/auth/child/register",
      payload: { difficulty: "ADVANCED" },
    });
    const headers = { authorization: `Bearer ${registration.json().token}` };
    const stroke = async () => {
      const response = await app.inject({ method: "POST", url: "/pet/stroke", headers });
      return response;
    };

    assert.equal((await stroke()).statusCode, 404);
    const created = await app.inject({
      method: "POST",
      url: "/pet",
      headers,
      payload: { petName: "Мурзик", furOptionId: "FUR_GRAY" },
    });
    assert.ok(created.statusCode < 300, created.body);
    const userId = registration.json().userId as string;
    const startRes = await pool.query<{ joy_level: number }>(
      `SELECT joy_level FROM pets WHERE child_user_id = $1`,
      [userId],
    );
    const startJoy = startRes.rows[0]!.joy_level;

    const gains: number[] = [];
    let joy = startJoy;
    for (let i = 0; i < 3; i++) {
      const response = await stroke();
      assert.equal(response.statusCode, 200, response.body);
      gains.push(Math.round(response.json().joy_gain * 1000) / 1000);
      joy = response.json().joy_level;
    }
    assert.deepEqual(gains, [0.5, 0.45, 0.405]);
    assert.equal(joy, Math.min(100, Math.floor(startJoy + 1.355)));

    const parallel = await Promise.all(Array.from({ length: 10 }, stroke));
    for (const response of parallel) assert.equal(response.statusCode, 200, response.body);
    const row = await pool.query(
      `SELECT stroke_streak FROM pets WHERE child_user_id = $1`,
      [userId],
    );
    assert.equal(row.rows[0].stroke_streak, 13);
  } finally {
    await app.close();
    await pool.end();
  }
});
