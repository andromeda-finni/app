import { randomInt } from "node:crypto";

export interface QuestTrack {
  id: string;
  simple: readonly string[];
  advanced?: readonly string[];
}

export const QUEST_TRACKS: readonly QuestTrack[] = [
  { id: "turnip", simple: ["Q_TURNIP_HARVEST"] },
  { id: "mole", simple: ["Q_MOLE_FINE_PRINT"] },
  { id: "ivan", simple: ["Q_IVAN_ROAD_EASY_1", "Q_IVAN_ROAD_EASY_2"],
    advanced: ["Q_IVAN_ROAD_HARD_1", "Q_IVAN_ROAD_HARD_2"] },
  { id: "goldfish", simple: ["Q_GOLDFISH_HOME_SIMPLE_1", "Q_GOLDFISH_HOME_SIMPLE_2"],
    advanced: ["Q_GOLDFISH_HOME_ADVANCED_1", "Q_GOLDFISH_HOME_ADVANCED_2"] },
  { id: "squirrel", simple: ["Q_SQUIRREL_QUALITY_SIMPLE"], advanced: ["Q_SQUIRREL_QUALITY_ADVANCED"] },
  { id: "bakery", simple: ["Q_BAKERY_PROFIT"] },
  { id: "tugriki", simple: ["Q_TUGRIKI_CURRENCY"] },
];

export function trackForQuest(questId: string): QuestTrack | undefined {
  return QUEST_TRACKS.find(track => [...track.simple, ...(track.advanced ?? [])].includes(questId));
}

export interface DailyCandidate {
  trackId: string;
  questId: string;
  assignmentId: string | null;
}

/** Carry-over order comes from persisted history. Randomness only fills vacancies. */
export function selectDailyCandidates(
  carried: readonly DailyCandidate[],
  fresh: readonly DailyCandidate[],
  limit: number,
  pickIndex: (length: number) => number = randomInt,
): DailyCandidate[] {
  const selected: DailyCandidate[] = [];
  const seen = new Set<string>();
  for (const candidate of carried) {
    if (selected.length >= limit) break;
    if (!seen.has(candidate.trackId)) {
      selected.push(candidate);
      seen.add(candidate.trackId);
    }
  }
  const pool = fresh.filter(candidate => !seen.has(candidate.trackId));
  while (pool.length && selected.length < limit) {
    const [candidate] = pool.splice(pickIndex(pool.length), 1);
    if (candidate && !seen.has(candidate.trackId)) {
      selected.push(candidate);
      seen.add(candidate.trackId);
    }
  }
  return selected;
}

/** Mirrors the existing client rule: finish a partially completed track first. */
export function nextTrackQuest(track: QuestTrack, difficulty: string, completed: ReadonlySet<string>): string | undefined {
  for (const route of [track.simple, track.advanced ?? []]) {
    if (route.some(id => completed.has(id)) && !route.every(id => completed.has(id))) {
      return route.find(id => !completed.has(id));
    }
  }
  // Either full track completes this character, even if settings later change.
  if (track.simple.every(id => completed.has(id)) ||
      (track.advanced?.every(id => completed.has(id)) ?? false)) return undefined;
  return (difficulty === "ADVANCED" ? track.advanced ?? track.simple : track.simple)
    .find(id => !completed.has(id));
}
