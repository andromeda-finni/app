import assert from "node:assert/strict";
import test from "node:test";
import Fastify from "fastify";
import { CATCH_FOOD_RULES, validateCatchFoodResult } from "../src/modules/catchFood/rules.js";

const id = "11111111-1111-4111-8111-111111111111";
const result = { score: 2, misses: 3, elapsedMs: 7000, reason: "MISSES" as const };

test("result validation rejects fabricated scores, elapsed time and finish reasons", () => {
  assert.doesNotThrow(() => validateCatchFoodResult(result, 8000));
  for (const value of [
    { ...result, score: 90 }, { ...result, score: -1 },
    { ...result, elapsedMs: 61000 }, { ...result, misses: 2 },
    { ...result, score: 1, elapsedMs: 1000 },
    { ...result, reason: "TIRED" as const },
  ]) assert.throws(() => validateCatchFoodResult(value, 8000));
  assert.throws(() => validateCatchFoodResult(result, 1000));
});

test("faster first arrival accepts either a fresh point or a spoiled-food mistake", () => {
  assert.equal(CATCH_FOOD_RULES.travelMs, 2400);
  const arrival = CATCH_FOOD_RULES.firstSpawnMs + CATCH_FOOD_RULES.travelMs;
  for (const value of [
    { score: 1, misses: 0, elapsedMs: arrival, reason: "STOPPED" as const },
    { score: 0, misses: 1, elapsedMs: arrival, reason: "STOPPED" as const },
  ]) {
    assert.doesNotThrow(() => validateCatchFoodResult(value, arrival));
    assert.throws(() => validateCatchFoodResult({ ...value, elapsedMs: arrival - 1 }, arrival));
  }
});

async function withServer(
  run: (state: any, request: (method: "GET" | "POST", url: string, body?: object) => Promise<any>) => Promise<void>,
) {
  process.env["APP_DATABASE_URL"] = "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { catchFoodRoutes }, { HttpError }] = await Promise.all([
    import("../src/lib/db.js"), import("../src/modules/catchFood/routes.js"),
    import("../src/lib/errors.js"),
  ]);
  const originalQuery = pool.query;
  const originalConnect = pool.connect;
  const state = {
    energy: 100, charges: 0, user: "child-1", role: "CHILD", pet: true,
    failInsert: false, now: new Date("2026-10-17T12:00:00Z"), sessions: new Map<string, any>(),
  };
  let snapshot: typeof state | null = null;
  const row = () => ({
    id: "pet-1", child_user_id: state.user, pet_name: "Финни", fur_option_id: "FUR_GRAY",
    energy_level: state.energy, joy_level: 50, health_level: 100,
    last_energy_tick_at: state.now, mode: "STANDARD", server_now: state.now,
  });
  const query = async (sql: string, params: unknown[] = []) => {
    if (sql.includes("FROM auth_credentials")) return { rows: [{ user_id: state.user, role: state.role }], rowCount: 1 };
    if (sql.startsWith("UPDATE auth_credentials")) return { rows: [], rowCount: 1 };
    if (sql === "BEGIN") { snapshot = { ...state, sessions: structuredClone(state.sessions) }; return { rows: [] }; }
    if (sql === "ROLLBACK") { Object.assign(state, snapshot); return { rows: [] }; }
    if (sql === "COMMIT") { snapshot = null; return { rows: [] }; }
    if (sql.includes("SELECT user_id FROM child_profiles")) {
      assert.match(sql, /FOR UPDATE/); return { rows: [{ user_id: state.user }], rowCount: 1 };
    }
    if (sql.includes("WITH locked_pet AS")) return { rows: state.pet ? [row()] : [], rowCount: state.pet ? 1 : 0 };
    if (sql.includes("WITH spent AS")) {
      if (state.energy < Number(params[1])) return { rows: [], rowCount: 0 };
      state.energy -= Number(params[1]); state.charges++;
      return { rows: [row()], rowCount: 1 };
    }
    if (sql.includes("MAX(score)")) {
      const scores = [...state.sessions.values()].filter((value) => value.child === params[0] && value.finished_at).map((value) => value.score);
      return { rows: [{ best: Math.max(0, ...scores) }], rowCount: 1 };
    }
    const key = `${params[0]}:${params[1]}`;
    if (sql.includes("INSERT INTO catch_food_sessions")) {
      if (state.failInsert) throw new Error("simulated storage failure");
      state.sessions.set(key, { child: params[0], id: params[1], energy_cost: params[2],
        score: 0, misses: 0, elapsed_ms: 0, finish_reason: null,
        created_at: state.now, finished_at: null, server_now: state.now });
    } else if (sql.includes("UPDATE catch_food_sessions")) {
      Object.assign(state.sessions.get(key), { score: params[2], misses: params[3], elapsed_ms: params[4],
        finish_reason: params[5], finished_at: state.now, server_now: state.now });
    } else if (!sql.includes("FROM catch_food_sessions")) {
      throw new Error(`Unexpected query: ${sql}`);
    }
    const session = state.sessions.get(key);
    return { rows: session ? [{ ...session, server_now: state.now }] : [], rowCount: session ? 1 : 0 };
  };
  pool.query = query as typeof pool.query;
  pool.connect = (async () => ({ query, release() {} })) as unknown as typeof pool.connect;
  const app = Fastify({ ajv: { customOptions: { removeAdditional: false } } });
  app.setErrorHandler((error, req, reply) => {
    if (error instanceof HttpError) return reply.code(error.statusCode).send({ error: error.code });
    reply.code((error as { statusCode?: number }).statusCode ?? 500).send({ error: "request_failed" });
  });
  await app.register(catchFoodRoutes);
  try {
    await run(state, (method, url, body) => app.inject({
      method, url, headers: { authorization: "Bearer test" }, ...(body ? { payload: body } : {}),
    }));
  } finally {
    pool.query = originalQuery; pool.connect = originalConnect;
    await app.close();
  }
}

