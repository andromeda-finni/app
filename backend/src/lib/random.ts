/**
 * Weighted random pick for game content selection (which pet event / scam
 * offer fires next). Math.random() is fine here — this is gameplay
 * randomness, not a security primitive; token generation uses node:crypto
 * (see auth/tokens.ts) instead.
 */
export function pickWeighted<T>(items: readonly T[], weightOf: (item: T) => number): T | undefined {
  const total = items.reduce((sum, item) => sum + weightOf(item), 0);
  if (total <= 0) return undefined;

  let roll = Math.random() * total;
  for (const item of items) {
    roll -= weightOf(item);
    if (roll <= 0) return item;
  }
  return items[items.length - 1];
}
