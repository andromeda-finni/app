import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import test from "node:test";

// Only an explicitly supplied disposable, migrated and seeded test database.
test("PostgreSQL serializes concurrent starts and persists a single energy charge", {
  skip: !process.env["ECONOMY_TEST_DATABASE_URL"],
}, async () => {
  process.env["APP_DATABASE_URL"] = process.env["ECONOMY_TEST_DATABASE_URL"]!;
  const [{ pool }, { buildApp }] = await Promise.all([
    import("../src/lib/db.js"), import("../src/app.js"),
  ]);
  const app = await buildApp();
  try {
    const child = await app.inject({
      method: "POST", url: "/auth/child/register", payload: { difficulty: "ADVANCED" },
    });
    assert.ok(child.statusCode < 300, child.body);
    const headers = { authorization: `Bearer ${child.json().token}` };
    const created = await app.inject({
      method: "PUT", url: "/pet", headers,
      payload: { petName: "Финни", furOptionId: "FUR_GRAY" },
    });
    assert.equal(created.statusCode, 200, created.body);
    const before = await app.inject({ method: "GET", url: "/pet", headers });
    const sessionId = randomUUID();
    const starts = await Promise.all(Array.from({ length: 5 }, () => app.inject({
      method: "POST", url: "/minigames/catch-food/start", headers, payload: { sessionId },
    })));
    for (const response of starts) {
      assert.equal(response.statusCode, 200, response.body);
      assert.equal(response.json().session.id, sessionId);
      assert.equal(response.json().pet.energy_level, before.json().energy_level - 20);
    }
    const finished = await app.inject({
      method: "POST", url: `/minigames/catch-food/${sessionId}/finish`, headers,
      payload: { score: 0, misses: 0, elapsedMs: 0, reason: "STOPPED" },
    });
    assert.equal(finished.statusCode, 200, finished.body);
    assert.equal(finished.json().session.finished, true);
    const rows = await pool.query(
      `SELECT * FROM catch_food_sessions WHERE child_user_id = $1 AND id = $2`,
      [child.json().userId, sessionId],
    );
    assert.equal(rows.rowCount, 1);
    assert.equal(rows.rows[0].energy_cost, 20);
  } finally {
    await app.close();
    await pool.end();
  }
});
