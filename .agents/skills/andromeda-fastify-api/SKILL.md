---
name: andromeda-fastify-api
description: Build and review Andromeda Fastify v5 and strict TypeScript APIs using runtime schemas, authenticated ownership checks, direct parameterized PostgreSQL access, atomic domain operations, and injection tests. Use for backend routes, plugins, server lifecycle, API contracts, or Flutter-backend integration.
---

# Andromeda Fastify API

Work with the existing Node.js ESM, NodeNext TypeScript, Fastify v5, and direct pg architecture. Do not introduce an ORM or a new framework without an explicit architectural decision.

## Route contract

For every endpoint define:

- HTTP method and stable resource-oriented path;
- authenticated role and ownership rule;
- runtime request schema for params, query, headers, and body;
- response schema where it adds contract or serialization safety;
- success status and typed domain-error statuses;
- transaction and idempotency requirements.

TypeScript generics do not validate untrusted runtime input. Use Fastify schemas and preserve strict typing. Reject unknown, malformed, out-of-range, or semantically invalid values at the boundary.

## Fastify structure

- Keep route groups modular and register shared behavior as plugins or hooks.
- Use Fastify's logger and request context; never log bearer tokens, invite codes, secrets, or child-entered content unnecessarily.
- Centralize error translation. Do not leak SQL, stack traces, or internal identifiers in production responses.
- Prefer app.inject for route tests because it exercises hooks, validation, status codes, and serialization without binding a port.
- Keep server construction separate from listen so tests can instantiate and close the app.

## Authentication and authorization

Authenticate opaque bearer tokens through the existing auth hook. Derive identity and role server-side. Every resource query or mutation must constrain ownership in SQL or prove it inside the same transaction; never trust a client-supplied user id as authorization.

Registration, invitations, rewards, purchases, and state transitions must resist replay. Return a stable conflict or existing result for duplicate operations according to the domain rule.

## Database interaction

- Use positional parameters for every untrusted value.
- Use one acquired client for all statements in a transaction.
- Lock rows in a deterministic order for concurrent money or state changes.
- Reuse the ledger helpers for wallet mutations.
- Map expected constraint conflicts to stable domain errors; do not catch and flatten every database error.

## Web integration

When a browser client is introduced, configure CORS with an environment-specific allow-list. Do not use a wildcard with credentials. Keep the backend bind host configurable and keep PostgreSQL bound to loopback or the private Docker network.

## Lifecycle and verification

External calls need timeouts, bounded retries only for safe/idempotent operations, and cancellation where practical. If touching server lifecycle, close the Fastify app and pg pool on shutdown.

Run npm ci when lockfile fidelity matters, npm run typecheck, npm run build, route tests, and relevant database integration tests before claiming completion.

For current Fastify-specific details, prefer the official Fastify documentation and the maintained mcollina/skills fastify-best-practices skill over generic Express patterns.
