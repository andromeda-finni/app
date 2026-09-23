import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { bodySchema, paramsSchema, shortIdSchema, uuidSchema } from "../../lib/schema.js";

interface UiSpec {
  correctOptionCode?: string;
  [key: string]: unknown;
}

export async function questRoutes(app: FastifyInstance): Promise<void> {
  // System quests told by the "Хитрый Лис" character, filtered to the
  // child's current difficulty (см. ML-adaptive difficulty note in db/README —
  // today this is a static filter; swapping in a model later only changes
  // how `difficulty` gets set on child_profiles, not this endpoint).
  app.get(
    "/quests",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const childRes = await pool.query<{ difficulty: string }>(
        `SELECT difficulty FROM child_profiles WHERE user_id = $1`,
        [req.authUser!.id],
      );
      const res = await pool.query(
        `SELECT id, topic_id, title, character_code, location_code, difficulty, reward_amount
           FROM quest_definitions
          WHERE active AND difficulty = $1
          ORDER BY id`,
        [childRes.rows[0]?.difficulty ?? "SIMPLE"],
      );
      return res.rows;
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

      const assignmentId = await withTransaction(async (client) => {
        const questRes = await client.query<{ reward_amount: number }>(
          `SELECT reward_amount FROM quest_definitions WHERE id = $1 AND active`,
          [questId],
        );
        const quest = questRes.rows[0];
        if (!quest) throw new HttpError(404, "quest_not_found");

        const periodRes = await client.query<{ id: string }>(
          `SELECT id FROM game_periods WHERE child_user_id = $1 AND status = 'ACTIVE'`,
          [childUserId],
        );

        // A quest already IN_PROGRESS or COMPLETED for this child can't be
        // started again — otherwise the reward could be farmed repeatedly.
        // The guard is the partial unique index from migration 0019 rather
        // than a preceding SELECT: two parallel starts both pass any check
        // written in application code, and only the database can serialize
        // them. 23505 here therefore means "someone already started it".
        try {
          const res = await client.query<{ id: string }>(
            `INSERT INTO assignments (child_user_id, period_id, origin, quest_id, reward_amount, status)
             VALUES ($1, $2, 'SYSTEM', $3, $4, 'IN_PROGRESS') RETURNING id`,
            [childUserId, periodRes.rows[0]?.id ?? null, questId, quest.reward_amount],
          );
          return res.rows[0]!.id;
        } catch (err) {
          const pgErr = err as { code?: string; constraint?: string };
          if (pgErr.code === "23505") {
            throw new HttpError(409, "quest_already_started_or_completed");
          }
          throw err;
        }
      });

      reply.code(201).send({ assignmentId });
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
      const { correctOptionCode: _omit, ...safeUiSpec } = step.ui_spec ?? {};
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
        }>(
          `SELECT quest_id, reward_amount, status FROM assignments
            WHERE id = $1 AND child_user_id = $2 AND origin = 'SYSTEM' FOR UPDATE`,
          [assignmentId, childUserId],
        );
        const assignment = assignmentRes.rows[0];
        if (!assignment) throw new HttpError(404, "assignment_not_found");
        if (assignment.status !== "IN_PROGRESS") throw new HttpError(409, "assignment_not_in_progress");

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

        const correctOptionCode = step.ui_spec?.correctOptionCode;
        const outcome: "SUCCESS" | "RECOVERABLE_ERROR" =
          !correctOptionCode || correctOptionCode === selectedOptionCode
            ? "SUCCESS"
            : "RECOVERABLE_ERROR";

        await client.query(
          `INSERT INTO quest_step_progress (assignment_id, step_no, outcome, selected_option_code)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (assignment_id, step_no)
           DO UPDATE SET outcome = EXCLUDED.outcome, selected_option_code = EXCLUDED.selected_option_code,
                         completed_at = now()`,
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
          `UPDATE assignments SET status = 'COMPLETED', reward_transaction_id = $1, updated_at = now() WHERE id = $2`,
          [txn.id, assignmentId],
        );

        return {
          outcome,
          feedback: step.success_feedback,
          questCompleted: true,
          rewardAmount: assignment.reward_amount,
          balanceAfter: txn.balanceAfter,
        };
      });
    },
  );
}
