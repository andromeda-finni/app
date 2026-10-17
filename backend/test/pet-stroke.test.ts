import assert from "node:assert/strict";
import test from "node:test";

import {
  applyStroke,
  STROKE_STREAK_RESET_SECONDS,
  type StrokeState,
} from "../src/modules/pet/stroke.js";

const start = new Date("2026-10-17T12:00:00Z");
const later = (seconds: number) => new Date(start.getTime() + seconds * 1000);

function strokeTimes(initial: StrokeState, count: number, everySeconds = 1) {
  let state: StrokeState = initial;
  const gains: number[] = [];
  for (let i = 0; i < count; i++) {
    const next = applyStroke(state, later(i * everySeconds));
    gains.push(next.gain);
    state = next;
  }
  return { state, gains };
}

const fresh: StrokeState = { joyLevel: 50, joyFraction: 0, streak: 0, lastStrokedAt: null };

test("a stroke adds half a joy point, kept as a fraction until it adds up", () => {
  const first = applyStroke(fresh, start);
  assert.equal(first.gain, 0.5);
  assert.equal(first.joyLevel, 50);
  assert.equal(first.joyFraction, 0.5);

  const second = applyStroke({ ...first, lastStrokedAt: null }, later(STROKE_STREAK_RESET_SECONDS));
  assert.equal(second.joyLevel, 51);
  assert.equal(second.joyFraction, 0);
});

test("each stroke of a rapid series is worth 10% less", () => {
  const { gains } = strokeTimes(fresh, 3);
  assert.deepEqual(gains.map((g) => Math.round(g * 1000) / 1000), [0.5, 0.45, 0.405]);
});

test("spamming cannot gain more than five joy in one series", () => {
  const { state } = strokeTimes(fresh, 500);
  assert.ok(state.joyLevel + state.joyFraction < 55, `${state.joyLevel}+${state.joyFraction}`);
  assert.ok(state.joyLevel >= 54);
});

test("a pause ends the series and restores the full stroke", () => {
  const { state } = strokeTimes(fresh, 20);
  const shortPause = applyStroke(state, later(19 + STROKE_STREAK_RESET_SECONDS - 1));
  assert.ok(shortPause.gain < 0.1);
  const longPause = applyStroke(state, later(19 + STROKE_STREAK_RESET_SECONDS));
  assert.equal(longPause.gain, 0.5);
  assert.equal(longPause.streak, 1);
});

test("joy never passes 100 and a full pet keeps no fraction", () => {
  const full = applyStroke({ joyLevel: 100, joyFraction: 0, streak: 0, lastStrokedAt: null }, start);
  assert.equal(full.joyLevel, 100);
  assert.equal(full.joyFraction, 0);
  const almost = applyStroke({ joyLevel: 99, joyFraction: 0.75, streak: 0, lastStrokedAt: null }, start);
  assert.equal(almost.joyLevel, 100);
  assert.equal(almost.joyFraction, 0);
});
