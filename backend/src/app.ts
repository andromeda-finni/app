import Fastify from "fastify";
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

/**
 * The migration this build's SQL assumes. `/health` refuses to report ready
 * until it is present, so a process started against an un-migrated or
 * half-migrated database fails its readiness probe instead of accepting
 * traffic and then 500ing on the first query that hits a missing column.
 * Bump this whenever a migration the code depends on is added.
 */
const REQUIRED_SCHEMA_VERSION = "0022_generic_pet_copy.sql";

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
