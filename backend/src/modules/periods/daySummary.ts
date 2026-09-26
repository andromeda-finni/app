import type { PoolClient } from "pg";
import { HttpError } from "../../lib/errors.js";
import { calculateDayOutcome } from "../economy/rules.js";

interface StoredDaySummary {
  period_id: string;
  sequence_no: number;
  required_need_amount: number;
  planned_need: number;
  planned_want: number;
  planned_savings: number;
  need_covered: boolean;
  plan_followed: boolean;
  actual_need: number;
  actual_want: number;
  actual_savings: number;
  pet_stage_before: number;
  pet_stage_after: number;
  feedback: string;
  earned_amount: number;
}

/**
 * The stable response returned both by the first close request and by a replay.
 * It is assembled only from persisted rows, so a transport timeout can never
 * make the child lose the result screen after the day has already closed.
 */
export async function readDaySummary(
  client: PoolClient,
  childUserId: string,
  periodId: string,
) {
  const summaryRes = await client.query<StoredDaySummary>(
    `SELECT gp.id AS period_id, gp.sequence_no, gp.required_need_amount,
            bp.need_amount AS planned_need,
            bp.want_amount AS planned_want,
            bp.savings_amount AS planned_savings,
            pr.need_covered, pr.plan_followed,
            pr.actual_need_amount AS actual_need,
            pr.actual_want_amount AS actual_want,
            pr.net_savings_contribution AS actual_savings,
            pr.pet_stage_before, pr.pet_stage_after,
            pr.feedback_text AS feedback,
            COALESCE((
              SELECT SUM(t.delta_amount)
                FROM transactions t
               WHERE t.child_user_id = gp.child_user_id
                 AND t.delta_amount > 0
                 AND t.event_type IN (
                   'DAILY_INCOME', 'PERIOD_GRANT', 'STREAK_BONUS',
                   'QUEST_REWARD', 'PARENT_TASK_REWARD'
                 )
                 AND t.occurred_at >= gp.opened_at
                 AND t.occurred_at <= gp.closed_at
            ), 0)::int AS earned_amount
       FROM game_periods gp
       JOIN budget_plans bp ON bp.period_id = gp.id
       JOIN period_results pr ON pr.period_id = gp.id
      WHERE gp.id = $1 AND gp.child_user_id = $2 AND gp.status = 'COMPLETED'`,
    [periodId, childUserId],
  );
  const row = summaryRes.rows[0];
  if (!row) throw new HttpError(404, "period_result_not_found");

  const outcome = calculateDayOutcome({
    requiredNeed: row.required_need_amount,
    plannedNeed: row.planned_need,
    plannedWant: row.planned_want,
    plannedSavings: row.planned_savings,
    actualNeed: row.actual_need,
    actualWant: row.actual_want,
    netSavings: row.actual_savings,
  });

  const streakRes = await client.query<{ plan_followed: boolean }>(
    `SELECT pr.plan_followed
       FROM period_results pr
       JOIN game_periods gp ON gp.id = pr.period_id
      WHERE pr.child_user_id = $1 AND gp.sequence_no <= $2
      ORDER BY gp.sequence_no DESC`,
    [childUserId, row.sequence_no],
  );
  let successfulPeriodStreak = 0;
  for (const result of streakRes.rows) {
    if (!result.plan_followed) break;
    successfulPeriodStreak++;
  }

  return {
    periodId: row.period_id,
    sequenceNo: row.sequence_no,
    earnedAmount: row.earned_amount,
    plan: {
      need: row.planned_need,
      want: row.planned_want,
      savings: row.planned_savings,
    },
    actual: {
      need: row.actual_need,
      want: row.actual_want,
      savings: row.actual_savings,
    },
    // Keep the established top-level fields while the Flutter client adopts
    // the clearer nested plan/actual contract.
    needCovered: row.need_covered,
    planFollowed: row.plan_followed,
    actualNeed: row.actual_need,
    actualWant: row.actual_want,
    netSavings: row.actual_savings,
    petStageBefore: row.pet_stage_before,
    petStageAfter: row.pet_stage_after,
    successfulPeriodStreak,
    feedback: row.feedback,
    recommendations: outcome.recommendations,
  };
}
