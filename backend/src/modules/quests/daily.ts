import type { PoolClient } from "pg";
import { HttpError } from "../../lib/errors.js";
import { ECONOMY_RULES } from "../economy/rules.js";
import { nextTrackQuest, QUEST_TRACKS, selectDailyCandidates, trackForQuest,
  type DailyCandidate } from "./dailySelection.js";

export interface DailyOffer {
  trackId: string;
  questId: string;
  assignmentId: string | null;
  status: "AVAILABLE" | "IN_PROGRESS" | "COMPLETED";
  rewardAmount: number;
  /** Lets the offline app know which answer completes the quest. */
  stepCount: number;
}

interface HistoryRow {
  id: string;
  quest_id: string;
  status: string;
  period_id: string | null;
  reward_amount: number;
}

/** Must run inside a transaction. All starts/answers take this owner lock first. */
export async function readDailyQuests(client: PoolClient, childUserId: string) {
  const profile = (await client.query<{ difficulty: string }>(
    `SELECT difficulty FROM child_profiles WHERE user_id = $1 FOR UPDATE`, [childUserId],
  )).rows[0];
  if (!profile) throw new HttpError(404, "child_profile_not_found");
  const period = (await client.query<{ id: string; sequence_no: number; plan_status: string }>(
    `SELECT gp.id, gp.sequence_no, bp.status AS plan_status
       FROM game_periods gp LEFT JOIN budget_plans bp ON bp.period_id = gp.id
      WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE' FOR UPDATE OF gp`, [childUserId],
  )).rows[0];
  if (!period) return { periodId: null, sequenceNo: null, limit: 3,
    planConfirmed: false, offers: [] as DailyOffer[], replays: [] as DailyOffer[] };

  const history = (await client.query<HistoryRow>(
    `SELECT id, quest_id, status, period_id, reward_amount FROM assignments
      WHERE child_user_id = $1 AND origin = 'SYSTEM'
        AND status IN ('IN_PROGRESS', 'COMPLETED') ORDER BY created_at DESC, id DESC`, [childUserId],
  )).rows;
  const completed = new Set(history.filter(row => row.status === "COMPLETED").map(row => row.quest_id));
  const catalog = (await client.query<{ id: string; reward_amount: number }>(
    `SELECT id, CASE WHEN $1 = 'ADVANCED' THEN COALESCE(advanced_reward_amount, reward_amount)
                    ELSE reward_amount END AS reward_amount
       FROM quest_definitions WHERE active`, [profile.difficulty],
  )).rows;
  const active = new Map(catalog.map(row => [row.id, row.reward_amount]));
  const stepCounts = new Map((await client.query<{ quest_id: string; steps: number }>(
    `SELECT quest_id, COUNT(*)::int AS steps FROM quest_steps GROUP BY quest_id`,
  )).rows.map(row => [row.quest_id, row.steps]));
  let selection = (await client.query<{ slot_limit: number }>(
    `SELECT slot_limit FROM quest_day_selections WHERE period_id = $1 AND child_user_id = $2`,
    [period.id, childUserId],
  )).rows[0];

  if (!selection) {
    const boots = await client.query(
      `SELECT 1 FROM pets p JOIN inventory_items i ON i.id = p.equipped_inventory_item_id
        WHERE p.child_user_id = $1 AND i.item_id = 'boots'
          AND NOT i.is_broken AND i.durability_current > 0`, [childUserId],
    );
    const limit = boots.rowCount ? ECONOMY_RULES.bootsQuestLimit : ECONOMY_RULES.dailyQuestLimit;
    // A mid-day upgrade must not create a second paid opportunity for a character.
    const doneToday: DailyCandidate[] = history
      .filter(row => row.status === "COMPLETED" && row.period_id === period.id)
      .flatMap(row => {
        const track = trackForQuest(row.quest_id);
        return track ? [{ trackId: track.id, questId: row.quest_id, assignmentId: row.id }] : [];
      });
    const carried = (await client.query<{ track_id: string; quest_id: string; assignment_id: string | null }>(
      `SELECT track_id, quest_id, assignment_id FROM (
       SELECT DISTINCT ON (o.track_id) o.track_id, o.quest_id, o.assignment_id,
              gp.sequence_no, o.slot
         FROM quest_day_offers o JOIN game_periods gp ON gp.id = o.period_id
        WHERE o.child_user_id = $1 AND gp.sequence_no < $2
          AND NOT EXISTS (SELECT 1 FROM assignments a WHERE a.child_user_id = $1
                          AND a.origin = 'SYSTEM' AND a.quest_id = o.quest_id AND a.status = 'COMPLETED')
        ORDER BY o.track_id, gp.sequence_no, o.slot
       ) pending ORDER BY sequence_no, slot`, [childUserId, period.sequence_no],
    )).rows.map(row => ({ trackId: row.track_id, questId: row.quest_id, assignmentId: row.assignment_id }));
    const legacyStarted: DailyCandidate[] = [...history].reverse()
      .filter(row => row.status === "IN_PROGRESS" && !completed.has(row.quest_id))
      .flatMap(row => {
        const track = trackForQuest(row.quest_id);
        return track ? [{ trackId: track.id, questId: row.quest_id, assignmentId: row.id }] : [];
      });
    const fresh: DailyCandidate[] = QUEST_TRACKS.flatMap(track => {
      const questId = nextTrackQuest(track, profile.difficulty, completed);
      return questId && active.has(questId) ? [{ trackId: track.id, questId, assignmentId: null }] : [];
    });
    const chosen = selectDailyCandidates([...doneToday, ...legacyStarted, ...carried]
      .filter(row => active.has(row.questId)), fresh, limit);
    await client.query(
      `INSERT INTO quest_day_selections(period_id, child_user_id, slot_limit) VALUES ($1, $2, $3)`,
      [period.id, childUserId, limit],
    );
    for (const [index, offer] of chosen.entries()) {
      await client.query(
        `INSERT INTO quest_day_offers(period_id, child_user_id, slot, track_id, quest_id, assignment_id)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [period.id, childUserId, index + 1, offer.trackId, offer.questId, offer.assignmentId],
      );
    }
    selection = { slot_limit: limit };
  }
  const rows = (await client.query<{
    track_id: string; quest_id: string; assignment_id: string | null;
  }>(
    `SELECT track_id, quest_id, assignment_id FROM quest_day_offers
      WHERE period_id = $1 AND child_user_id = $2 ORDER BY slot`, [period.id, childUserId],
  )).rows;
  const offers: DailyOffer[] = rows.map(row => {
    const assignment = history.find(item => item.quest_id === row.quest_id);
    return { trackId: row.track_id, questId: row.quest_id,
      assignmentId: assignment?.id ?? row.assignment_id,
      status: assignment?.status === "COMPLETED" ? "COMPLETED" :
        assignment?.status === "IN_PROGRESS" ? "IN_PROGRESS" : "AVAILABLE",
      rewardAmount: assignment?.reward_amount ?? active.get(row.quest_id) ?? 0,
      stepCount: stepCounts.get(row.quest_id) ?? 1 };
  });
  const replayTracks = new Set<string>();
  const replays: DailyOffer[] = history.filter(row => row.status === "COMPLETED").flatMap(row => {
    const track = trackForQuest(row.quest_id);
    if (!track || replayTracks.has(track.id) || !active.has(row.quest_id)) return [];
    replayTracks.add(track.id);
    return [{ trackId: track.id, questId: row.quest_id, assignmentId: row.id,
      status: "COMPLETED" as const, rewardAmount: row.reward_amount,
      stepCount: stepCounts.get(row.quest_id) ?? 1 }];
  });
  return { periodId: period.id, sequenceNo: period.sequence_no,
    limit: selection.slot_limit, planConfirmed: period.plan_status === "CONFIRMED", offers, replays };
}
