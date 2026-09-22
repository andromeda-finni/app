---
name: andromeda-security
description: Threat-model and review Andromeda changes involving authentication, authorization, child data, browser access, secrets, invitations, economy, or public deployment. Use for security-sensitive implementation and review; do not invoke as ceremony for isolated visual edits.
---

# Andromeda Security

Review the concrete change and trust boundaries before applying a checklist. Prioritize exploitable paths and violations of project invariants.

## Trust boundaries and assets

Protect opaque bearer tokens, invitation codes, account links, wallet balances, transaction history, inventory, goals, and parent-only actions. Flutter, browser storage, request bodies, URLs, and headers are untrusted. Fastify is the policy boundary; PostgreSQL constraints and the restricted role are the final integrity boundary.

The product intentionally avoids child PII. Flag any proposal to store names of people, ages, birth dates, email, phone, location, device identifiers, analytics identifiers, or free-form child data for explicit privacy review. A pet name is still untrusted content and may require moderation and output safety.

## Review requirements

- Generate credentials with cryptographically secure randomness and sufficient entropy.
- Store only token hashes server-side; support revocation and avoid tokens in URLs or logs.
- Enforce role and ownership on every protected query and mutation.
- Make invitation redemption single-use, expiring, rate-limited, and transactionally linked.
- Validate input at the API boundary and parameterize SQL.
- Keep economic outcomes server-computed, atomic, concurrency-safe, and idempotent.
- Keep secrets in environment or deployment secret stores; never commit .env or production URLs with credentials.
- Return minimal errors and apply rate limits appropriate to registration, invitation, and guessing-sensitive routes.
- Pin browser CORS to known origins. CORS is not authorization.
- Use HTTPS in deployed environments. Web secure storage based on WebCrypto requires a secure context; insecure LAN HTTP is development-only and must not be described as secure.
- Keep PostgreSQL unavailable to the public internet unless a managed private-access design explicitly requires otherwise.

## Verification

Test missing, malformed, revoked, wrong-role, and cross-account credentials. Attempt identifier swapping, replay, duplicate taps, concurrent spending, negative and oversized amounts, expired invitations, malformed JSON, and unexpected fields. Check logs and error responses for secrets or sensitive data.

Report findings with severity, evidence, affected path, exploit scenario, and the smallest safe fix. Do not claim the system is secure solely because dependencies, CORS, TLS, or parameterized SQL are present.
