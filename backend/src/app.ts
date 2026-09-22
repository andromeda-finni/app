import Fastify from "fastify";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import sensible from "@fastify/sensible";
import { HttpError } from "./lib/errors.js";
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

export async function buildApp() {
  const app = Fastify({
    logger: true,
    // No X-Powered-By-style fingerprinting, trims default error verbosity.
    disableRequestLogging: false,
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

  app.get("/health", async () => ({ ok: true }));

  await app.register(authRoutes);
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
