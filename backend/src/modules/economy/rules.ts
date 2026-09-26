export const ECONOMY_RULES = {
  dailyIncome: 30,
  foodReserve: 10,
  daysPerWeek: 7,
  questRewards: [10, 12, 15] as const,
  dailyQuestLimit: 3,
  bootsQuestLimit: 4,
  parentRewardLimit: 10,
  savingsTransferAmounts: [5, 10] as const,
  eventProbability: 0.7,
  firstEventDay: 2,
  minimumEventCost: 2,
  maximumEventCost: 20,
  frostMinimum: 10,
  frostMaximum: 50,
  frostStep: 10,
  frostDays: 5,
  frostBonusPercent: 10,
} as const;

export interface DayOutcomeInput {
  requiredNeed: number;
  plannedNeed: number;
  plannedWant: number;
  plannedSavings: number;
  actualNeed: number;
  actualWant: number;
  netSavings: number;
}

export interface DayOutcome {
  needCovered: boolean;
  planFollowed: boolean;
  recommendations: string[];
}

/** Pure economy calculation shared by closing a day and report endpoints. */
export function calculateDayOutcome(input: DayOutcomeInput): DayOutcome {
  const needCovered = input.actualNeed >= input.requiredNeed;
  const planFollowed =
    needCovered &&
    input.actualWant <= input.plannedWant &&
    input.netSavings >= input.plannedSavings;

  const recommendations: string[] = [];
  if (!needCovered) {
    recommendations.push("Сначала закрой обязательные траты на питомца.");
  }
  if (input.actualWant > input.plannedWant) {
    recommendations.push("Сравни желания с планом перед следующей покупкой.");
  }
  if (input.netSavings < input.plannedSavings && recommendations.length < 2) {
    recommendations.push("Попробуй отложить в Копилку сумму из плана.");
  }
  if (recommendations.length === 0) {
    recommendations.push("План выполнен — можно продолжать в том же темпе.");
  }

  return { needCovered, planFollowed, recommendations: recommendations.slice(0, 2) };
}

export function weekForDay(sequenceNo: number): number {
  return Math.floor((sequenceNo - 1) / ECONOMY_RULES.daysPerWeek) + 1;
}

export function dayOfWeek(sequenceNo: number): number {
  return ((sequenceNo - 1) % ECONOMY_RULES.daysPerWeek) + 1;
}

/**
 * The current database constraint stores an exact 10% integer bonus. Until
 * that schema changes, deposits are accepted only in steps of ten, making the
 * result identical to ceil(principal * 10%).
 */
export function frostBonus(principal: number): number {
  return Math.ceil((principal * ECONOMY_RULES.frostBonusPercent) / 100);
}

export function assertFrostPrincipal(principal: number): void {
  if (
    !Number.isInteger(principal) ||
    principal < ECONOMY_RULES.frostMinimum ||
    principal > ECONOMY_RULES.frostMaximum ||
    principal % ECONOMY_RULES.frostStep !== 0
  ) {
    throw new Error("invalid_frost_principal");
  }
}
