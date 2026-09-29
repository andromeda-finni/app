import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { bodySchema, paramsSchema, shortIdSchema, uuidSchema } from "../../lib/schema.js";
import { useArtifact } from "../../lib/artifacts.js";
import { ECONOMY_RULES } from "../economy/rules.js";

interface UiSpec {
  correctOptionCode?: string;
  answerValidation?: {
    kind?: string;
    expectedSequence?: string[];
    acceptedOptions?: string[];
    budget?: number;
    itemPrices?: Record<string, number>;
  };
  [key: string]: unknown;
}

function answerMatches(uiSpec: UiSpec | null, selectedOptionCode?: string): boolean {
  const validation = uiSpec?.answerValidation;
  if (validation?.kind === "ORDERED_SEQUENCE") {
    const expected = validation.expectedSequence;
    if (!expected?.length || !selectedOptionCode) return false;
    return selectedOptionCode === expected.join(",");
  }

  if (validation?.kind === "BUDGET_SELECTION") {
    const budget = validation.budget;
    const itemPrices = validation.itemPrices;
    if (!Number.isInteger(budget) || (budget ?? 0) < 0 || !itemPrices || !selectedOptionCode) {
      return false;
    }
    const selectedIds = selectedOptionCode.split(",").filter(Boolean);
    if (selectedIds.length === 0 || new Set(selectedIds).size !== selectedIds.length) {
      return false;
    }
    let total = 0;
    for (const itemId of selectedIds) {
      const price = itemPrices[itemId];
      if (!Number.isInteger(price) || (price ?? -1) < 0) return false;
      total += price!;
    }
    return total <= budget!;
  }

  if (validation?.kind === "ONE_OF") {
    const accepted = validation.acceptedOptions;
    return Boolean(
      selectedOptionCode &&
      accepted?.length &&
      accepted.includes(selectedOptionCode),
    );
  }

  return typeof uiSpec?.correctOptionCode === "string" &&
    uiSpec.correctOptionCode === selectedOptionCode;
}

