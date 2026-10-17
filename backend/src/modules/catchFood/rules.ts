import { HttpError } from "../../lib/errors.js";
import { ACTIVITY_ENERGY_COST } from "../pet/energy.js";

// First balancing pass: reuse the existing activity cost and recovery model.
// Food is a score token; this game never awards food, coins or quest rewards.
export const CATCH_FOOD_RULES = Object.freeze({
  energyCost: ACTIVITY_ENERGY_COST,
  durationMs: 60_000,
  maxMisses: 3,
  travelMs: 2_400,
  firstSpawnMs: 600,
  initialSpawnMs: 1_300,
  minimumSpawnMs: 700,
  catchWindowMs: 180,
  spoiledFoodPercent: 20,
});

export type FinishReason = "MISSES" | "TIRED" | "STOPPED";
export interface CatchFoodResult {
  score: number;
  misses: number;
  elapsedMs: number;
  reason: FinishReason;
}

export function validateCatchFoodResult(result: CatchFoodResult, wallTimeMs: number): void {
  const rules = CATCH_FOOD_RULES;
  const firstCatchMs = rules.firstSpawnMs + rules.travelMs;
  const possibleScore = result.elapsedMs < firstCatchMs
    ? 0
    : 1 + Math.floor((result.elapsedMs - firstCatchMs) / rules.minimumSpawnMs);
  if (!Number.isInteger(result.score) || result.score < 0 || result.score + result.misses > possibleScore
    || !Number.isInteger(result.misses) || result.misses < 0 || result.misses > rules.maxMisses
    || !Number.isInteger(result.elapsedMs) || result.elapsedMs < 0 || result.elapsedMs > rules.durationMs
    || result.elapsedMs > wallTimeMs + 1_500
    || !["MISSES", "TIRED", "STOPPED"].includes(result.reason)
    || (result.reason === "MISSES" && result.misses !== rules.maxMisses)
    || (result.reason === "TIRED" && result.elapsedMs !== rules.durationMs)) {
    throw new HttpError(400, "invalid_catch_food_result");
  }
}
