import assert from "node:assert/strict";
import test from "node:test";

import Fastify from "fastify";

test("child registration creates empty wallets without a starting grant", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { authRoutes }] = await Promise.all([
    import("../src/lib/db.js"),
    import("../src/auth/routes.js"),
  ]);
  const app = Fastify();
  const originalConnect = pool.connect;
  const queries: string[] = [];

  const transactionClient = {
    query: async (text: string) => {
      queries.push(text);
      if (text === "BEGIN" || text === "COMMIT" || text === "ROLLBACK") {
        return { rows: [], rowCount: null };
      }
      if (text.includes("INSERT INTO users")) {
        return {
          rows: [{ id: "11111111-1111-4111-8111-111111111111" }],
          rowCount: 1,
        };
      }
      if (
        text.includes("INSERT INTO child_profiles") ||
        text.includes("INSERT INTO wallets") ||
        text.includes("INSERT INTO auth_credentials")
      ) {
        return { rows: [], rowCount: 1 };
      }
      throw new Error(`Unexpected transaction query in test: ${text}`);
    },
    release: () => undefined,
  };
  pool.connect = (async () => transactionClient) as unknown as typeof pool.connect;

  try {
    await app.register(authRoutes);
    const response = await app.inject({
      method: "POST",
      url: "/auth/child/register",
      payload: {},
    });

    assert.equal(response.statusCode, 201);
    assert.equal(
      response.json().userId,
      "11111111-1111-4111-8111-111111111111",
    );
    assert.ok(queries.some((query) => query.includes("INSERT INTO wallets")));
    assert.ok(!queries.some((query) => query.includes("INSERT INTO transactions")));
    assert.ok(!queries.some((query) => query.includes("UPDATE wallets SET balance")));
  } finally {
    pool.connect = originalConnect;
    await app.close();
  }
});
