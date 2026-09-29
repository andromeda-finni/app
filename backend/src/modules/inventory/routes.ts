import type { FastifyInstance } from "fastify";
import { requireAuth, requireRole } from "../../auth/plugin.js";
import { WEARABLE_ARTIFACT_IDS, repairCost } from "../../lib/artifacts.js";
import { withTransaction } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { postTransaction } from "../../lib/ledger.js";
import { bodySchema, paramsSchema, uuidSchema } from "../../lib/schema.js";

export async function inventoryRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: { inventoryItemId?: string | null } }>(
    "/pet/equip",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: bodySchema({ inventoryItemId: { type: ["string", "null"], format: "uuid" } }),
    },
    async (req) => {
      const childUserId = req.authUser!.id;
      const inventoryItemId = req.body?.inventoryItemId ?? null;

      return withTransaction(async (client) => {
        if (inventoryItemId) {
          const owns = await client.query<{
            item_id: string;
            durability_current: number;
            is_broken: boolean;
          }>(
            `SELECT item_id, durability_current, is_broken
               FROM inventory_items
              WHERE id = $1 AND child_user_id = $2
              FOR UPDATE`,
            [inventoryItemId, childUserId],
          );
          const item = owns.rows[0];
          if (!item) throw new HttpError(403, "item_not_owned");
          if (!WEARABLE_ARTIFACT_IDS.has(item.item_id)) {
            throw new HttpError(400, "artifact_not_wearable");
          }
          if (item.is_broken || item.durability_current === 0) {
            throw new HttpError(409, "artifact_is_broken");
          }
        }

        await client.query(
          `UPDATE pets
              SET equipped_inventory_item_id = $1, updated_at = now()
            WHERE child_user_id = $2`,
          [inventoryItemId, childUserId],
        );
        return { ok: true, equippedInventoryItemId: inventoryItemId };
      });
    },
  );

  app.post<{ Params: { inventoryItemId: string } }>(
    "/inventory/:inventoryItemId/repair",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: paramsSchema({ inventoryItemId: uuidSchema }, ["inventoryItemId"]),
    },
    async (req) => {
      const childUserId = req.authUser!.id;
      const { inventoryItemId } = req.params;

      return withTransaction(async (client) => {
        const itemRes = await client.query<{
          item_id: string;
          durability_current: number;
          durability_max: number;
          repair_cost_per_point: string | number;
        }>(
          `SELECT i.item_id, i.durability_current, i.durability_max,
                  s.repair_cost_per_point
             FROM inventory_items i
             JOIN shop_items s ON s.id = i.item_id
            WHERE i.id = $1 AND i.child_user_id = $2
            FOR UPDATE OF i`,
          [inventoryItemId, childUserId],
        );
        const item = itemRes.rows[0];
        if (!item) throw new HttpError(404, "inventory_item_not_found");

        const cost = repairCost({
          itemId: item.item_id,
          durabilityCurrent: item.durability_current,
          durabilityMax: item.durability_max,
          repairCostPerPoint: Number(item.repair_cost_per_point),
        });
        if (cost === 0) throw new HttpError(409, "artifact_not_damaged");

        const txn = await postTransaction(client, {
          childUserId,
          walletKind: "SPENDABLE",
          eventType: "ARTIFACT_REPAIR",
          deltaAmount: -cost,
          referenceType: "inventory_item",
          referenceId: inventoryItemId,
          idempotencyKey: `artifact-repair:${inventoryItemId}:${item.durability_current}`,
        });
        await client.query(
          `UPDATE inventory_items
              SET durability_current = durability_max, is_broken = false
            WHERE id = $1`,
          [inventoryItemId],
        );

        return {
          ok: true,
          repairCost: cost,
          durabilityCurrent: item.durability_max,
          durabilityMax: item.durability_max,
          balanceAfter: txn.balanceAfter,
        };
      });
    },
  );
}
