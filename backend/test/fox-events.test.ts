import assert from "node:assert/strict";
import test from "node:test";
import { foxScripts } from "../src/modules/foxEvents/content.js";
import { advanceFox, FOX_DAILY_CHANCE, rollFoxDay, type FoxState } from "../src/modules/foxEvents/rules.js";

const fresh = (): FoxState => ({ lastRollDay: 0, completedScriptIds: [], session: null });

test("Fox rolls exactly 70%, once per game day including a failed roll", () => {
  assert.equal(FOX_DAILY_CHANCE, 0.7);
  const yes = fresh();
  rollFoxDay(yes, 1, "SIMPLE", () => 0.699999);
  assert.ok(yes.session);
  const no = fresh();
  let calls = 0;
  rollFoxDay(no, 1, "SIMPLE", () => { calls++; return 0.7; });
  rollFoxDay(no, 1, "SIMPLE", () => { throw new Error("rerolled"); });
  assert.equal(no.session, null);
  assert.equal(calls, 1);
  rollFoxDay(no, 2, "SIMPLE", () => 0);
  assert.ok(no.session);
});

test("a debt returns next game day without another roll or double credit", () => {
  const state = fresh();
  rollFoxDay(state, 4, "SIMPLE", () => 0);
  assert.equal(advanceFox(state, 4, "start", "give_now"), -10);
  assert.equal(advanceFox(state, 4, "start", "give_now"), 0);
  assert.equal(advanceFox(state, 4, "gave_without_questions", "wait"), 0);
  assert.equal(advanceFox(state, 4, "gave_without_questions", "wait"), 0);
  assert.equal(state.session!.dueGameDay, 5);
  assert.throws(() => advanceFox(state, 4, "returned_without_questions"));
  rollFoxDay(state, 5, "SIMPLE", () => { throw new Error("rolled during return"); });
  assert.equal(state.session!.isReturnVisit, true);
  assert.equal(advanceFox(state, 5, "returned_without_questions"), 10);
  assert.equal(advanceFox(state, 5, "returned_without_questions"), 0);
  assert.equal(state.session!.status, "completed");
  const completedId = state.session!.id;
  rollFoxDay(state, 5, "SIMPLE", () => { throw new Error("second visit same day"); });
  assert.equal(state.session!.id, completedId);
});

test("saved conversations resume and retain their difficulty and ledger keys", () => {
  const state = fresh();
  rollFoxDay(state, 1, "ADVANCED", () => 0);
  advanceFox(state, 1, "start");
  const restored: FoxState = JSON.parse(JSON.stringify(state));
  rollFoxDay(restored, 2, "SIMPLE", () => { throw new Error("rerolled unfinished story"); });
  assert.equal(restored.session!.scriptId, "fox_older_honey_business");
  assert.equal(restored.session!.id, state.session!.id);
  assert.equal(advanceFox(restored, 2, "start"), 0);
});

test("story sequence loops with a new visit id, so repeated stories can charge again", () => {
  const state = fresh();
  const ids: string[] = [];
  const visits: string[] = [];
  for (let day = 1; day <= 4; day++) {
    rollFoxDay(state, day, "SIMPLE", () => 0);
    ids.push(state.session!.scriptId);
    visits.push(state.session!.id);
    advanceFox(state, day, "start", "refuse_now");
  }
  assert.deepEqual(ids, ["fox_younger_introduction", "fox_younger_treasure", "fox_younger_boots", "fox_younger_introduction"]);
  assert.equal(new Set(visits).size, 4);
});

test("only valid current choices can mutate the server's story", () => {
  const state = fresh();
  rollFoxDay(state, 1, "SIMPLE", () => 0);
  const before = structuredClone(state);
  assert.throws(() => advanceFox(state, 1, "returned_without_questions"));
  assert.throws(() => advanceFox(state, 1, "start", "fake_reward"));
  assert.deepEqual(state, before);
});

test("exported content has complete transitions and delayed debt outcomes", () => {
  assert.equal(Object.keys(foxScripts).length, 5);
  for (const script of Object.values(foxScripts)) {
    const nodes = script.nodes as Record<string, { terminal: boolean; waitUntilNextGameDay: boolean; coinDeltaOnEnter: number; choices: Record<string, { nextNodeId: string }> }>;
    for (const node of Object.values(nodes)) {
      for (const choice of Object.values(node.choices)) assert.ok(nodes[choice.nextNodeId]);
      if (node.coinDeltaOnEnter > 0) assert.equal(node.waitUntilNextGameDay, true);
    }
  }
});
