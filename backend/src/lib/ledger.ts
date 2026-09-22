import type { PoolClient } from "pg";
import { HttpError } from "./errors.js";

export type WalletKind = "SPENDABLE" | "SAVINGS" | "FROZEN";

export type TransactionEventType =
  | "START_GRANT"
  | "DAILY_INCOME"
  | "STREAK_BONUS"
  | "PERIOD_GRANT"
  | "QUEST_REWARD"
  | "PARENT_TASK_REWARD"
  | "PURCHASE"
  | "SAVINGS_DEPOSIT"
  | "SAVINGS_WITHDRAWAL"
  | "FROST_DEPOSIT"
  | "FROST_WITHDRAWAL"
  | "FROST_BONUS"
  | "GOAL_REDEMPTION"
  | "PET_EVENT_PAYMENT"
  | "SCAM_OFFER_LOSS";

export interface PostTransactionInput {
  childUserId: string;
  walletKind: WalletKind;
  eventType: TransactionEventType;
  deltaAmount: number; // positive = credit, negative = debit
  referenceType?: string | undefined;
  referenceId?: string | undefined;
  idempotencyKey: string;
}

export interface PostedTransaction {
  id: string;
  balanceAfter: number;
}

/**
 * The single choke point for every wallet mutation. Locks the wallet row
 * (SELECT ... FOR UPDATE) so concurrent requests for the same child/wallet
 * can't both read a stale balance, computes balance_after itself (never
 * trusts a client-supplied balance), and throws a 409 if a debit would push
 * the balance negative — the DB CHECK constraint would also catch this, but
 * failing here gives a clean HTTP error instead of a raw Postgres error.
 */
export async function postTransaction(
  client: PoolClient,
  input: PostTransactionInput,
): Promise<PostedTransaction> {
  const walletRes = await client.query<{ balance: number }>(
    `SELECT balance FROM wallets WHERE child_user_id = $1 AND kind = $2 FOR UPDATE`,
    [input.childUserId, input.walletKind],
  );
  const wallet = walletRes.rows[0];
  if (!wallet) {
    throw new HttpError(404, `wallet ${input.walletKind} not found for child`);
  }

  const balanceAfter = wallet.balance + input.deltaAmount;
  if (balanceAfter < 0) {
    throw new HttpError(409, "insufficient_funds");
  }

  const txnRes = await client.query<{ id: string }>(
    `INSERT INTO transactions
       (child_user_id, wallet_kind, event_type, delta_amount, balance_after,
        reference_type, reference_id, idempotency_key)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING id`,
    [
      input.childUserId,
      input.walletKind,
      input.eventType,
      input.deltaAmount,
      balanceAfter,
      input.referenceType ?? null,
      input.referenceId ?? null,
      input.idempotencyKey,
    ],
  );

  await client.query(
    `UPDATE wallets SET balance = $1, updated_at = now() WHERE child_user_id = $2 AND kind = $3`,
    [balanceAfter, input.childUserId, input.walletKind],
  );

  return { id: txnRes.rows[0]!.id, balanceAfter };
}

/**
 * Moves `amount` from one wallet to another for the same child as a single
 * atomic pair of transactions sharing one idempotency prefix. Used both for
 * the explicit /savings/deposit|withdraw endpoints and to actually move
 * money into SAVINGS when a budget plan is confirmed (confirming the plan
 * is the "I'm putting this aside now" moment, not just a paper intention).
 */
export async function transferBetweenWallets(
  client: PoolClient,
  args: {
    childUserId: string;
    fromWallet: WalletKind;
    toWallet: WalletKind;
    amount: number;
    eventType: TransactionEventType;
    referenceType?: string;
    referenceId?: string;
    idempotencyKeyPrefix: string;
  },
): Promise<{ fromTxnId: string; toTxnId: string }> {
  const from = await postTransaction(client, {
    childUserId: args.childUserId,
    walletKind: args.fromWallet,
    eventType: args.eventType,
    deltaAmount: -args.amount,
    referenceType: args.referenceType,
    referenceId: args.referenceId,
    idempotencyKey: `${args.idempotencyKeyPrefix}:from`,
  });
  const to = await postTransaction(client, {
    childUserId: args.childUserId,
    walletKind: args.toWallet,
    eventType: args.eventType,
    deltaAmount: args.amount,
    referenceType: args.referenceType,
    referenceId: args.referenceId,
    idempotencyKey: `${args.idempotencyKeyPrefix}:to`,
  });
  return { fromTxnId: from.id, toTxnId: to.id };
}

/**
 * Debits SPENDABLE first and, if that alone can't cover `amount`, debits the
 * remainder from SAVINGS. Used for pet-event bills: "pay from your everyday
 * money, and if that's not enough, it comes out of your savings" — the game's
 * concrete lesson about having a safety net for surprise expenses.
 */
export async function postSpendableThenSavings(
  client: PoolClient,
  args: {
    childUserId: string;
    amount: number;
    eventType: TransactionEventType;
    referenceType: string;
    referenceId: string;
    idempotencyKeyPrefix: string;
  },
): Promise<{ spendableTxnId: string | null; savingsTxnId: string | null }> {
  const spendableRes = await client.query<{ balance: number }>(
    `SELECT balance FROM wallets WHERE child_user_id = $1 AND kind = 'SPENDABLE' FOR UPDATE`,
    [args.childUserId],
  );
  const spendableBalance = spendableRes.rows[0]?.balance ?? 0;
  const fromSpendable = Math.min(spendableBalance, args.amount);
  const remainder = args.amount - fromSpendable;

  // transactions.delta_amount has CHECK (delta_amount <> 0) — skip posting a
  // leg entirely when it would be zero (e.g. SPENDABLE is already empty)
  // instead of letting that constraint reject the whole operation.
  const spendableTxnId =
    fromSpendable > 0
      ? (
          await postTransaction(client, {
            childUserId: args.childUserId,
            walletKind: "SPENDABLE",
            eventType: args.eventType,
            deltaAmount: -fromSpendable,
            referenceType: args.referenceType,
            referenceId: args.referenceId,
            idempotencyKey: `${args.idempotencyKeyPrefix}:spendable`,
          })
        ).id
      : null;

  if (remainder === 0) {
    return { spendableTxnId, savingsTxnId: null };
  }

  const savings = await postTransaction(client, {
    childUserId: args.childUserId,
    walletKind: "SAVINGS",
    eventType: args.eventType,
    deltaAmount: -remainder,
    referenceType: args.referenceType,
    referenceId: args.referenceId,
    idempotencyKey: `${args.idempotencyKeyPrefix}:savings`,
  });

  return { spendableTxnId, savingsTxnId: savings.id };
}
