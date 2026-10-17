import type { PoolClient } from "pg";
import { postTransaction, transferBetweenWallets } from "../../lib/ledger.js";

/** Coins distributed in the onboarding tutorial and granted on the first day. */
export const TUTORIAL_INCOME = 10;

export interface TutorialPlan {
  needAmount: number;
  wantAmount: number;
  savingsAmount: number;
}

export function isValidTutorialPlan(plan: TutorialPlan): boolean {
  return (
    plan.needAmount + plan.wantAmount + plan.savingsAmount ===
    TUTORIAL_INCOME
  );
}

/**
 * Opens the child's first game day from the onboarding tutorial budget: the
 * tutorial's ten coins are granted and the split the child chose is confirmed
 * as that day's plan, so the planned savings move to SAVINGS right away just
 * like a regular confirmed plan. Every later day uses the regular income.
 *
 * The obligatory-need floor is the child's own planned NEED amount: the usual
 * food reserve cannot be demanded from a ten-coin tutorial budget.
 *
 * Returns false without changes when the child already has any game day, so
 * a replayed onboarding completion never grants the coins twice.
 */
export async function openTutorialDay(
  client: PoolClient,
  childUserId: string,
  plan: TutorialPlan,
): Promise<boolean> {
  const existing = await client.query(
    `SELECT 1 FROM game_periods WHERE child_user_id = $1 LIMIT 1`,
    [childUserId],
  );
  if (existing.rowCount) return false;

  const walletsRes = await client.query<{ kind: string; balance: number }>(
    `SELECT kind, balance FROM wallets WHERE child_user_id = $1`,
    [childUserId],
  );
  const balances = Object.fromEntries(walletsRes.rows.map((w) => [w.kind, w.balance]));

  const periodRes = await client.query<{ id: string }>(
    `INSERT INTO game_periods
       (child_user_id, sequence_no, required_need_amount, opening_spendable, opening_savings, opening_frozen)
     VALUES ($1, 1, $2, $3, $4, $5) RETURNING id`,
    [
      childUserId,
      plan.needAmount,
      balances["SPENDABLE"] ?? 0,
      balances["SAVINGS"] ?? 0,
      balances["FROZEN"] ?? 0,
    ],
  );
  const periodId = periodRes.rows[0]!.id;

  await postTransaction(client, {
    childUserId,
    walletKind: "SPENDABLE",
    eventType: "DAILY_INCOME",
    deltaAmount: TUTORIAL_INCOME,
    referenceType: "game_period",
    referenceId: periodId,
    idempotencyKey: `daily-income:${periodId}`,
  });

  const planRes = await client.query<{ id: string }>(
    `INSERT INTO budget_plans
       (period_id, child_user_id, available_amount, need_amount, want_amount,
        savings_amount, status, confirmed_at)
     VALUES ($1, $2, $3, $4, $5, $6, 'CONFIRMED', now()) RETURNING id`,
    [
      periodId,
      childUserId,
      TUTORIAL_INCOME,
      plan.needAmount,
      plan.wantAmount,
      plan.savingsAmount,
    ],
  );
  const planId = planRes.rows[0]!.id;

  if (plan.savingsAmount > 0) {
    await transferBetweenWallets(client, {
      childUserId,
      fromWallet: "SPENDABLE",
      toWallet: "SAVINGS",
      amount: plan.savingsAmount,
      eventType: "SAVINGS_DEPOSIT",
      referenceType: "budget_plan",
      referenceId: planId,
      idempotencyKeyPrefix: `budget-plan-savings:${planId}`,
    });
  }
  return true;
}
