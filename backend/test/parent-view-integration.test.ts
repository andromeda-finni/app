import assert from "node:assert/strict";
import test from "node:test";
import Fastify from "fastify";

// Opt in with a disposable, migrated and seeded DB. Never uses the app's .env.
test("parent sees only children who redeemed their invite", {
  skip: !process.env["ECONOMY_TEST_DATABASE_URL"],
}, async () => {
  process.env["APP_DATABASE_URL"] = process.env["ECONOMY_TEST_DATABASE_URL"]!;
  const { pool } = await import("../src/lib/db.js");
  const { HttpError } = await import("../src/lib/errors.js");
  const { authRoutes } = await import("../src/auth/routes.js");
  const { petRoutes } = await import("../src/modules/pet/routes.js");
  const { parentViewRoutes } = await import("../src/modules/parentView/routes.js");
  const { parentTaskRoutes } = await import("../src/modules/parentTasks/routes.js");
  const { goalRoutes } = await import("../src/modules/goals/routes.js");
  const { periodRoutes } = await import("../src/modules/periods/routes.js");
  const app = Fastify({ ajv: { customOptions: { removeAdditional: false } } });
  app.setErrorHandler((error, _req, reply) => {
    if (error instanceof HttpError) reply.code(error.statusCode).send({ error: error.code });
    else reply.code((error as { statusCode?: number }).statusCode ?? 500).send({ error: String(error) });
  });
  for (const routes of [
    authRoutes,
    petRoutes,
    parentViewRoutes,
    parentTaskRoutes,
    goalRoutes,
    periodRoutes,
  ]) await app.register(routes);

  const register = async (url: string) => {
    const res = await app.inject({ method: "POST", url, payload: {} });
    assert.equal(res.statusCode, 201, res.body);
    return { authorization: `Bearer ${res.json().token}` };
  };
  const call = (method: "GET" | "POST" | "PUT", url: string, headers: object, payload?: object) =>
    app.inject({ method, url, headers, ...(payload ? { payload } : {}) });

  try {
    const parent = await register("/auth/parent/register");
    const stranger = await register("/auth/parent/register");
    const child = await register("/auth/child/register");
    await call("PUT", "/pet", child, { petName: "Пушок", furOptionId: "FUR_GRAY" });

    assert.deepEqual((await call("GET", "/parent/children", parent)).json(), []);
    assert.equal((await call("GET", "/child/parent-link", child)).json().linked, false);

    const { inviteCode } = (await call("POST", "/auth/parent/invites", parent)).json();
    // Codes are read aloud, so a lower-case entry must still match.
    const redeem = await call("POST", "/child/parent-link/redeem", child, {
      inviteCode: inviteCode.toLowerCase(),
    });
    assert.equal(redeem.statusCode, 200, redeem.body);
    const reuse = await call("POST", "/child/parent-link/redeem", child, { inviteCode });
    assert.equal(reuse.json().error, "invite_code_invalid_or_expired");
    assert.equal((await call("GET", "/child/parent-link", child)).json().linked, true);

    const children = (await call("GET", "/parent/children", parent)).json();
    assert.equal(children.length, 1);
    assert.equal(children[0].petName, "Пушок");
    const overviewUrl = `/parent/children/${children[0].childUserId}/overview`;

    const overview = await call("GET", overviewUrl, parent);
    assert.equal(overview.statusCode, 200, overview.body);
    assert.equal(overview.json().pet.pet_name, "Пушок");
    assert.equal(overview.json().wallets.SPENDABLE, 0);
    assert.equal(overview.json().rules.parentRewardLimit, 10);

    const childUserId = children[0].childUserId as string;
    const forbiddenTask = await call("POST", "/parent/tasks", stranger, {
      childUserId,
      title: "Чужое поручение",
      rewardAmount: 10,
    });
    assert.equal(forbiddenTask.statusCode, 403, forbiddenTask.body);
    const excessiveTask = await call("POST", "/parent/tasks", parent, {
      childUserId,
      title: "Слишком большая награда",
      rewardAmount: 11,
    });
    assert.equal(excessiveTask.statusCode, 400, excessiveTask.body);
    const blankTask = await call("POST", "/parent/tasks", parent, {
      childUserId,
      title: "   ",
      rewardAmount: 1,
    });
    assert.equal(blankTask.statusCode, 400, blankTask.body);

    const createdTask = await call("POST", "/parent/tasks", parent, {
      childUserId,
      title: "  Полить цветы  ",
      rewardAmount: 10,
    });
    assert.equal(createdTask.statusCode, 201, createdTask.body);
    const assignmentId = createdTask.json().id as string;
    const withTask = (await call("GET", overviewUrl, parent)).json();
    assert.equal(withTask.parentTasks[0].title, "Полить цветы");
    assert.equal(withTask.parentTasks[0].status, "AVAILABLE");

    assert.equal(
      (await call("POST", `/child/tasks/${assignmentId}/submit`, child)).statusCode,
      200,
    );
    const tooEarly = await call("POST", `/parent/tasks/${assignmentId}/verify`, parent);
    assert.equal(tooEarly.statusCode, 409, tooEarly.body);

    assert.equal((await call("POST", "/goals", child, {
      targetItemId: "saucer",
    })).statusCode, 201);
    assert.equal((await call("POST", "/periods", child)).statusCode, 201);
    const paid = await call("POST", `/parent/tasks/${assignmentId}/verify`, parent);
    assert.equal(paid.statusCode, 200, paid.body);
    assert.equal(paid.json().balanceAfter, 40);
    assert.equal(
      (await call("POST", `/parent/tasks/${assignmentId}/verify`, parent)).statusCode,
      404,
    );

    // Isolation: only the linked parent may read the child, and only parents.
    assert.equal((await call("GET", overviewUrl, stranger)).statusCode, 403);
    assert.equal((await call("GET", "/parent/children", child)).statusCode, 403);
    assert.equal((await app.inject({ method: "GET", url: "/parent/children" })).statusCode, 401);
  } finally {
    await app.close();
    await pool.end();
  }
});
