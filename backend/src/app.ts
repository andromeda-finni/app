import Fastify from "fastify";
import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import sensible from "@fastify/sensible";
import { HttpError } from "./lib/errors.js";
import { pool } from "./lib/db.js";
import { authRoutes } from "./auth/routes.js";
import { petRoutes } from "./modules/pet/routes.js";
import { walletRoutes } from "./modules/wallet/routes.js";
import { shopRoutes } from "./modules/shop/routes.js";
import { periodRoutes } from "./modules/periods/routes.js";
import { questRoutes } from "./modules/quests/routes.js";
import { parentTaskRoutes } from "./modules/parentTasks/routes.js";
import { frostChestRoutes } from "./modules/frostChest/routes.js";
import { goalRoutes } from "./modules/goals/routes.js";
import { petEventRoutes } from "./modules/petEvents/routes.js";
import { scamOfferRoutes } from "./modules/scamOffers/routes.js";
import { passportRoutes } from "./modules/passport/routes.js";
import { parentViewRoutes } from "./modules/parentView/routes.js";
import { onboardingRoutes } from "./modules/onboarding/routes.js";
import { economyRoutes } from "./modules/economy/routes.js";
import { insuranceRoutes } from "./modules/insurance/routes.js";
import { inventoryRoutes } from "./modules/inventory/routes.js";
import { childSettingsRoutes } from "./modules/childSettings/routes.js";
import { parkProjectRoutes } from "./modules/parkProject/routes.js";

/**
 * The migrations this build's SQL assumes. `/health` refuses to report ready
 * until every one is present, so a process started against an un-migrated or
 * half-migrated database fails its readiness probe instead of accepting
 * traffic and then 500ing on the first query that hits a missing column.
 *
 * It is a list because parallel branches added migrations with the same
 * numeric prefix; the newest file name alone no longer proves the other line
 * of migrations ran. Add an entry whenever the code starts depending on one.
 */
const REQUIRED_SCHEMA_VERSIONS = [
  "0027_artifact_durability.sql",
  "0029_child_display_settings.sql",
  "0032_park_project.sql",
] as const;

const LOOPBACK_ORIGIN_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]"]);

/**
 * CORS_ORIGINS is a comma-separated allow-list for deployed web builds. When
 * unset, only loopback origins are allowed, because `flutter run -d chrome`
 * serves the app from localhost on a random port.
 */
export function corsOriginPolicy(configured: string | undefined) {
  const allowList = (configured ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
  return (origin: string | undefined, callback: (err: Error | null, allow: boolean) => void) => {
    // Native apps and curl send no Origin header; CORS does not apply to them.
    if (!origin) return callback(null, true);
    if (allowList.length > 0) return callback(null, allowList.includes(origin));
    try {
      return callback(null, LOOPBACK_ORIGIN_HOSTS.has(new URL(origin).hostname));
    } catch {
      return callback(null, false);
    }
  };
}

export async function buildApp() {
  const app = Fastify({
    logger: true,
    ajv: {
      customOptions: {
        // Fastify defaults this to true, which makes `additionalProperties:
        // false` silently DELETE unknown fields and run the handler anyway.
        // A request carrying a field the server doesn't understand is a
        // client/server contract mismatch — reject it with a 400 rather than
        // quietly acting on a different request than the one that was sent.
        removeAdditional: false,
      },
    },
  });

  // Only browsers enforce CORS, so this only matters for the Flutter web build.
  // `origin: true` with credentials would let any site script this API; the
  // app authenticates with a bearer header rather than cookies, so credentials
  // stay off and origins come from an explicit allow-list.
  await app.register(cors, {
    origin: corsOriginPolicy(process.env["CORS_ORIGINS"]),
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allowedHeaders: ["Content-Type", "Authorization"],
    credentials: false,
  });
  await app.register(helmet);
  await app.register(sensible);
  await app.register(rateLimit, {
    max: 120,
    timeWindow: "1 minute",
  });

  app.setErrorHandler((err, _req, reply) => {
    if (err instanceof HttpError) {
      reply.code(err.statusCode).send({ error: err.code, details: err.details });
      return;
    }
    // Fastify validation errors already carry a statusCode.
    const withStatus = err as { statusCode?: number; message?: string };
    if (withStatus.statusCode) {
      reply.code(withStatus.statusCode).send({ error: withStatus.message ?? "request_error" });
      return;
    }
    app.log.error(err);
    reply.code(500).send({ error: "internal_server_error" });
  });

  // Readiness, not liveness: reachable-but-unmigrated is still not servable,
  // so a bare `SELECT 1` (which succeeds against a completely empty schema)
  // isn't enough to answer "can this process serve requests?".
  app.get("/health", async (_req, reply) => {
    let applied: string | null;
    let missing: string[];
    try {
      const res = await pool.query<{ missing: string[]; latest: string | null }>(
        `SELECT ARRAY(
                  SELECT required FROM unnest($1::text[]) AS required
                   WHERE NOT EXISTS (SELECT 1 FROM schema_migrations WHERE version = required)
                ) AS missing,
                (SELECT MAX(version) FROM schema_migrations) AS latest`,
        [REQUIRED_SCHEMA_VERSIONS],
      );
      missing = res.rows[0]!.missing;
      applied = res.rows[0]!.latest;
    } catch (err) {
      app.log.error(err, "health check: database unreachable or schema_migrations missing");
      reply.code(503);
      return { ok: false, error: "database_unreachable" };
    }

    if (missing.length > 0) {
      app.log.error(
        { missing, applied },
        "health check: database schema is behind the versions this build requires",
      );
      reply.code(503);
      return {
        ok: false,
        error: "schema_out_of_date",
        missing,
        applied,
      };
    }

    return { ok: true, schemaVersion: applied };
  });

  await app.register(authRoutes);
  await app.register(onboardingRoutes);
  await app.register(economyRoutes);
  await app.register(insuranceRoutes);
  await app.register(childSettingsRoutes);
  await app.register(petRoutes);
  await app.register(walletRoutes);
  await app.register(shopRoutes);
  await app.register(periodRoutes);
  await app.register(questRoutes);
  await app.register(parkProjectRoutes);
  await app.register(parentTaskRoutes);
  await app.register(frostChestRoutes);
  await app.register(goalRoutes);
  await app.register(inventoryRoutes);
  await app.register(petEventRoutes);
  await app.register(scamOfferRoutes);
  await app.register(passportRoutes);
  await app.register(parentViewRoutes);

  return app;
}
