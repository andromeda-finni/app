---
name: andromeda-feature-design
description: Design substantial Andromeda features before implementation by turning product intent into scoped cross-layer contracts and verifiable acceptance criteria. Use for changes spanning Flutter, Fastify, PostgreSQL, authentication, wallet state, or multiple user roles. Do not use for trivial styling edits or already-clear one-file fixes.
---

# Andromeda Feature Design

Design the smallest production-ready change that preserves existing product and data invariants.

## Establish facts first

Inspect the relevant Flutter flow, Fastify routes, SQL migrations, tests, and project documentation before proposing architecture. Separate:

- repository facts;
- explicit user requirements;
- assumptions that still need confirmation.

Do not invent business rules. Ask only when a missing choice materially changes persisted data, authorization, money movement, or user-visible behavior.

## Build the feature contract

For a substantial feature, define:

1. Goal and observable user outcome.
2. In-scope and explicitly out-of-scope behavior.
3. Parent and child permissions and resource ownership.
4. State transitions, invalid transitions, and retry behavior.
5. Flutter states: loading, success, empty, validation failure, transport failure, and recovery.
6. API contract: method, path, authenticated role, request validation, response shape, and domain errors.
7. Database impact: tables, constraints, transaction boundary, locking, idempotency, migration, and seed changes.
8. Verification at unit, widget, route-injection, database-integration, and manual-flow levels as applicable.

Map each layer only when it is affected. Avoid speculative abstractions and new dependencies.

## Preserve project invariants

- The server is authoritative for balances, rewards, progression, ownership, and state transitions.
- Wallet mutations go through the atomic ledger path; the client never supplies a resulting balance.
- Persistent actions must be safe under retry and concurrent requests.
- Authentication uses opaque bearer tokens; raw tokens are not stored by the server.
- Do not introduce child PII without an explicit product and privacy decision.
- Keep PostgreSQL behind the backend. Never connect Flutter directly to the database.
- Support both Android and Web when shared Flutter code is changed; state any intentional platform limitation.

## Cover material edge cases

Consider duplicated taps, request timeout after server commit, stale client state, partially completed onboarding, expired or reused invitations, insufficient funds, simultaneous wallet operations, missing seed content, browser refresh, narrow screens, keyboard overlap, accessibility, and secure-context restrictions on web storage.

Include only cases relevant to the feature.

## Produce implementable acceptance criteria

Each criterion must identify a starting condition, action, observable result, prohibited side effect when material, and verification method. Prefer concrete pass/fail language over words such as “correctly”, “securely”, or “properly”.

Before implementation, summarize the chosen flow and the files expected to change. During implementation, revise the contract only when repository evidence requires it and disclose the revision.
