-- Least-privilege application role. Migrations run as the DB owner/admin role;
-- the backend connects ONLY as groshik_app, which cannot CREATE/DROP/ALTER
-- anything, cannot touch other schemas, and has no superuser bit. This limits
-- blast radius if a query were ever compromised (e.g. injection attempt).
SELECT 'CREATE ROLE groshik_app LOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'groshik_app')
\gexec

ALTER ROLE groshik_app WITH PASSWORD :'groshik_app_password';

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO groshik_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO groshik_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO groshik_app;

-- No sequence/DDL/ownership rights, no DROP/TRUNCATE, no access to other roles' objects.
REVOKE CREATE ON SCHEMA public FROM groshik_app;
