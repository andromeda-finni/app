import assert from "node:assert/strict";
import test from "node:test";

import { parsePrivateHosts, validateAppDatabaseUrl } from "../src/lib/database-config.js";

test("accepts an explicit non-TLS connection to loopback PostgreSQL", () => {
  const value = "postgres://groshik_app:secret@localhost:5432/groshik?sslmode=disable";
  assert.equal(validateAppDatabaseUrl(value), value);
});

test("rejects ambiguous TLS fallback for local PostgreSQL", () => {
  assert.throws(
    () => validateAppDatabaseUrl("postgres://groshik_app:secret@127.0.0.1:5432/groshik?sslmode=prefer"),
    /Local APP_DATABASE_URL must use sslmode=disable/,
  );
});

test("accepts certificate-verified TLS for a remote PostgreSQL host", () => {
  const value = "postgres://groshik_app:secret@db.example.com:5432/groshik?sslmode=verify-full";
  assert.equal(validateAppDatabaseUrl(value), value);
});

test("rejects an insecure remote PostgreSQL connection", () => {
  assert.throws(
    () => validateAppDatabaseUrl("postgres://groshik_app:secret@db.example.com:5432/groshik?sslmode=disable"),
    /Non-local APP_DATABASE_URL must use sslmode=verify-full/,
  );
});

test("rejects malformed and incomplete database URLs without exposing them", () => {
  assert.throws(() => validateAppDatabaseUrl("not a URL"), /valid PostgreSQL URL/);
  assert.throws(
    () => validateAppDatabaseUrl("postgres://groshik_app@localhost:5432/groshik?sslmode=disable"),
    /must include username, password, host, and database name/,
  );
});

test("a host on the same machine's private network may skip TLS only when listed", () => {
  const value = "postgres://groshik_app:secret@db:5432/groshik?sslmode=disable";
  assert.throws(() => validateAppDatabaseUrl(value), /Non-local APP_DATABASE_URL must use sslmode=verify-full/);
  assert.equal(validateAppDatabaseUrl(value, parsePrivateHosts(" db , cache")), value);
  assert.throws(
    () => validateAppDatabaseUrl(
      "postgres://groshik_app:secret@db:5432/groshik?sslmode=prefer",
      parsePrivateHosts("db"),
    ),
    /private host must use sslmode=disable or sslmode=verify-full/,
  );
  // Listing one private host does not relax any other remote host.
  assert.throws(
    () => validateAppDatabaseUrl(
      "postgres://groshik_app:secret@db.example.com:5432/groshik?sslmode=disable",
      parsePrivateHosts("db"),
    ),
    /Non-local APP_DATABASE_URL must use sslmode=verify-full/,
  );
});
