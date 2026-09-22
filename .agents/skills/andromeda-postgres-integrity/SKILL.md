---
name: andromeda-postgres-integrity
description: Design and review Andromeda PostgreSQL schema changes, migrations, queries, and wallet transactions while preserving data integrity, least privilege, concurrency safety, and replay protection. Use for db migrations, pg queries, indexes, constraints, seed data, or ledger behavior.
---

# Andromeda PostgreSQL Integrity

Treat migrations and the database constraints as the durable source of truth. The backend uses direct parameterized SQL and the least-privilege groshik_app role.

## Preserve hard invariants

- Wallet balances are non-negative integers.
- The transactions table is append-only audit history; wallets.balance is a rebuildable cache.
- Every money mutation writes the ledger and cached balance atomically.
- Idempotency keys prevent duplicate economic effects.
- Resource ownership is enforced in database predicates, not inferred from client input.
- Raw authentication tokens never enter the database; only their SHA-256 hashes are stored.
- The application role must not gain DDL, ownership, cross-schema, DROP, or TRUNCATE privileges.

## Migration workflow

1. Inspect all earlier migrations and the queries that consume the affected objects.
2. Add a new numerically ordered migration; never edit one that may already have run.
3. Prefer database constraints for truths that must survive every client and code path.
4. Plan compatibility between old code, new code, and migrated data when deployment is not atomic.
5. Separate large backfills from blocking schema changes and make progress restartable.
6. Update role grants when a migration creates new object kinds not covered by existing defaults.

The current migration runner wraps each file in a transaction. CREATE INDEX CONCURRENTLY cannot run inside that wrapper; adapt the runner explicitly before using it rather than inserting an invalid migration.

## Query and transaction review

- Parameterize all values; dynamic identifiers require an explicit allow-list.
- Select only needed columns and verify indexes against actual filter, join, and ordering patterns.
- Use EXPLAIN ANALYZE on representative data before asserting a performance improvement.
- Acquire row locks only inside a transaction and in a deterministic order.
- Keep external calls outside database transactions.
- Treat unique violations caused by idempotency as a defined replay path, not an opaque 500.
- Never emit a zero-delta ledger entry; it violates the ledger contract and database constraint.

## Verification

Apply the full migration sequence to a disposable PostgreSQL instance, rerun it to prove migration tracking, load seed data, and exercise representative reads and mutations through the application role. For economy changes, test insufficient funds, duplicate requests, simultaneous operations, rollback after failure, and reconciliation of wallet balances against the ledger.

For current optimization guidance, consult PostgreSQL documentation and the maintained Supabase Postgres best-practices skill; apply only rules supported by this schema and workload.
