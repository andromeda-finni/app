import assert from "node:assert/strict";
import test from "node:test";

import Fastify from "fastify";

test("insurance purchase charges SPENDABLE once and blocks a second policy for tomorrow", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { HttpError }, { insuranceRoutes }] = await Promise.all([
    import("../src/lib/db.js"),
    import("../src/lib/errors.js"),
    import("../src/modules/insurance/routes.js"),
  ]);
  const app = Fastify();
  app.setErrorHandler((error, _req, reply) => {
    if (error instanceof HttpError) {
      reply.code(error.statusCode).send({ error: error.code });
      return;
    }
    reply.code(500).send({ error: String(error) });
  });

  const originalQuery = pool.query;
  const originalConnect = pool.connect;
  let policyExists = false;
  let walletBalance = 30;
  let transactionInserts = 0;

  pool.query = (async (text: string) => {
    if (text.includes("FROM auth_credentials")) {
      return { rows: [{ user_id: "child-1", role: "CHILD" }], rowCount: 1 };
    }
    return { rows: [], rowCount: 1 };
  }) as typeof pool.query;

  pool.connect = (async () => ({
    query: async (text: string, params: unknown[] = []) => {
      if (text === "BEGIN" || text === "COMMIT" || text === "ROLLBACK") {
        return { rows: [], rowCount: null };
      }
      if (text.includes("INSERT INTO idempotency_keys")) {
        return { rows: [{}], rowCount: 1 };
      }
      if (text.includes("UPDATE idempotency_keys")) {
        return { rows: [], rowCount: 1 };
      }
      if (text.includes("FROM game_periods gp")) {
        assert.match(text, /FOR UPDATE OF gp/);
        return { rows: [{ id: "day-1", sequence_no: 1 }], rowCount: 1 };
      }
      if (text.includes("UPDATE insurance_policies")) {
        return { rows: [], rowCount: 0 };
      }
      if (text.includes("SELECT 1 FROM insurance_policies")) {
        return policyExists ? { rows: [{}], rowCount: 1 } : { rows: [], rowCount: 0 };
      }
      if (text.includes("SELECT gen_random_uuid")) {
        return { rows: [{ id: "11111111-1111-1111-1111-111111111111" }], rowCount: 1 };
      }
      if (text.includes("SELECT balance FROM wallets")) {
        return { rows: [{ balance: walletBalance }], rowCount: 1 };
      }
      if (text.includes("INSERT INTO transactions")) {
        transactionInserts++;
        assert.equal(params[2], "INSURANCE_PREMIUM");
        assert.equal(params[3], -5);
        return { rows: [{ id: "txn-1" }], rowCount: 1 };
      }
      if (text.includes("UPDATE wallets")) {
        walletBalance = params[0] as number;
        return { rows: [], rowCount: 1 };
      }
      if (text.includes("INSERT INTO insurance_policies")) {
        policyExists = true;
        return { rows: [], rowCount: 1 };
      }
      throw new Error(`Unexpected transaction query in test: ${text}`);
    },
    release: () => undefined,
  })) as unknown as typeof pool.connect;

  try {
    await app.register(insuranceRoutes);
    const headers = { authorization: "Bearer token" };
    const first = await app.inject({
      method: "POST",
      url: "/insurance/purchase",
      headers,
      payload: { idempotencyKey: "insurance-test-1" },
    });
    assert.equal(first.statusCode, 201, first.body);
    assert.equal(first.json().coverageSequence, 2);
    assert.equal(first.json().balanceAfter, 25);
    assert.equal(walletBalance, 25);
    assert.equal(transactionInserts, 1);

    const duplicate = await app.inject({
      method: "POST",
      url: "/insurance/purchase",
      headers,
      payload: { idempotencyKey: "insurance-test-2" },
    });
    assert.equal(duplicate.statusCode, 409, duplicate.body);
    assert.equal(duplicate.json().error, "insurance_already_purchased_for_next_day");
    assert.equal(walletBalance, 25);
    assert.equal(transactionInserts, 1);
  } finally {
    pool.query = originalQuery;
    pool.connect = originalConnect;
    await app.close();
  }
});
