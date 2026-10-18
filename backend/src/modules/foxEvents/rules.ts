import { randomUUID } from "node:crypto";
import { HttpError } from "../../lib/errors.js";
import { foxScripts } from "./content.js";

export const FOX_DAILY_CHANCE = 0.7;
interface Node {
  terminal: boolean;
  waitUntilNextGameDay: boolean;
  coinDeltaOnEnter: number;
  choices: Record<string, { nextNodeId: string; coinDelta: number }>;
}
interface Script {
  ageGroup: string;
  initialNodeId: string;
  nodes: Record<string, Node>;
}
const scripts: Record<string, Script> = foxScripts;

export interface FoxSession {
  id: string;
  scriptId: string;
  currentNodeId: string;
  status: "active" | "waitingForNextDay" | "completed";
  dueGameDay: number | null;
  isReturnVisit: boolean;
  appliedEffectKeys: string[];
  choiceHistory: string[];
}
export interface FoxState {
  lastRollDay: number;
  completedScriptIds: string[];
  session: FoxSession | null;
}

export function rollFoxDay(state: FoxState, day: number, difficulty: string, random = Math.random): void {
  const session = state.session;
  if (session?.status === "waitingForNextDay" && session.dueGameDay! <= day) {
    session.status = "active";
    session.dueGameDay = null;
    session.isReturnVisit = true;
    state.lastRollDay = day;
    return;
  }
  if (session && session.status !== "completed") {
    // An unfinished conversation occupies today's visit as well.
    state.lastRollDay = day;
    return;
  }
  if (state.lastRollDay >= day) return;
  state.lastRollDay = day;
  state.session = null;
  if (random() >= FOX_DAILY_CHANCE) return;
  const ageGroup = difficulty === "ADVANCED" ? "older" : "younger";
  const available = Object.entries(scripts).filter(([, s]) => s.ageGroup === ageGroup);
  let next = available.find(([id]) => !state.completedScriptIds.includes(id));
  if (!next) {
    state.completedScriptIds = state.completedScriptIds.filter((id) => !available.some(([key]) => key === id));
    next = available[0]!;
  }
  state.session = {
    id: randomUUID(), scriptId: next[0], currentNodeId: next[1].initialNodeId,
    status: "active", dueGameDay: null, isReturnVisit: false,
    appliedEffectKeys: [], choiceHistory: [],
  };
}

export function currentNode(session: FoxSession): Node {
  const node = scripts[session.scriptId]?.nodes[session.currentNodeId];
  if (!node) throw new HttpError(409, "fox_story_mismatch");
  return node;
}

/** Mutates a transaction-local state; the caller posts the delta and saves atomically. */
export function advanceFox(state: FoxState, day: number, nodeId: string, choiceId?: string): number {
  const session = state.session;
  if (!session) throw new HttpError(409, "fox_not_available");
  const actionKey = `${nodeId}:${choiceId ?? "enter"}`;
  if (session.appliedEffectKeys.includes(actionKey)) return 0;
  if (session.status === "waitingForNextDay") throw new HttpError(409, "fox_not_available");
  if (session.currentNodeId !== nodeId || session.status !== "active") {
    throw new HttpError(409, "fox_story_mismatch");
  }
  const node = currentNode(session);
  let delta = 0;
  if (choiceId !== undefined) {
    const choice = node.choices[choiceId];
    if (!choice || node.terminal) throw new HttpError(400, "invalid_fox_choice");
    delta = choice.coinDelta;
    session.currentNodeId = choice.nextNodeId;
    session.choiceHistory.push(`${nodeId}:${choiceId}`);
    const next = currentNode(session);
    if (next.waitUntilNextGameDay) {
      session.status = "waitingForNextDay";
      session.dueGameDay = day + 1;
    } else {
      delta += next.coinDeltaOnEnter;
    }
  } else {
    delta = node.coinDeltaOnEnter;
  }
  if (session.status === "active" && currentNode(session).terminal) {
    session.status = "completed";
    if (!state.completedScriptIds.includes(session.scriptId)) state.completedScriptIds.push(session.scriptId);
  }
  session.appliedEffectKeys.push(actionKey);
  return delta;
}
