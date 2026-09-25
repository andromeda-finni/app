import assert from "node:assert/strict";
import test from "node:test";

import Fastify from "fastify";

test("onboarding status resumes and progress advances sequentially and idempotently", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const [{ pool }, { HttpError }, { onboardingRoutes }] = await Promise.all([
    import("../src/lib/db.js"),
    import("../src/lib/errors.js"),
    import("../src/modules/onboarding/routes.js"),
  ]);
  const app = Fastify();
  const originalQuery = pool.query;
  const originalConnect = pool.connect;
  let currentStep = 2;
  let completedAt: Date | null = null;

  pool.query = (async (text: string) => {
    if (text.includes("FROM auth_credentials")) {
      return { rows: [{ user_id: "child-1", role: "CHILD" }], rowCount: 1 };
    }
    if (text.startsWith("UPDATE auth_credentials")) {
      return { rows: [], rowCount: 1 };
    }
    if (text.includes("FROM child_profiles cp")) {
      return {
        rows: [
          {
            onboarding_step: currentStep,
            onboarding_completed_at: completedAt,
            pet_name: "Мурзик",
            fur_option_id: "FUR_GRAY",
          },
        ],
        rowCount: 1,
      };
    }
    throw new Error(`Unexpected query in test: ${text}`);
  }) as typeof pool.query;

  const transactionClient = {
    query: async (text: string, params: unknown[] = []) => {
      if (text === "BEGIN" || text === "COMMIT" || text === "ROLLBACK") {
        return { rows: [], rowCount: null };
      }
      if (text.includes("SELECT onboarding_step")) {
        return {
          rows: [
            {
              onboarding_step: currentStep,
              onboarding_completed_at: completedAt,
            },
          ],
          rowCount: 1,
        };
      }
      if (text.includes("SET onboarding_step = $2")) {
        currentStep = params[1] as number;
        return { rows: [], rowCount: 1 };
      }
      if (text.includes("SET onboarding_completed_at = now()")) {
        completedAt = new Date("2026-09-23T12:00:00Z");
        return { rows: [], rowCount: 1 };
      }
      throw new Error(`Unexpected transaction query in test: ${text}`);
    },
    release: () => undefined,
  };
  pool.connect = (async () => transactionClient) as unknown as typeof pool.connect;

  try {
    app.setErrorHandler((err, _request, reply) => {
      if (err instanceof HttpError) {
        reply.code(err.statusCode).send({ error: err.code, details: err.details });
        return;
      }
      reply.code(500).send({ error: "internal_server_error" });
    });
    await app.register(onboardingRoutes);

    const status = await app.inject({
      method: "GET",
      url: "/onboarding/status",
      headers: { authorization: "Bearer token" },
    });
    assert.equal(status.statusCode, 200);
    assert.deepEqual(status.json(), {
      currentStep: 2,
      completed: false,
      pet: { petName: "Мурзик", furOptionId: "FUR_GRAY" },
    });

    const completeStep2 = await app.inject({
      method: "PUT",
      url: "/onboarding/progress",
      headers: { authorization: "Bearer token" },
      payload: { completedStep: 2 },
    });
    assert.equal(completeStep2.statusCode, 200);
    assert.deepEqual(completeStep2.json(), { currentStep: 3, completed: false });

    const retryStep2 = await app.inject({
      method: "PUT",
      url: "/onboarding/progress",
      headers: { authorization: "Bearer token" },
      payload: { completedStep: 2 },
    });
    assert.equal(retryStep2.statusCode, 200);
    assert.deepEqual(retryStep2.json(), { currentStep: 3, completed: false });

    const skipStep3 = await app.inject({
      method: "PUT",
      url: "/onboarding/progress",
      headers: { authorization: "Bearer token" },
      payload: { completedStep: 4 },
    });
    assert.equal(skipStep3.statusCode, 409);
    assert.deepEqual(skipStep3.json(), {
      error: "onboarding_step_out_of_order",
      details: { currentStep: 3 },
    });

    for (const completedStep of [3, 4]) {
      const response = await app.inject({
        method: "PUT",
        url: "/onboarding/progress",
        headers: { authorization: "Bearer token" },
        payload: { completedStep },
      });
      assert.equal(response.statusCode, 200);
    }

    const completedStatus = await app.inject({
      method: "GET",
      url: "/onboarding/status",
      headers: { authorization: "Bearer token" },
    });
    assert.deepEqual(completedStatus.json(), {
      currentStep: 4,
      completed: true,
      pet: { petName: "Мурзик", furOptionId: "FUR_GRAY" },
    });
  } finally {
    pool.query = originalQuery;
    pool.connect = originalConnect;
    await app.close();
  }
});
