import type { PoolClient } from "pg";

export const WEARABLE_ARTIFACT_IDS = new Set(["shield", "boots", "purse"]);

export interface ArtifactEffectResult {
  inventoryItemId: string;
  itemId: string;
  effectCode: string;
  durabilitySpent: number;
  durabilityCurrent: number;
  durabilityMax: number;
  isBroken: boolean;
}
interface UsableArtifactRow {
  id: string;
  item_id: string;
  durability_current: number;
  durability_max: number;
}

/**
 * Finds and locks one usable artifact. Wearables only work while equipped;
 * home artifacts are passive while they remain intact in the inventory.
 */
export async function useArtifact(
  client: PoolClient,
  args: {
    childUserId: string;
    itemId: string;
    effectCode: string;
    durabilityCost: number;
    referenceType: string;
    referenceId: string;
    equippedOnly?: boolean;
    inventoryItemId?: string;
  },
): Promise<ArtifactEffectResult | null> {
  const equippedJoin = args.equippedOnly
    ? "JOIN pets p ON p.child_user_id = i.child_user_id AND p.equipped_inventory_item_id = i.id"
    : "";
  const artifactRes = await client.query<UsableArtifactRow>(
    `SELECT i.id, i.item_id, i.durability_current, i.durability_max
       FROM inventory_items i
       ${equippedJoin}
      WHERE i.child_user_id = $1 AND i.item_id = $2
        AND NOT i.is_broken AND i.durability_current > 0
        AND ($3::uuid IS NULL OR i.id = $3)
      FOR UPDATE OF i`,
    [args.childUserId, args.itemId, args.inventoryItemId ?? null],
  );
  const artifact = artifactRes.rows[0];
  if (!artifact) return null;

  const priorRes = await client.query<{ durability_after: number }>(
    `SELECT durability_after
       FROM artifact_effect_events
      WHERE inventory_item_id = $1 AND effect_code = $2
        AND reference_type = $3 AND reference_id = $4`,
    [artifact.id, args.effectCode, args.referenceType, args.referenceId],
  );
  if (priorRes.rows[0]) {
    const durabilityCurrent = priorRes.rows[0].durability_after;
    return {
      inventoryItemId: artifact.id,
      itemId: artifact.item_id,
      effectCode: args.effectCode,
      durabilitySpent: 0,
      durabilityCurrent,
      durabilityMax: artifact.durability_max,
      isBroken: durabilityCurrent === 0,
    };
  }

  const durabilitySpent = Math.min(args.durabilityCost, artifact.durability_current);
  const durabilityCurrent = artifact.durability_current - durabilitySpent;
  const isBroken = durabilityCurrent === 0;

  await client.query(
    `UPDATE inventory_items
        SET durability_current = $1, is_broken = $2
      WHERE id = $3`,
    [durabilityCurrent, isBroken, artifact.id],
  );
  await client.query(
    `INSERT INTO artifact_effect_events
       (child_user_id, inventory_item_id, effect_code, durability_spent,
        durability_after, reference_type, reference_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [
      args.childUserId,
      artifact.id,
      args.effectCode,
      durabilitySpent,
      durabilityCurrent,
      args.referenceType,
      args.referenceId,
    ],
  );

  if (isBroken) {
    await client.query(
      `UPDATE pets
          SET equipped_inventory_item_id = NULL, updated_at = now()
        WHERE child_user_id = $1 AND equipped_inventory_item_id = $2`,
      [args.childUserId, artifact.id],
    );
  }

  return {
    inventoryItemId: artifact.id,
    itemId: artifact.item_id,
    effectCode: args.effectCode,
    durabilitySpent,
    durabilityCurrent,
    durabilityMax: artifact.durability_max,
    isBroken,
  };
}

export function repairCost(args: {
  itemId: string;
  durabilityCurrent: number;
  durabilityMax: number;
  repairCostPerPoint: number;
}): number {
  if (args.itemId === "vial") return args.durabilityCurrent < args.durabilityMax ? 100 : 0;
  return Math.ceil(
    (args.durabilityMax - args.durabilityCurrent) * args.repairCostPerPoint,
  );
}
