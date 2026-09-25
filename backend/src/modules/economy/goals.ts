import type { PoolClient } from "pg";
import { HttpError } from "../../lib/errors.js";

// Serialize goal lifecycle changes even when there is no goal row yet.
export async function lockGoalOwner(client: PoolClient, childUserId: string): Promise<void> {
  await client.query(`SELECT user_id FROM child_profiles WHERE user_id = $1 FOR UPDATE`, [childUserId]);
}

export async function requireGoal(client: PoolClient, childUserId: string, allowCompletedCatalog = false): Promise<void> {
  const goal = await client.query(
    `SELECT 1 FROM financial_goals WHERE child_user_id = $1 AND status IN ('ACTIVE','PAUSED','ACHIEVED')`,
    [childUserId],
  );
  if (goal.rowCount) return;
  if (allowCompletedCatalog) {
    const remaining = await client.query(
      `SELECT 1 FROM shop_items s WHERE s.active AND s.kind = 'ARTIFACT'
       AND NOT EXISTS (SELECT 1 FROM inventory_items i WHERE i.child_user_id = $1 AND i.item_id = s.id) LIMIT 1`,
      [childUserId],
    );
    if (!remaining.rowCount) return;
  }
  throw new HttpError(409, "financial_goal_required");
}