test("information is free and an idempotent start charges exactly once without a quest/day", async () => {
  await withServer(async (state, request) => {
    const info = await request("GET", "/minigames/catch-food");
    assert.equal(info.statusCode, 200);
    assert.equal(info.json().config.travelMs, 2400);
    assert.equal(info.json().config.spoiledFoodPercent, 20);
    assert.equal(state.charges, 0);
    const first = await request("POST", "/minigames/catch-food/start", { sessionId: id });
    const retry = await request("POST", "/minigames/catch-food/start", { sessionId: id });
    assert.equal(first.statusCode, 200, first.body);
    assert.deepEqual(first.json(), retry.json());
    assert.equal(state.energy, 80);
    assert.equal(state.charges, 1);
    assert.equal(state.sessions.size, 1);
  });
});

test("low satiety and missing pets cannot create an attempt", async () => {
  await withServer(async (state, request) => {
    state.energy = 19;
    assert.equal((await request("POST", "/minigames/catch-food/start", { sessionId: id })).statusCode, 409);
    state.pet = false;
    assert.equal((await request("POST", "/minigames/catch-food/start", { sessionId: id })).statusCode, 404);
    assert.equal(state.sessions.size, 0);
    assert.equal(state.charges, 0);
  });
});

test("storage failure rolls back the charge, then the same attempt may be retried", async () => {
  await withServer(async (state, request) => {
    state.failInsert = true;
    assert.equal((await request("POST", "/minigames/catch-food/start", { sessionId: id })).statusCode, 500);
    assert.equal(state.energy, 100);
    assert.equal(state.charges, 0);
    state.failInsert = false;
    assert.equal((await request("POST", "/minigames/catch-food/start", { sessionId: id })).statusCode, 200);
    assert.equal(state.charges, 1);
  });
});

test("finishing saves a personal best once, with no additional satiety charge", async () => {
  await withServer(async (state, request) => {
    await request("POST", "/minigames/catch-food/start", { sessionId: id });
    state.now = new Date(state.now.getTime() + 8000);
    const finished = await request("POST", `/minigames/catch-food/${id}/finish`, result);
    const duplicate = await request("POST", `/minigames/catch-food/${id}/finish`, { ...result, score: 0 });
    assert.equal(finished.statusCode, 200, finished.body);
    assert.deepEqual(finished.json(), duplicate.json());
    assert.equal(finished.json().bestScore, 2);
    assert.equal(state.energy, 80);
    assert.equal(state.charges, 1);
    const restart = await request("POST", "/minigames/catch-food/start", { sessionId: id });
    assert.equal(restart.json().session.finished, true);
    assert.equal(state.charges, 1);
  });
});

test("another child cannot read or finish a stored attempt", async () => {
  await withServer(async (state, request) => {
    await request("POST", "/minigames/catch-food/start", { sessionId: id });
    state.user = "child-2";
    assert.equal((await request("POST", `/minigames/catch-food/${id}/finish`, result)).statusCode, 404);
    assert.equal((await request("GET", "/minigames/catch-food")).json().bestScore, 0);
  });
});

test("request schemas reject unknown fields and parent access", async () => {
  await withServer(async (state, request) => {
    assert.equal((await request("POST", "/minigames/catch-food/start", { sessionId: "invalid" })).statusCode, 400);
    assert.equal((await request("POST", "/minigames/catch-food/start", { sessionId: id, energyCost: 0 })).statusCode, 400);
    assert.equal(state.charges, 0);
    state.role = "PARENT";
    assert.equal((await request("GET", "/minigames/catch-food")).statusCode, 403);
  });
});
