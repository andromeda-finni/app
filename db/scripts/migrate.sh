#!/usr/bin/env bash
# Applies db/migrations/*.sql in order, tracking progress in schema_migrations
# so re-running is safe. Requires DATABASE_URL (admin/owner role) and
# GROSHIK_APP_PASSWORD (password to (re)assign to the least-privilege app role).
set -euo pipefail

: "${DATABASE_URL:?Set DATABASE_URL, e.g. postgres://groshik_admin:pass@localhost:5432/groshik}"
: "${GROSHIK_APP_PASSWORD:?Set GROSHIK_APP_PASSWORD for the groshik_app role}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_DIR="$SCRIPT_DIR/../migrations"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$MIGRATIONS_DIR/0000_migrations_table.sql"

for file in "$MIGRATIONS_DIR"/*.sql; do
  version="$(basename "$file")"
  [ "$version" = "0000_migrations_table.sql" ] && continue

  already_applied="$(psql "$DATABASE_URL" -tAc "SELECT 1 FROM schema_migrations WHERE version = '$version'")"
  if [ "$already_applied" = "1" ]; then
    echo "skip  $version (already applied)"
    continue
  fi

  echo "apply $version"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v groshik_app_password="$GROSHIK_APP_PASSWORD" <<SQL
BEGIN;
\i $file
INSERT INTO schema_migrations (version) VALUES ('$version');
COMMIT;
SQL
done

echo "done"
