import type { FastifyInstance } from "fastify";
import { pool, withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction, transferBetweenWallets } from "../../lib/ledger.js";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { bodySchema, nonNegativeIntSchema, paramsSchema, uuidSchema } from "../../lib/schema.js";

const PERIOD_GRANT_BY_DIFFICULTY: Record<"SIMPLE" | "ADVANCED", number> = {
  SIMPLE: 100,
  ADVANCED: 150,
};
const REQUIRED_NEED_BY_DIFFICULTY: Record<"SIMPLE" | "ADVANCED", number> = {
  SIMPLE: 10,
  ADVANCED: 20,
};

export async function periodRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/periods/active",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query(
        `SELECT gp.*, bp.id AS budget_plan_id, bp.status AS budget_plan_status,
                bp.available_amount, bp.need_amount, bp.want_amount, bp.savings_amount
           FROM game_periods gp
           LEFT JOIN budget_plans bp ON bp.period_id = gp.id
          WHERE gp.child_user_id = $1 AND gp.status = 'ACTIVE'`,
        [req.authUser!.id],
      );
      return res.rows[0] ?? null;
    },
  );

  app.post(
    "/periods",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req, reply) => {
      const childUserId = req.authUser!.id;

      const result = await withTransaction(async (client) => {
        const childRes = await client.query<{ difficulty: "SIMPLE" | "ADVANCED" }>(
          `SELECT difficulty FROM child_profiles WHERE user_id = $1`,
          [childUserId],
        );
        const difficulty = childRes.rows[0]?.difficulty ?? "SIMPLE";

        const seqRes = await client.query<{ next_seq: number }>(
          `SELECT COALESCE(MAX(sequence_no), 0) + 1 AS next_seq FROM game_periods WHERE child_user_id = $1`,
          [childUserId],
        );
        const sequenceNo = seqRes.rows[0]!.next_seq;

        const walletsRes = await client.query<{ kind: string; balance: number }>(
          `SELECT kind, balance FROM wallets WHERE child_user_id = $1`,
          [childUserId],
        );
        const balances = Object.fromEntries(walletsRes.rows.map((w) => [w.kind, w.balance]));

        let periodId: string;
        try {
          const periodRes = await client.query<{ id: string }>(
            `INSERT INTO game_periods
               (child_user_id, sequence_no, required_need_amount, opening_spendable, opening_savings, opening_frozen)
             VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
            [
              childUserId,
              sequenceNo,
              REQUIRED_NEED_BY_DIFFICULTY[difficulty],
              balances["SPENDABLE"] ?? 0,
              balances["SAVINGS"] ?? 0,
              balances["FROZEN"] ?? 0,
            ],
          );
          periodId = periodRes.rows[0]!.id;
        } catch (err) {
          const pgErr = err as { code?: string };
          if (pgErr.code === "23505") throw new HttpError(409, "period_already_active");
          throw err;
        }

        const grantAmount = PERIOD_GRANT_BY_DIFFICULTY[difficulty];
        const txn = await postTransaction(client, {
          childUserId,
          walletKind: "SPENDABLE",
          eventType: "PERIOD_GRANT",
          deltaAmount: grantAmount,
          referenceType: "game_period",
          referenceId: periodId,
          idempotencyKey: `period-grant:${periodId}`,
        });

        const planRes = await client.query<{ id: string }>(
          `INSERT INTO budget_plans (period_id, child_user_id, available_amount)
           VALUES ($1, $2, $3) RETURNING id`,
          [periodId, childUserId, grantAmount],
        );

        return { periodId, budgetPlanId: planRes.rows[0]!.id, grantAmount, balanceAfter: txn.balanceAfter };
      });

      reply.code(201).send(result);
    },
  );

  app.put<{
    Params: { periodId: string };
    Body: { needAmount: number; wantAmount: number; savingsAmount: number };
  }>(
    "/periods/:periodId/budget-plan",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: {
        ...paramsSchema({ periodId: uuidSchema }, ["periodId"]),
        ...bodySchema(
          {
            needAmount: nonNegativeIntSchema,
            wantAmount: nonNegativeIntSchema,
            savingsAmount: nonNegativeIntSchema,
          },
          ["needAmount", "wantAmount", "savingsAmount"],
        ),
      },
    },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { periodId } = req.params;
      const { needAmount, wantAmount, savingsAmount } = req.body;

      const res = await pool.query(
        `UPDATE budget_plans
            SET need_amount = $1, want_amount = $2, savings_amount = $3
          WHERE period_id = $4 AND child_user_id = $5 AND status = 'DRAFT'
          RETURNING id, available_amount`,
        [needAmount, wantAmount, savingsAmount, periodId, childUserId],
      );
      const plan = res.rows[0];
      if (!plan) throw new HttpError(404, "draft_budget_plan_not_found");
      if (needAmount + wantAmount + savingsAmount !== plan.available_amount) {
        // Not an error — a draft may be partially filled while the child is
        // still deciding. The client shows the remaining unallocated amount.
      }
      return { ok: true };
    },
  );

  app.post<{ Params: { periodId: string } }>(
    "/periods/:periodId/budget-plan/confirm",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: paramsSchema({ periodId: uuidSchema }, ["periodId"]),
    },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { periodId } = req.params;

      const planRes = await pool.query<{
        id: string;
        need_amount: number;
        want_amount: number;
        savings_amount: number;
        available_amount: number;
      }>(
        `SELECT id, need_amount, want_amount, savings_amount, available_amount
           FROM budget_plans WHERE period_id = $1 AND child_user_id = $2 AND status = 'DRAFT'`,
        [periodId, childUserId],
      );
      const plan = planRes.rows[0];
      if (!plan) throw new HttpError(404, "draft_budget_plan_not_found");

      const periodRes = await pool.query<{ required_need_amount: number }>(
        `SELECT required_need_amount FROM game_periods WHERE id = $1 AND child_user_id = $2`,
        [periodId, childUserId],
      );
      const requiredNeed = periodRes.rows[0]?.required_need_amount ?? 0;

      if (plan.need_amount + plan.want_amount + plan.savings_amount !== plan.available_amount) {
        throw new HttpError(400, "plan_must_allocate_the_full_available_amount");
      }
      if (plan.need_amount < requiredNeed) {
        throw new HttpError(400, `need_amount_must_be_at_least_${requiredNeed}`);
      }

      await withTransaction(async (client) => {
        await client.query(
          `UPDATE budget_plans SET status = 'CONFIRMED', confirmed_at = now() WHERE id = $1`,
          [plan.id],
        );

        // Confirming the plan is the "set this aside now" moment: the planned
        // savings portion actually moves SPENDABLE -> SAVINGS here, not just
        // on paper. NEED/WANT stay in SPENDABLE to be spent via /purchases.
        if (plan.savings_amount > 0) {
          await transferBetweenWallets(client, {
            childUserId,
            fromWallet: "SPENDABLE",
            toWallet: "SAVINGS",
            amount: plan.savings_amount,
            eventType: "SAVINGS_DEPOSIT",
            referenceType: "budget_plan",
            referenceId: plan.id,
            idempotencyKeyPrefix: `budget-plan-savings:${plan.id}`,
          });
        }
      });

      return { ok: true };
    },
  );

  app.post<{ Params: { periodId: string } }>(
    "/periods/:periodId/close",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: paramsSchema({ periodId: uuidSchema }, ["periodId"]),
    },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { periodId } = req.params;

      const result = await withTransaction(async (client) => {
        const periodRes = await client.query(
          `SELECT * FROM game_periods WHERE id = $1 AND child_user_id = $2 AND status = 'ACTIVE' FOR UPDATE`,
          [periodId, childUserId],
        );
        const period = periodRes.rows[0];
        if (!period) throw new HttpError(404, "active_period_not_found");

        const planRes = await client.query(
          `SELECT * FROM budget_plans WHERE period_id = $1 AND status = 'CONFIRMED'`,
          [periodId],
        );
        const plan = planRes.rows[0];
        if (!plan) throw new HttpError(400, "budget_plan_not_confirmed");

        const needSpentRes = await client.query<{ total: string }>(
          `SELECT COALESCE(SUM(total_price), 0) AS total
             FROM purchases p JOIN transactions t ON t.id = p.transaction_id
            WHERE p.child_user_id = $1 AND p.item_kind = 'NEED' AND t.occurred_at >= $2`,
          [childUserId, period.opened_at],
        );
        const wantSpentRes = await client.query<{ total: string }>(
          `SELECT COALESCE(SUM(total_price), 0) AS total
             FROM purchases p JOIN transactions t ON t.id = p.transaction_id
            WHERE p.child_user_id = $1 AND p.item_kind = 'WANT' AND t.occurred_at >= $2`,
          [childUserId, period.opened_at],
        );
        const savingsRes = await client.query<{ deposits: string; withdrawals: string }>(
          `SELECT
             COALESCE(SUM(delta_amount) FILTER (WHERE event_type = 'SAVINGS_DEPOSIT'), 0) AS deposits,
             COALESCE(SUM(-delta_amount) FILTER (WHERE event_type = 'SAVINGS_WITHDRAWAL'), 0) AS withdrawals
           FROM transactions WHERE child_user_id = $1 AND occurred_at >= $2`,
          [childUserId, period.opened_at],
        );

        const actualNeed = Number(needSpentRes.rows[0]?.total ?? 0);
        const actualWant = Number(wantSpentRes.rows[0]?.total ?? 0);
        const netSavings =
          Number(savingsRes.rows[0]?.deposits ?? 0) - Number(savingsRes.rows[0]?.withdrawals ?? 0);

        const needCovered = actualNeed >= period.required_need_amount;
        const planFollowed =
          needCovered && actualWant <= plan.want_amount && netSavings >= plan.savings_amount;

        const petRes = await client.query<{ evolution_stage: number; successful_period_streak: number }>(
          `SELECT evolution_stage, successful_period_streak FROM pets WHERE child_user_id = $1 FOR UPDATE`,
          [childUserId],
        );
        const pet = petRes.rows[0];
        if (!pet) throw new HttpError(404, "pet_not_found");

        const stageBefore = pet.evolution_stage;
        const newStreak = planFollowed ? pet.successful_period_streak + 1 : 0;
        // Advance evolution every 3 consecutive successful periods; never regress —
        // consequences of a bad period are comedic/short-lived (see impulse-purchase
        // energy/joy dip), not a permanent setback. Matches the brief's "no harsh
        // punishment" requirement.
        const stageAfter =
          planFollowed && newStreak % 3 === 0 ? Math.min(3, stageBefore + 1) : stageBefore;

        const feedback = planFollowed
          ? "Отличный период! План выполнен, Грошик доволен и растёт."
          : needCovered
            ? "Нужное закрыто, но с желаниями или накоплениями вышло не по плану — в следующий раз получится лучше!"
            : "В этот раз не хватило на нужное. Грошик расстроился, но ничего страшного — попробуем снова.";

        await client.query(
          `UPDATE pets SET evolution_stage = $1, successful_period_streak = $2, updated_at = now()
            WHERE child_user_id = $3`,
          [stageAfter, newStreak, childUserId],
        );

        await client.query(
          `UPDATE game_periods SET status = 'COMPLETED', closed_at = now() WHERE id = $1`,
          [periodId],
        );

        await client.query(
          `INSERT INTO period_results
             (period_id, child_user_id, need_covered, plan_followed, actual_need_amount,
              actual_want_amount, net_savings_contribution, pet_stage_before, pet_stage_after, feedback_text)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
          [
            periodId,
            childUserId,
            needCovered,
            planFollowed,
            actualNeed,
            actualWant,
            netSavings,
            stageBefore,
            stageAfter,
            feedback,
          ],
        );

        return {
          needCovered,
          planFollowed,
          actualNeed,
          actualWant,
          netSavings,
          petStageBefore: stageBefore,
          petStageAfter: stageAfter,
          successfulPeriodStreak: newStreak,
          feedback,
        };
      });

      return result;
    },
  );
}
