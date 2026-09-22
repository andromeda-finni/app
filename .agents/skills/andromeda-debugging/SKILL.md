---
name: andromeda-debugging
description: Diagnose Andromeda failures across Flutter, browser, Fastify, Docker, and PostgreSQL by gathering evidence and isolating the failing boundary before changing code. Use for bugs, hangs, startup failures, network issues, incorrect state, flaky tests, or regressions.
---

# Andromeda Debugging

Find the root cause before implementing a fix. Do not stack speculative changes.

## Reproduce and classify

Record the exact action, environment, URL or device, expected result, observed result, timing, and whether the failure is deterministic. Identify the earliest failing layer:

1. Flutter widget or state lifecycle.
2. Browser loading, console, secure context, cache, service worker, or responsive rendering.
3. Network route, host binding, port, CORS, timeout, or firewall.
4. Fastify validation, auth hook, route handler, or error translation.
5. PostgreSQL connection, migration, constraint, lock, or transaction.
6. Docker process, port mapping, volume, health, or environment.

## Gather evidence

Use the narrowest relevant signals: Flutter exception output, browser console and network requests, Fastify request logs, curl against health and failing endpoints, docker compose ps/logs, listening ports, environment presence without printing secrets, PostgreSQL error codes, and a minimal SQL read.

Compare a working path with the failing path. Trace identifiers and state forward across boundaries or trace the bad value backward to its source.

## Form and test one hypothesis

State the evidence, hypothesis, and one observation that would falsify it. Change one variable at a time. Prefer a minimal reproduction or diagnostic check over an implementation edit.

After three failed hypotheses, stop adding patches and reassess assumptions, architecture, and reproduction fidelity.

## Common project traps

- 127.0.0.1 on a phone refers to the phone, not the development Mac.
- A server can answer locally while guest Wi-Fi or AP isolation blocks another device.
- Flutter debug web builds can load slowly over Wi-Fi; reproduce with a release build.
- flutter_secure_storage on Web requires HTTPS or localhost for cryptographic operations.
- A browser may retain stale service-worker assets.
- Docker port 5432 can conflict with a Homebrew PostgreSQL service.
- The backend defaults to loopback unless HOST is configured.
- A request timeout does not prove the server rolled back; retries need idempotency.
- A transaction can still race if ownership/state reads occur outside it.

## Fix and prove

Implement the smallest fix that addresses the demonstrated cause. Add a regression test at the layer where the defect escaped. Re-run the original reproduction plus adjacent success and failure cases, then report the evidence and any unverified environment assumptions.

This workflow incorporates the evidence-first principles from the maintained obra/superpowers systematic-debugging skill without importing its unrelated orchestration rules.
