import assert from "node:assert/strict";
import test from "node:test";

process.env["APP_DATABASE_URL"] = "postgres://test:test@localhost:5432/test?sslmode=disable";
const { corsOriginPolicy } = await import("../src/app.js");

function allows(policy: ReturnType<typeof corsOriginPolicy>, origin: string | undefined) {
  let result: boolean | undefined;
  policy(origin, (_err, allow) => (result = allow));
  return result;
}

test("without CORS_ORIGINS only loopback web origins are allowed", () => {
  const policy = corsOriginPolicy(undefined);
  assert.equal(allows(policy, "http://localhost:53211"), true);
  assert.equal(allows(policy, "http://127.0.0.1:8080"), true);
  // Reflecting any origin was the bug: an arbitrary site must be refused.
  assert.equal(allows(policy, "https://evil.example"), false);
  assert.equal(allows(policy, "not a url"), false);
});

test("CORS_ORIGINS replaces the loopback default with an exact allow-list", () => {
  const policy = corsOriginPolicy("https://app.groshik.example, https://staging.groshik.example");
  assert.equal(allows(policy, "https://app.groshik.example"), true);
  assert.equal(allows(policy, "https://staging.groshik.example"), true);
  assert.equal(allows(policy, "http://localhost:53211"), false);
  assert.equal(allows(policy, "https://app.groshik.example.evil.example"), false);
});

test("requests without an Origin header are not subject to CORS", () => {
  // Native apps and curl send no Origin; blocking them would break the app.
  assert.equal(allows(corsOriginPolicy(undefined), undefined), true);
});
