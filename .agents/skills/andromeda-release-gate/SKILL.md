---
name: andromeda-release-gate
description: Verify Andromeda changes before claiming completion, merging, releasing, or handing off by selecting risk-based Flutter, backend, database, security, and manual checks. Use when work is described as ready, finished, fixed, releasable, or production-ready.
---

# Andromeda Release Gate

Evidence must match the claim. A passing formatter is not proof of a build; a successful build is not proof of behavior.

## Determine the affected surfaces

Inspect the diff and map it to Flutter Android, Flutter Web, Fastify, PostgreSQL migrations, Docker/local setup, authentication, economy, and CI. Run the smallest complete verification set that covers every affected surface.

## Standard commands

For Flutter changes:

- dart format --output=none --set-exit-if-changed .
- flutter analyze
- flutter test
- flutter build web when shared UI or Web behavior changed
- flutter build apk when Android configuration, plugins, or release behavior changed

For backend changes:

- npm ci when dependencies or lockfile fidelity matter
- npm run typecheck
- npm run build
- route or integration tests relevant to the change
- GET /health plus one representative success and failure path when runtime behavior changed

For database changes:

- start a disposable or explicitly approved local PostgreSQL instance
- apply migrations from zero
- rerun the migration script
- apply seed data when relevant
- exercise the changed path as groshik_app
- verify rollback, constraints, ownership, idempotency, and concurrency where affected

## Risk gates

- Auth or authorization: negative tests for missing, wrong-role, revoked, and cross-account access.
- Economy: reconciliation, insufficient funds, replay, rollback, and simultaneous requests.
- Web/mobile: narrow viewport, refresh, offline or timeout state, secure storage context, and real release assets.
- Dependency changes: review provenance, maintenance, license, transitive impact, and lockfile diff.
- Deployment changes: environment validation, health/readiness, least privilege, rollback, and secret handling.

## Completion report

State each command or manual check actually run, its result, and any skipped check with the reason and resulting risk. Never mark tests as passed when they were not run in the current change context. Never hide warnings, partial coverage, unavailable services, or manual steps.

Before the final claim, inspect git diff --check and git status so generated files, secrets, unrelated edits, and ignored-but-required artifacts are not missed.

This gate adopts the evidence-before-claims principle from the maintained obra/superpowers verification-before-completion skill and tailors it to this repository.
