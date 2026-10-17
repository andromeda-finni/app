/** Joy gained by the first stroke of a series. */
export const STROKE_JOY = 0.5;
/** Each further stroke of a series is worth 10% less than the previous one. */
export const STROKE_DECAY = 0.9;
/**
 * A pause this long ends the series. The gain of one series is bounded by
 * STROKE_JOY / (1 - STROKE_DECAY) = 5 joy, however fast the child taps.
 */
export const STROKE_STREAK_RESET_SECONDS = 10 * 60;
export const MAX_JOY = 100;

export interface StrokeState {
  joyLevel: number;
  joyFraction: number;
  streak: number;
  lastStrokedAt: Date | null;
}

export interface StrokeResult extends StrokeState {
  gain: number;
}

/** Pure stroke rule; the route applies it to a row-locked pet. */
export function applyStroke(state: StrokeState, now: Date): StrokeResult {
  const seriesContinues =
    state.lastStrokedAt !== null &&
    now.getTime() - state.lastStrokedAt.getTime() < STROKE_STREAK_RESET_SECONDS * 1000;
  const streak = seriesContinues ? state.streak : 0;
  const gain = STROKE_JOY * STROKE_DECAY ** streak;

  // Rounded to the column's scale so repeated strokes never drift.
  const total = Math.round((state.joyLevel + state.joyFraction + gain) * 1e5) / 1e5;
  const joyLevel = Math.min(MAX_JOY, Math.floor(total));
  const joyFraction =
    joyLevel >= MAX_JOY ? 0 : Math.round((total - joyLevel) * 1e5) / 1e5;

  return { joyLevel, joyFraction, streak: streak + 1, lastStrokedAt: now, gain };
}
