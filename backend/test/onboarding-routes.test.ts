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
  const app = Fastify({
    ajv: { customOptions: { removeAdditional: false } },
  });
  const originalQuery = pool.query;
  const originalConnect = pool.connect;
  let currentStep = 2;
  let completedAt: Date | null = null;
  let homeTourCompletedAt: Date | null = null;
  let authRole = "CHILD";
  let profileExists = true;

  pool.query = (async (text: string) => {
    if (text.includes("FROM auth_credentials")) {
      return { rows: [{ user_id: "child-1", role: authRole }], rowCount: 1 };
    }
    if (text.startsWith("UPDATE auth_credentials")) {
      return { rows: [], rowCount: 1 };
    }
    if (text.includes("FROM child_profiles cp")) {
      return {
        rows: profileExists ? [
          {
            difficulty: "ADVANCED",
            onboarding_step: currentStep,
            onboarding_completed_at: completedAt,
            home_tour_completed_at: homeTourCompletedAt,
            pet_name: "Мурзик",
            fur_option_id: "FUR_GRAY",
          },
        ] : [],
        rowCount: profileExists ? 1 : 0,
      };
    }
    if (text.startsWith("UPDATE child_profiles") && text.includes("home_tour_completed_at")) {
      if (!profileExists) return { rows: [], rowCount: 0 };
      homeTourCompletedAt ??= new Date("2026-09-27T12:00:00Z");
      return { rows: [], rowCount: 1 };
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
      const validationError = err as { statusCode?: number };
      if (validationError.statusCode) {
        reply.code(validationError.statusCode).send({ error: "request_error" });
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
      difficulty: "ADVANCED",
      currentStep: 2,
      completed: false,
      homeTourCompleted: false,
      pet: { petName: "Мурзик", furOptionId: "FUR_GRAY" },
    });

    authRole = "PARENT";
    const forbiddenTour = await app.inject({
      method: "PUT",
      url: "/onboarding/home-tour",
      headers: { authorization: "Bearer token" },
      payload: {},
    });
    assert.equal(forbiddenTour.statusCode, 403);
    authRole = "CHILD";

    for (let attempt = 0; attempt < 2; attempt++) {
      const completedTour = await app.inject({
        method: "PUT",
        url: "/onboarding/home-tour",
        headers: { authorization: "Bearer token" },
        payload: {},
      });
      assert.equal(completedTour.statusCode, 200);
      assert.deepEqual(completedTour.json(), { homeTourCompleted: true });
    }

    const unknownTourField = await app.inject({
      method: "PUT",
      url: "/onboarding/home-tour",
      headers: { authorization: "Bearer token" },
      payload: { completed: true },
    });
    assert.equal(unknownTourField.statusCode, 400);

    profileExists = false;
    const missingProfileTour = await app.inject({
      method: "PUT",
      url: "/onboarding/home-tour",
      headers: { authorization: "Bearer token" },
      payload: {},
    });
    assert.equal(missingProfileTour.statusCode, 404);
    profileExists = true;

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
      difficulty: "ADVANCED",
      currentStep: 4,
      completed: true,
      homeTourCompleted: true,
      pet: { petName: "Мурзик", furOptionId: "FUR_GRAY" },
    });
  } finally {
    pool.query = originalQuery;
    pool.connect = originalConnect;
    await app.close();
  }
});
