import assert from "node:assert/strict";
import test from "node:test";
import { nextTrackQuest, QUEST_TRACKS, selectDailyCandidates } from "../src/modules/quests/dailySelection.js";

test("carry-over takes slots, random only fills vacancies with different characters", () => {
  const old = { trackId: "squirrel", questId: "old", assignmentId: null };
  const fresh = [old, ...["ivan", "mole", "turnip"].map(trackId => ({ trackId, questId: trackId, assignmentId: null }))];
  const selected = selectDailyCandidates([old, old], fresh, 3, n => n - 1);
  assert.deepEqual(selected.map(row => row.trackId), ["squirrel", "turnip", "mole"]);
  assert.equal(new Set(selected.map(row => row.trackId)).size, 3);
  assert.deepEqual(selectDailyCandidates([old], fresh, 1), [old]);
});

test("an exhausted catalogue does not repeat quests to fabricate three rewards", () => {
  assert.deepEqual(selectDailyCandidates([], [], 3), []);
  const ivan = QUEST_TRACKS.find(track => track.id === "ivan")!;
  assert.equal(nextTrackQuest(ivan, "SIMPLE", new Set()), "Q_IVAN_ROAD_EASY_1");
  assert.equal(nextTrackQuest(ivan, "ADVANCED", new Set(["Q_IVAN_ROAD_EASY_1"])), "Q_IVAN_ROAD_EASY_2");
  assert.equal(nextTrackQuest(ivan, "ADVANCED", new Set(ivan.simple)), undefined);
});

test("new characters do not depend on finishing another character", () => {
  const completed = new Set<string>();
  const first = QUEST_TRACKS.map(track => nextTrackQuest(track, "SIMPLE", completed));
  assert.equal(first.filter(Boolean).length, 7);
  const advanced = QUEST_TRACKS.map(track => nextTrackQuest(track, "ADVANCED", completed));
  assert.ok(advanced.includes("Q_IVAN_ROAD_HARD_1"));
  assert.ok(advanced.includes("Q_GOLDFISH_HOME_ADVANCED_1"));
  assert.ok(advanced.includes("Q_SQUIRREL_QUALITY_ADVANCED"));
});
