import type { FastifyInstance } from "fastify";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { bodySchema, paramsSchema, uuidSchema } from "../../lib/schema.js";
import { presentPet, recoverPetEnergy } from "../pet/energy.js";
import { CATCH_FOOD_RULES, type CatchFoodResult } from "./rules.js";
import { catchFoodBest, finishCatchFood, startCatchFood } from "./service.js";

export async function catchFoodRoutes(app: FastifyInstance): Promise<void> {
  const preHandler = [requireAuth, requireRole("CHILD")];
  app.get("/minigames/catch-food", { preHandler }, async (req) => {
    const childId = req.authUser!.id;
    const pet = await recoverPetEnergy(pool, childId);
    if (!pet) throw new HttpError(404, "pet_not_created");
    return { config: CATCH_FOOD_RULES, pet: presentPet(pet), bestScore: await catchFoodBest(pool, childId) };
  });
  app.post<{ Body: { sessionId: string } }>("/minigames/catch-food/start", {
    preHandler, schema: bodySchema({ sessionId: uuidSchema }, ["sessionId"]),
  }, async (req) => withTransaction((client) => startCatchFood(client, req.authUser!.id, req.body.sessionId)));
  app.post<{ Params: { sessionId: string }; Body: CatchFoodResult }>(
    "/minigames/catch-food/:sessionId/finish", {
      preHandler,
      schema: {
        ...paramsSchema({ sessionId: uuidSchema }, ["sessionId"]),
        ...bodySchema({
          score: { type: "integer", minimum: 0, maximum: 1_000 },
          misses: { type: "integer", minimum: 0, maximum: CATCH_FOOD_RULES.maxMisses },
          elapsedMs: { type: "integer", minimum: 0, maximum: CATCH_FOOD_RULES.durationMs },
          reason: { type: "string", enum: ["MISSES", "TIRED", "STOPPED"] },
        }, ["score", "misses", "elapsedMs", "reason"]),
      },
    }, async (req) => withTransaction((client) => finishCatchFood(
      client, req.authUser!.id, req.params.sessionId, req.body,
    )),
  );
}
