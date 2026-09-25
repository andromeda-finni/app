const LOOPBACK_HOSTS = new Set(["localhost", "127.0.0.1", "::1", "[::1]"]);

/**
 * Validates the database transport policy before pg creates a pool.
 *
 * pg currently treats sslmode=prefer as verify-full unless a compatibility
 * flag is supplied, while libpq treats it as "try TLS, then fall back". That
 * ambiguity caused local Docker startup to fail after a dependency update.
 * Requiring an explicit mode keeps local and deployed behavior deterministic.
 */
export function validateAppDatabaseUrl(connectionString: string): string {
  let url: URL;
  try {
    url = new URL(connectionString);
  } catch {
    throw new Error("APP_DATABASE_URL must be a valid PostgreSQL URL");
  }

  if (url.protocol !== "postgres:" && url.protocol !== "postgresql:") {
    throw new Error("APP_DATABASE_URL must use the postgres or postgresql protocol");
  }
  if (!url.username || !url.password || !url.hostname || url.pathname.length <= 1) {
    throw new Error("APP_DATABASE_URL must include username, password, host, and database name");
  }

  const sslMode = url.searchParams.get("sslmode");
  if (LOOPBACK_HOSTS.has(url.hostname)) {
    if (sslMode !== "disable") {
      throw new Error(
        "Local APP_DATABASE_URL must use sslmode=disable because the loopback-only Docker PostgreSQL instance does not provide TLS",
      );
    }
  } else if (sslMode !== "verify-full") {
    throw new Error(
      "Non-local APP_DATABASE_URL must use sslmode=verify-full and a trusted CA certificate",
    );
  }

  return connectionString;
}
