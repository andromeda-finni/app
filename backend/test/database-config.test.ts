import assert from "node:assert/strict";
import test from "node:test";

import { validateAppDatabaseUrl } from "../src/lib/database-config.js";

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
