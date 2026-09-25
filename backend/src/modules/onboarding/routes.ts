import type { FastifyInstance } from "fastify";

import { requireAuth, requireRole } from "../../auth/plugin.js";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { bodySchema } from "../../lib/schema.js";

interface OnboardingStatusRow {
  onboarding_step: number;
  onboarding_completed_at: Date | null;
  pet_name: string | null;
  fur_option_id: string | null;
}

interface CompleteStepBody {
  completedStep: 2 | 3 | 4;
}

function statusResponse(row: OnboardingStatusRow) {
  return {
    currentStep: row.onboarding_step,
    completed: row.onboarding_completed_at !== null,
    pet:
      row.pet_name === null
        ? null
        : {
            petName: row.pet_name,
            furOptionId: row.fur_option_id,
          },
  };
}

export async function onboardingRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/onboarding/status",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query<OnboardingStatusRow>(
        `SELECT cp.onboarding_step, cp.onboarding_completed_at,
                p.pet_name, p.fur_option_id
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

  app.put<{ Body: CompleteStepBody }>(
    "/onboarding/progress",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: bodySchema(
        { completedStep: { type: "integer", enum: [2, 3, 4] } },
        ["completedStep"],
      ),
    },
    async (req) => {
      return withTransaction(async (client) => {
        const stateRes = await client.query<{
          onboarding_step: number;
          onboarding_completed_at: Date | null;
        }>(
          `SELECT onboarding_step, onboarding_completed_at
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

        const completedStep = req.body.completedStep;
        if (completedStep > state.onboarding_step) {
          throw new HttpError(409, "onboarding_step_out_of_order", {
            currentStep: state.onboarding_step,
          });
        }

        // A retry or a return to an earlier screen must be harmless and must
        // never move persistent progress backwards.
        if (completedStep < state.onboarding_step) {
          return { currentStep: state.onboarding_step, completed: false };
        }

        if (completedStep === 4) {
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