export async function questRoutes(app: FastifyInstance): Promise<void> {
  // Difficulty controls the amount of guidance inside a game. The story/map
  // catalogue is shared: filtering SIMPLE quest definitions out for an
  // ADVANCED child would leave the map empty rather than make play harder.
  app.get(
    "/quests",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      // The daily paid-quest limit (3, or 4 with boots) is enforced when a
      // reward is paid, not by hiding catalogue entries.
      const perksRes = await pool.query<{ boots_active: boolean; saucer_active: boolean }>(
        `SELECT
           EXISTS (
             SELECT 1 FROM inventory_items i
             JOIN pets p ON p.child_user_id = i.child_user_id
                          AND p.equipped_inventory_item_id = i.id
             WHERE i.child_user_id = $1 AND i.item_id = 'boots'
               AND NOT i.is_broken AND i.durability_current > 0
           ) AS boots_active,
           EXISTS (
             SELECT 1 FROM inventory_items i
             WHERE i.child_user_id = $1 AND i.item_id = 'saucer'
               AND NOT i.is_broken AND i.durability_current > 0
           ) AS saucer_active`,
        [req.authUser!.id],
      );
      const perks = perksRes.rows[0];
      const res = await pool.query(
        `SELECT id, topic_id, title, character_code, location_code, difficulty, reward_amount
           FROM quest_definitions
          WHERE active
          ORDER BY id`,
      );
      return res.rows.map((quest) => ({
        ...quest,
        forecast: perks?.saucer_active
          ? { rewardAmount: quest.reward_amount, energyCost: null }
          : null,
      }));
    },
  );

  app.post<{ Params: { questId: string } }>(
    "/quests/:questId/start",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: paramsSchema({ questId: shortIdSchema }, ["questId"]),
    },
    async (req, reply) => {
      const childUserId = req.authUser!.id;
      const { questId } = req.params;

      const result = await withTransaction(async (client) => {
        // Serialise starts for one child. Besides making two concurrent starts
        // naturally converge on the same assignment, this gives prerequisite
        // and active-day checks one stable view of that child's progression.
        const childRes = await client.query<{ difficulty: string }>(
          `SELECT difficulty FROM child_profiles WHERE user_id = $1 FOR UPDATE`,
          [childUserId],
        );
        const child = childRes.rows[0];
        if (!child) throw new HttpError(404, "child_profile_not_found");

        const questRes = await client.query<{ reward_amount: number }>(
          `SELECT CASE
                    WHEN $2 = 'ADVANCED'
                    THEN COALESCE(advanced_reward_amount, reward_amount)
                    ELSE reward_amount
                  END AS reward_amount
             FROM quest_definitions
            WHERE id = $1 AND active`,
          [questId, child.difficulty],
        );
        const quest = questRes.rows[0];
        if (!quest) throw new HttpError(404, "quest_not_found");

        const blockedRes = await client.query<{ prerequisite_quest_id: string }>(
          `SELECT qp.prerequisite_quest_id
             FROM quest_prerequisites qp
            WHERE qp.quest_id = $1
              AND NOT EXISTS (
                SELECT 1 FROM assignments a
                 WHERE a.child_user_id = $2
                   AND a.origin = 'SYSTEM'
                   AND a.quest_id = qp.prerequisite_quest_id
                   AND a.status = 'COMPLETED'
              )
            ORDER BY qp.prerequisite_quest_id`,
          [questId, childUserId],
        );
        if (blockedRes.rowCount) {
          throw new HttpError(409, "quest_prerequisite_not_completed", {
            prerequisiteQuestIds: blockedRes.rows.map((row) => row.prerequisite_quest_id),
          });
        }

        const periodRes = await client.query<{ id: string }>(
          `SELECT gp.id FROM game_periods gp
            JOIN budget_plans bp ON bp.period_id = gp.id AND bp.status = 'CONFIRMED'
           WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE'`,
          [childUserId],
        );
        const period = periodRes.rows[0];
        if (!period) throw new HttpError(409, "active_day_with_confirmed_plan_required");

        // An unfinished run is resumed rather than refused: a child who left a
        // game halfway must still be able to finish it and earn the reward.
        // Only a completed quest is closed for good.
        const existingRes = await client.query<{
          id: string;
          status: string;
          reward_amount: number;
          next_step_no: number;
          balance_after: number | null;
        }>(
          `SELECT a.id, a.status, a.reward_amount,
                  COALESCE((
                    SELECT MAX(qsp.step_no) + 1
                      FROM quest_step_progress qsp
                     WHERE qsp.assignment_id = a.id AND qsp.outcome = 'SUCCESS'
                  ), 1)::int AS next_step_no,
                  reward_txn.balance_after
             FROM assignments a
             LEFT JOIN transactions reward_txn ON reward_txn.id = a.reward_transaction_id
            WHERE a.child_user_id = $1 AND a.quest_id = $2 AND a.origin = 'SYSTEM'
              AND a.status IN ('IN_PROGRESS', 'COMPLETED')
            ORDER BY a.created_at DESC LIMIT 1`,
          [childUserId, questId],
        );
        const existing = existingRes.rows[0];
        if (existing?.status === "COMPLETED") {
          return {
            assignmentId: existing.id,
            rewardAmount: existing.reward_amount,
            balanceAfter: existing.balance_after,
            resumed: false,
            completed: true,
            rewardAlreadyGranted: true,
            nextStepNo: existing.next_step_no,
          };
        }
        if (existing) {
          return {
            assignmentId: existing.id,
            rewardAmount: existing.reward_amount,
            resumed: true,
            nextStepNo: existing.next_step_no,
          };
        }

        const res = await client.query<{ id: string }>(
          `INSERT INTO assignments (child_user_id, period_id, origin, quest_id, reward_amount, status)
           VALUES ($1, $2, 'SYSTEM', $3, $4, 'IN_PROGRESS') RETURNING id`,
          [childUserId, period.id, questId, quest.reward_amount],
        );
        return {
          assignmentId: res.rows[0]!.id,
          rewardAmount: quest.reward_amount,
          resumed: false,
          nextStepNo: 1,
        };
      });

      reply.code(result.resumed || result.completed ? 200 : 201).send(result);
    },
  );

  app.get<{ Params: { assignmentId: string; stepNo: string } }>(
    "/assignments/:assignmentId/steps/:stepNo",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: paramsSchema(
        { assignmentId: uuidSchema, stepNo: { type: "string", pattern: "^[1-9][0-9]*$" } },
        ["assignmentId", "stepNo"],
      ),
    },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { assignmentId, stepNo } = req.params;

      const res = await pool.query<{
        instruction: string;
        expected_action_code: string;
        ui_spec: UiSpec | null;
      }>(
        `SELECT qs.instruction, qs.expected_action_code, qs.ui_spec
           FROM assignments a
           JOIN quest_steps qs ON qs.quest_id = a.quest_id AND qs.step_no = $3
          WHERE a.id = $1 AND a.child_user_id = $2 AND a.origin = 'SYSTEM'`,
        [assignmentId, childUserId, Number(stepNo)],
      );
      const step = res.rows[0];
      if (!step) throw new HttpError(404, "step_not_found");

      // Never leak the correct answer to the client.
      const {
        correctOptionCode: _omitAnswer,
        answerValidation: _omitValidation,
        ...safeUiSpec
      } = step.ui_spec ?? {};
      return { ...step, ui_spec: safeUiSpec };
    },
  );

  app.post<{
    Params: { assignmentId: string };
    Body: { stepNo: number; selectedOptionCode?: string };
  }>(
    "/assignments/:assignmentId/answer",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: {
        ...paramsSchema({ assignmentId: uuidSchema }, ["assignmentId"]),
        ...bodySchema(
          {
            stepNo: { type: "integer", minimum: 1 },
            selectedOptionCode: { type: "string", minLength: 1, maxLength: 80 },
          },
          ["stepNo"],
        ),
      },
    },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { assignmentId } = req.params;
      const { stepNo, selectedOptionCode } = req.body;

      return withTransaction(async (client) => {
        const assignmentRes = await client.query<{
          quest_id: string;
          reward_amount: number;
          status: string;
          balance_after: number | null;
        }>(
          `SELECT a.quest_id, a.reward_amount, a.status, reward_txn.balance_after
             FROM assignments a
             LEFT JOIN transactions reward_txn ON reward_txn.id = a.reward_transaction_id
            WHERE a.id = $1 AND a.child_user_id = $2 AND a.origin = 'SYSTEM'
            FOR UPDATE OF a`,
          [assignmentId, childUserId],
        );
        const assignment = assignmentRes.rows[0];
        if (!assignment) throw new HttpError(404, "assignment_not_found");
        // The transaction may have committed while its HTTP response was lost.
        // Replaying the final answer must report the already-issued reward,
        // not turn a successful child experience into a false failure.
        if (assignment.status === "COMPLETED") {
          return {
            outcome: "SUCCESS" as const,
            feedback: "Результат уже сохранён.",
            questCompleted: true,
            rewardAmount: assignment.reward_amount,
            balanceAfter: assignment.balance_after,
            rewardAlreadyGranted: true,
            replayed: true,
          };
        }
        if (assignment.status !== "IN_PROGRESS") {
          throw new HttpError(409, "assignment_not_in_progress");
        }

        // Steps must be answered in order: stepNo can only be attempted once
        // every earlier step already has a recorded SUCCESS.
        if (stepNo > 1) {
          const priorRes = await client.query<{ count: string }>(
            `SELECT COUNT(*) FROM quest_step_progress
              WHERE assignment_id = $1 AND step_no < $2 AND outcome = 'SUCCESS'`,
            [assignmentId, stepNo],
          );
          if (Number(priorRes.rows[0]?.count ?? 0) < stepNo - 1) {
            throw new HttpError(409, "earlier_steps_not_completed");
          }
        }

        const stepRes = await client.query<{
          success_feedback: string;
          recovery_feedback: string;
          ui_spec: UiSpec | null;
        }>(
          `SELECT success_feedback, recovery_feedback, ui_spec
             FROM quest_steps WHERE quest_id = $1 AND step_no = $2`,
          [assignment.quest_id, stepNo],
        );
        const step = stepRes.rows[0];
        if (!step) throw new HttpError(404, "step_not_found");

        const previousRes = await client.query<{ outcome: string }>(
          `SELECT outcome FROM quest_step_progress
            WHERE assignment_id = $1 AND step_no = $2`,
          [assignmentId, stepNo],
        );
        const wasAlreadySuccessful = previousRes.rows[0]?.outcome === "SUCCESS";
        const outcome: "SUCCESS" | "RECOVERABLE_ERROR" =
          wasAlreadySuccessful || answerMatches(step.ui_spec, selectedOptionCode)
            ? "SUCCESS"
            : "RECOVERABLE_ERROR";

        await client.query(
          `INSERT INTO quest_step_progress (assignment_id, step_no, outcome, selected_option_code)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (assignment_id, step_no)
           DO UPDATE SET
             outcome = CASE
               WHEN quest_step_progress.outcome = 'SUCCESS' THEN quest_step_progress.outcome
               ELSE EXCLUDED.outcome
             END,
             selected_option_code = CASE
               WHEN quest_step_progress.outcome = 'SUCCESS' THEN quest_step_progress.selected_option_code
               ELSE EXCLUDED.selected_option_code
             END,
             completed_at = CASE
               WHEN quest_step_progress.outcome = 'SUCCESS' THEN quest_step_progress.completed_at
               ELSE now()
             END`,
          [assignmentId, stepNo, outcome, selectedOptionCode ?? null],
        );

        if (outcome === "RECOVERABLE_ERROR") {
          return { outcome, feedback: step.recovery_feedback, questCompleted: false };
        }

        const maxStepRes = await client.query<{ max_step: number }>(
          `SELECT MAX(step_no) AS max_step FROM quest_steps WHERE quest_id = $1`,
          [assignment.quest_id],
        );
        const isLastStep = stepNo >= (maxStepRes.rows[0]?.max_step ?? stepNo);

        if (!isLastStep) {
          return { outcome, feedback: step.success_feedback, questCompleted: false };
        }

        if (!(ECONOMY_RULES.questRewards as readonly number[]).includes(assignment.reward_amount)) {
          throw new HttpError(409, "quest_reward_is_not_an_economy_value");
        }

        // Every quest completion for the day locks the same period row before
        // counting paid assignments. Different assignments can otherwise all
        // observe the old count and collectively exceed the daily limit.
        const periodRes = await client.query<{ id: string }>(
          `SELECT gp.id FROM game_periods gp
            JOIN budget_plans bp ON bp.period_id = gp.id AND bp.status = 'CONFIRMED'
           WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE'
           FOR UPDATE OF gp`,
          [childUserId],
        );
        const period = periodRes.rows[0];
        if (!period) throw new HttpError(409, "active_day_with_confirmed_plan_required");

        const bootsRes = await client.query(
          `SELECT 1 FROM pets p
            JOIN inventory_items i ON i.id = p.equipped_inventory_item_id
           WHERE p.child_user_id = $1 AND i.item_id = 'boots'
             AND NOT i.is_broken AND i.durability_current > 0`,
          [childUserId],
        );
        const dailyLimit = (bootsRes.rowCount ?? 0) > 0
          ? ECONOMY_RULES.bootsQuestLimit
          : ECONOMY_RULES.dailyQuestLimit;
        const paidRes = await client.query<{ paid: string }>(
          `SELECT COUNT(*) AS paid FROM assignments
            WHERE child_user_id = $1 AND origin = 'SYSTEM'
              AND period_id = $2 AND status = 'COMPLETED'`,
          [childUserId, period.id],
        );
        if (Number(paidRes.rows[0]?.paid ?? 0) >= dailyLimit) {
          throw new HttpError(409, "daily_quest_reward_limit_reached", {
            limit: dailyLimit,
          });
        }

        const txn = await postTransaction(client, {
          childUserId,
          walletKind: "SPENDABLE",
          eventType: "QUEST_REWARD",
          deltaAmount: assignment.reward_amount,
          referenceType: "assignment",
          referenceId: assignmentId,
          idempotencyKey: `quest-reward:${assignmentId}`,
        });

        await client.query(
          `UPDATE assignments
              SET status = 'COMPLETED', reward_transaction_id = $1,
                  period_id = $2, updated_at = now()
            WHERE id = $3`,
          [txn.id, period.id, assignmentId],
        );

        const bootsEffect = await useArtifact(client, {
          childUserId,
          itemId: "boots",
          effectCode: "QUEST_PATH",
          durabilityCost: 5,
          referenceType: "assignment",
          referenceId: assignmentId,
          equippedOnly: true,
        });

        return {
          outcome,
          feedback: step.success_feedback,
          questCompleted: true,
          rewardAmount: assignment.reward_amount,
          balanceAfter: txn.balanceAfter,
          artifactEffects: bootsEffect ? [bootsEffect] : [],
        };
      });
    },
  );
}
