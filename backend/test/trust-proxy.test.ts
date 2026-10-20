import assert from "node:assert/strict";
import test from "node:test";

process.env["APP_DATABASE_URL"] ??=
  "postgres://test:test@localhost:5432/test?sslmode=disable";
const { trustProxySetting } = await import("../src/app.js");

test("no proxy is trusted unless configured", () => {
  assert.equal(trustProxySetting(undefined), false);
  assert.equal(trustProxySetting(""), false);
});

test("exactly the configured number of proxy hops is trusted", () => {
  const one = trustProxySetting("1");
  assert.ok(one);
  assert.equal(one("172.18.0.5", 0), true);
  assert.equal(one("203.0.113.7", 1), false);
  const two = trustProxySetting(" 2 ");
  assert.ok(two);
  assert.equal(two("10.0.0.1", 1), true);
  assert.equal(two("10.0.0.2", 2), false);
});

test("invalid hop counts fail at startup instead of trusting everything", () => {
  for (const value of ["0", "-1", "true", "1.5", "99"]) {
    assert.throws(() => trustProxySetting(value), /TRUST_PROXY_HOPS/);
  }
});

test("behind one proxy the rate limit sees each child's own address", async () => {
  const Fastify = (await import("fastify")).default;
  const app = Fastify({ trustProxy: trustProxySetting("1") });
  app.get("/ip", async (req) => ({ ip: req.ip }));
  const res = await app.inject({
    method: "GET",
    url: "/ip",
    remoteAddress: "172.18.0.5",
    headers: { "x-forwarded-for": "203.0.113.7" },
  });
  assert.equal(res.json().ip, "203.0.113.7");

  // A client cannot hide behind a forged chain: only one hop is trusted.
  const forged = await app.inject({
    method: "GET",
    url: "/ip",
    remoteAddress: "172.18.0.5",
    headers: { "x-forwarded-for": "1.2.3.4, 203.0.113.7" },
  });
  assert.equal(forged.json().ip, "203.0.113.7");
  await app.close();
});

test("without a proxy, X-Forwarded-For is ignored", async () => {
  const Fastify = (await import("fastify")).default;
  const app = Fastify({ trustProxy: trustProxySetting(undefined) });
  app.get("/ip", async (req) => ({ ip: req.ip }));
  const res = await app.inject({
    method: "GET",
    url: "/ip",
    remoteAddress: "198.51.100.9",
    headers: { "x-forwarded-for": "1.2.3.4" },
  });
  assert.equal(res.json().ip, "198.51.100.9");
  await app.close();
});
