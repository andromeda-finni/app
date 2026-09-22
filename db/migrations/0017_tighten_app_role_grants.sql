-- 0011 granted groshik_app blanket SELECT/INSERT/UPDATE/DELETE on every
-- table. In reality: no route ever issues a DELETE against anything, and
-- most tables (append-only ledgers, content catalogs, migration tracking)
-- are never UPDATEd either — only 11 tables have status/state columns the
-- app actually mutates in place. Tighten to exactly what backend/src issues.

REVOKE UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM groshik_app;

-- Tables the app updates in place (state machines: status columns, wallet
-- balances, pet stats, invite redemption, credential bookkeeping).
GRANT UPDATE ON
    assignments,
    auth_credentials,
    budget_plans,
    financial_goals,
    frost_chests,
    game_periods,
    parent_child_links,
    pet_event_occurrences,
    pets,
    scam_offer_occurrences,
    wallets
TO groshik_app;

-- schema_migrations is written only by db/scripts/migrate.sh running as the
-- admin/owner role, never by the application — the app needs no access at all.
REVOKE ALL ON schema_migrations FROM groshik_app;

-- New tables created by future migrations no longer default to UPDATE/DELETE;
-- a migration that adds a mutable table must GRANT UPDATE on it explicitly.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE UPDATE, DELETE ON TABLES FROM groshik_app;
