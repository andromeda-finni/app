import type { FastifyInstance } from "fastify";
import { readDailyQuests } from "../quests/daily.js";

import { requireAuth, requireRole } from "../../auth/plugin.js";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { bodySchema, nonNegativeIntSchema } from "../../lib/schema.js";
import {
  isValidTutorialPlan,
  openTutorialDay,
  TUTORIAL_INCOME,
  type TutorialPlan,
} from "../periods/tutorialDay.js";

interface OnboardingStatusRow {
  difficulty: "SIMPLE" | "ADVANCED";
  onboarding_step: number;
  onboarding_completed_at: Date | null;
  home_tour_completed_at: Date | null;
  pet_name: string | null;
  fur_option_id: string | null;
  tutorial_need_amount: number | null;
  tutorial_want_amount: number | null;
  tutorial_savings_amount: number | null;
  accessory_option_id: string | null;
}

interface CompleteStepBody {
  completedStep: 2 | 3 | 4;
  /** Required with step 3: the tutorial split that becomes the first day's plan. */
  tutorialPlan?: TutorialPlan;
}

const tutorialAmountSchema = {
  ...nonNegativeIntSchema,
  maximum: TUTORIAL_INCOME,
} as const;

function statusResponse(row: OnboardingStatusRow) {
  return {
    difficulty: row.difficulty,
    currentStep: row.onboarding_step,
    completed: row.onboarding_completed_at !== null,
    homeTourCompleted: row.home_tour_completed_at !== null,
    pet:
      row.pet_name === null
        ? null
        : {
            petName: row.pet_name,
            furOptionId: row.fur_option_id,
            accessoryOptionId: row.accessory_option_id,
          },
    tutorialPlan:
      row.tutorial_need_amount === null
        ? null
        : {
            needAmount: row.tutorial_need_amount,
            wantAmount: row.tutorial_want_amount,
            savingsAmount: row.tutorial_savings_amount,
          },
  };
}

export async function onboardingRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/onboarding/status",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query<OnboardingStatusRow>(
        `SELECT cp.difficulty, cp.onboarding_step, cp.onboarding_completed_at,
                cp.home_tour_completed_at, cp.tutorial_need_amount,
                cp.tutorial_want_amount, cp.tutorial_savings_amount,
                p.pet_name, p.fur_option_id, p.accessory_option_id
           FROM child_profiles cp
           LEFT JOIN pets p ON p.child_user_id = cp.user_id
          WHERE cp.user_id = $1`,
        [req.authUser!.id],
      );
      const row = res.rows[0];
      if (!row) throw new HttpError(404, "child_profile_not_found");
      return statusResponse(row);
    },
  );

  app.put(
    "/onboarding/home-tour",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: bodySchema({}, []),
    },
    async (req) => {
      const result = await pool.query(
        `UPDATE child_profiles
            SET home_tour_completed_at = COALESCE(home_tour_completed_at, now()),
                updated_at = CASE
                  WHEN home_tour_completed_at IS NULL THEN now()
                  ELSE updated_at
                END
          WHERE user_id = $1`,
        [req.authUser!.id],
      );
      if (result.rowCount === 0) {
        throw new HttpError(404, "child_profile_not_found");
      }
      return { homeTourCompleted: true };
    },
  );

  app.put<{ Body: CompleteStepBody }>(
    "/onboarding/progress",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: bodySchema(
        {
          completedStep: { type: "integer", enum: [2, 3, 4] },
          tutorialPlan: {
            type: "object",
            additionalProperties: false,
            properties: {
              needAmount: tutorialAmountSchema,
              wantAmount: tutorialAmountSchema,
              savingsAmount: tutorialAmountSchema,
            },
            required: ["needAmount", "wantAmount", "savingsAmount"],
          },
        },
        ["completedStep"],
      ),
    },
    async (req) => {
      const { completedStep, tutorialPlan } = req.body;
      if (completedStep === 3) {
        if (!tutorialPlan) throw new HttpError(400, "tutorial_plan_required");
        if (!isValidTutorialPlan(tutorialPlan)) {
          throw new HttpError(400, "tutorial_plan_must_allocate_all_coins");
        }
      }

      return withTransaction(async (client) => {
        const stateRes = await client.query<{
          onboarding_step: number;
          onboarding_completed_at: Date | null;
          mode: "STANDARD" | "DEMO";
          tutorial_need_amount: number | null;
          tutorial_want_amount: number | null;
          tutorial_savings_amount: number | null;
        }>(
          `SELECT onboarding_step, onboarding_completed_at, mode,
                  tutorial_need_amount, tutorial_want_amount, tutorial_savings_amount
             FROM child_profiles
            WHERE user_id = $1
            FOR UPDATE`,
          [req.authUser!.id],
        );
        const state = stateRes.rows[0];
        if (!state) throw new HttpError(404, "child_profile_not_found");

        if (state.onboarding_completed_at !== null) {
          return { currentStep: 4, completed: true };
        }

        if (completedStep > state.onboarding_step) {
          throw new HttpError(409, "onboarding_step_out_of_order", {
            currentStep: state.onboarding_step,
          });
        }

        // Re-submitting step 3 after going back from step 4 replaces the
        // split: the first day must use the plan the child finally chose.
        if (completedStep === 3) {
          await client.query(
            `UPDATE child_profiles
                SET tutorial_need_amount = $2, tutorial_want_amount = $3,
                    tutorial_savings_amount = $4, updated_at = now()
              WHERE user_id = $1`,
            [
              req.authUser!.id,
              tutorialPlan!.needAmount,
              tutorialPlan!.wantAmount,
              tutorialPlan!.savingsAmount,
            ],
          );
        }

        // A retry or a return to an earlier screen must be harmless and must
        // never move persistent progress backwards.
        if (completedStep < state.onboarding_step) {
          return { currentStep: state.onboarding_step, completed: false };
        }

        if (completedStep === 4) {
          // Profiles that passed step 3 before the split was stored keep the
          // old behaviour: their first day starts from the regular income.
          if (state.mode === "STANDARD" && state.tutorial_need_amount !== null) {
            await openTutorialDay(client, req.authUser!.id, {
              needAmount: state.tutorial_need_amount,
              wantAmount: state.tutorial_want_amount!,
              savingsAmount: state.tutorial_savings_amount!,
            });
            await readDailyQuests(client, req.authUser!.id);
          }
          await client.query(
            `UPDATE child_profiles
                SET onboarding_completed_at = now(), updated_at = now()
              WHERE user_id = $1`,
            [req.authUser!.id],
          );
          return { currentStep: 4, completed: true };
        }

        const nextStep = completedStep + 1;
        await client.query(
          `UPDATE child_profiles
              SET onboarding_step = $2, updated_at = now()
            WHERE user_id = $1`,
          [req.authUser!.id, nextStep],
        );
        return { currentStep: nextStep, completed: false };
      });
    },
  );
}
