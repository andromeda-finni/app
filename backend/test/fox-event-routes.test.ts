import assert from "node:assert/strict";
import test from "node:test";
import Fastify from "fastify";
import { HttpError } from "../src/lib/errors.js";
import type { FoxState } from "../src/modules/foxEvents/rules.js";

test("Fox routes persist rolls and validate atomic, replay-safe wallet effects", async () => {
  process.env["APP_DATABASE_URL"] = "postgres://test:test@localhost:5432/test?sslmode=disable";
  const { pool } = await import("../src/lib/db.js");
  const { foxEventRoutes } = await import("../src/modules/foxEvents/routes.js");
  const originalQuery = pool.query;
  const originalConnect = pool.connect;
  const originalRandom = Math.random;
  let state: FoxState = { lastRollDay: 0, completedScriptIds: [], session: null };
  let spendable = 35;
  let day = 1;
  let confirmed = true;
  let difficulty = "SIMPLE";
  let ledger: unknown[][] = [];
  let txState = structuredClone(state);
  let txBalance = spendable;
  let txLedger = ledger;
  let failSave = false;
  pool.query = (async (sql: string) => {
    if (sql.includes("FROM auth_credentials")) return { rows: [{ user_id: "child-1", role: "CHILD" }], rowCount: 1 };
    if (sql.startsWith("UPDATE auth_credentials")) return { rows: [], rowCount: 1 };
    throw new Error(`Unexpected auth query: ${sql}`);
  }) as typeof pool.query;
  pool.connect = (async () => ({
    release() {},
    async query(sql: string, params: unknown[] = []) {
      if (sql === "BEGIN") { txState = structuredClone(state); txBalance = spendable; txLedger = [...ledger]; }
      else if (sql === "COMMIT") { state = txState; spendable = txBalance; ledger = txLedger; }
      else if (sql === "ROLLBACK") { /* Transaction-local effects are discarded. */ }
      else if (sql.includes("SELECT difficulty FROM child_profiles")) {
        assert.match(sql, /FOR UPDATE/);
        return { rows: [{ difficulty }], rowCount: 1 };
      } else if (sql.includes("SELECT gp.sequence_no")) {
        assert.match(sql, /bp.status = 'CONFIRMED'/);
        return { rows: confirmed ? [{ sequence_no: day }] : [], rowCount: confirmed ? 1 : 0 };
      } else if (sql.includes("INSERT INTO fox_event_states")) { /* Already initialized. */ }
      else if (sql.includes("SELECT state FROM fox_event_states")) {
        assert.match(sql, /FOR UPDATE/);
        return { rows: [{ state: structuredClone(txState) }], rowCount: 1 };
      } else if (sql.includes("UPDATE fox_event_states")) {
        if (failSave) throw new Error("storage unavailable");
        txState = JSON.parse(params[1] as string);
      } else if (sql.includes("SELECT balance FROM wallets")) {
        assert.match(sql, /FOR UPDATE/);
        return { rows: [{ balance: txBalance }], rowCount: 1 };
      } else if (sql.includes("AS reserve")) return { rows: [{ reserve: 10 }], rowCount: 1 };
      else if (sql.includes("INSERT INTO transactions")) {
        txLedger.push(params);
        return { rows: [{ id: "txn-1" }], rowCount: 1 };
      } else if (sql.includes("UPDATE wallets")) txBalance = params[0] as number;
      else throw new Error(`Unexpected transaction query: ${sql}`);
      return { rows: [], rowCount: 1 };
    },
  })) as unknown as typeof pool.connect;
  Math.random = () => 0;
  const app = Fastify({ ajv: { customOptions: { removeAdditional: false } } });
  app.setErrorHandler((error, _req, reply) => {
    if (error instanceof HttpError) return reply.code(error.statusCode).send({ error: error.code });
    return reply.code(error.statusCode ?? 500).send({ error: "request_failed" });
  });
  await app.register(foxEventRoutes);
  const headers = { authorization: "Bearer test-token" };
  const visit = () => app.inject({ method: "POST", url: "/fox-events/visit", headers });
  const advance = (nodeId: string, choiceId?: string, extra = {}) => app.inject({
    method: "POST", url: "/fox-events/advance", headers,
    payload: { sessionId: state.session?.id, nodeId, ...(choiceId ? { choiceId } : {}), ...extra },
  });
  try {
    assert.equal((await app.inject({ method: "POST", url: "/fox-events/visit" })).statusCode, 401);
    confirmed = false;
    assert.equal((await visit()).json().session, null);
    assert.equal(state.lastRollDay, 0);
    confirmed = true;
    const first = await visit();
    assert.equal(first.statusCode, 200, first.body);
    const id = first.json().session.id;
    assert.equal((await visit()).json().session.id, id);
    assert.equal((await advance("start", "give_now", { delta: 1000 })).statusCode, 400);
    assert.equal((await advance("start", "fake_reward")).statusCode, 400);
    assert.equal((await advance("returned_without_questions")).statusCode, 409);
    failSave = true;
    assert.equal((await advance("start", "give_now")).statusCode, 500);
    assert.equal(spendable, 35);
    assert.equal(ledger.length, 0);
    assert.equal(state.session!.currentNodeId, "start");
    failSave = false;
    assert.equal((await advance("start", "give_now")).statusCode, 200);
    assert.equal(spendable, 25);
    assert.equal((await advance("start", "give_now")).statusCode, 200);
    assert.equal(ledger.length, 1);
    assert.equal((await advance("gave_without_questions", "wait")).json().session.status, "waitingForNextDay");
    assert.equal((await visit()).json().session, null);
    assert.equal((await advance("returned_without_questions")).statusCode, 409);
    day++;
    const returned = (await visit()).json();
    assert.equal(returned.session.id, id);
    assert.equal(returned.session.isReturnVisit, true);
    assert.equal((await advance("returned_without_questions")).json().balance, 35);
    assert.equal((await advance("returned_without_questions")).json().balance, 35);
    assert.equal(ledger.length, 2);
    assert.equal((await visit()).json().session, null);
    day++;
    difficulty = "ADVANCED";
    assert.equal((await visit()).json().session.scriptId, "fox_older_honey_business");
    spendable = 25;
    const insufficient = await advance("start", "give_now");
    assert.equal(insufficient.statusCode, 409);
    assert.equal(insufficient.json().error, "insufficient_free_funds");
    assert.equal(spendable, 25);
    assert.equal(state.session!.currentNodeId, "start");
    day++;
    state.session = null;
    Math.random = () => 0.7;
    assert.equal((await visit()).json().session, null);
    Math.random = () => { throw new Error("same day must not roll again"); };
    assert.equal((await visit()).json().session, null);
  } finally {
    pool.query = originalQuery;
    pool.connect = originalConnect;
    Math.random = originalRandom;
    await app.close();
  }
});
