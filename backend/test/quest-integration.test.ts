import assert from "node:assert/strict";
import test from "node:test";

// Global-chain assertions are superseded by daily-quests.integration: characters
// are independent, while each character's own level prerequisites remain.
test("migrated quest prerequisites preserve character levels, not a global map chain", {
  skip: !process.env["ECONOMY_TEST_DATABASE_URL"],
}, async () => {
  process.env["APP_DATABASE_URL"] = process.env["ECONOMY_TEST_DATABASE_URL"]!;
  const { pool } = await import("../src/lib/db.js");
  try {
    const prerequisites = await pool.query<{ quest_id: string; prerequisite_quest_id: string }>(
      `SELECT quest_id, prerequisite_quest_id FROM quest_prerequisites ORDER BY quest_id`,
    );
    assert.deepEqual(prerequisites.rows, [
      { quest_id: "Q_GOLDFISH_HOME_ADVANCED_2", prerequisite_quest_id: "Q_GOLDFISH_HOME_ADVANCED_1" },
      { quest_id: "Q_GOLDFISH_HOME_SIMPLE_2", prerequisite_quest_id: "Q_GOLDFISH_HOME_SIMPLE_1" },
      { quest_id: "Q_IVAN_ROAD_EASY_2", prerequisite_quest_id: "Q_IVAN_ROAD_EASY_1" },
      { quest_id: "Q_IVAN_ROAD_HARD_2", prerequisite_quest_id: "Q_IVAN_ROAD_HARD_1" },
    ]);
    const migration = await pool.query("SELECT 1 FROM schema_migrations WHERE version = $1", ["0037_daily_quest_offers.sql"]);
    assert.equal(migration.rowCount, 1);
  } finally { await pool.end(); }
});
