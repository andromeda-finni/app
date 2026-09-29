import assert from "node:assert/strict";
import test from "node:test";

import { repairCost, useArtifact } from "../src/lib/artifacts.js";

test("repair cost is proportional, while the empty vial costs 100", () => {
  assert.equal(
    repairCost({
      itemId: "shield",
      durabilityCurrent: 20,
      durabilityMax: 100,
      repairCostPerPoint: 0.2,
    }),
    16,
  );
  assert.equal(
    repairCost({
      itemId: "vial",
      durabilityCurrent: 0,
      durabilityMax: 1,
      repairCostPerPoint: 100,
    }),
    100,
  );
});

test("an artifact activation spends durability and unequips it when it breaks", async () => {
  const statements: string[] = [];
  const client = {
    query: async (text: string) => {
      statements.push(text);
      if (text.includes("FROM inventory_items i")) {
        return {
          rows: [
            {
              id: "inventory-shield",
              item_id: "shield",
              durability_current: 20,
              durability_max: 100,
            },
          ],
          rowCount: 1,
        };
      }
      if (text.includes("FROM artifact_effect_events")) {
        return { rows: [], rowCount: 0 };
      }
      return { rows: [], rowCount: 1 };
    },
  };

  const effect = await useArtifact(client as never, {
    childUserId: "child-1",
    itemId: "shield",
    effectCode: "VIGILANCE_SHIELD",
    durabilityCost: 20,
    referenceType: "scam_offer_occurrence",
    referenceId: "offer-1",
    equippedOnly: true,
  });

  assert.equal(effect?.durabilityCurrent, 0);
  assert.equal(effect?.isBroken, true);
  assert.ok(statements.some((sql) => sql.includes("INSERT INTO artifact_effect_events")));
  assert.ok(statements.some((sql) => sql.includes("equipped_inventory_item_id = NULL")));
});
