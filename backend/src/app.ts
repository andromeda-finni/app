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
import { onboardingRoutes } from "./modules/onboarding/routes.js";
import { economyRoutes } from "./modules/economy/routes.js";

/**
 * The migration this build's SQL assumes. `/health` refuses to report ready
 * until it is present, so a process started against an un-migrated or
 * half-migrated database fails its readiness probe instead of accepting
 * traffic and then 500ing on the first query that hits a missing column.
 * Bump this whenever a migration the code depends on is added.
 */
const REQUIRED_SCHEMA_VERSION = "0023_mole_minigame_content.sql";

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
    let required: boolean;
    try {
      const res = await pool.query<{ required_present: boolean; latest: string | null }>(
        `SELECT EXISTS (SELECT 1 FROM schema_migrations WHERE version = $1) AS required_present,
                MAX(version) AS latest
           FROM schema_migrations`,
        [REQUIRED_SCHEMA_VERSION],
      );
      required = res.rows[0]!.required_present;
      applied = res.rows[0]!.latest;
    } catch (err) {
      app.log.error(err, "health check: database unreachable or schema_migrations missing");
      reply.code(503);
      return { ok: false, error: "database_unreachable" };
    }

    if (!required) {
      app.log.error(
        { required: REQUIRED_SCHEMA_VERSION, applied },
        "health check: database schema is behind the version this build requires",
      );
      reply.code(503);
      return {
        ok: false,
        error: "schema_out_of_date",
        required: REQUIRED_SCHEMA_VERSION,
        applied,
      };
    }

    return { ok: true, schemaVersion: applied };
  });

  await app.register(authRoutes);
  await app.register(onboardingRoutes);
  await app.register(economyRoutes);
  await app.register(petRoutes);
  await app.register(walletRoutes);
  await app.register(shopRoutes);
  await app.register(periodRoutes);
  await app.register(questRoutes);
  await app.register(parentTaskRoutes);
  await app.register(frostChestRoutes);
  await app.register(goalRoutes);
  await app.register(petEventRoutes);
  await app.register(scamOfferRoutes);
  await app.register(passportRoutes);

  return app;
}
