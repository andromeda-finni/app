import assert from "node:assert/strict";
import test from "node:test";

import { answerMatches } from "../src/modules/quests/validation.js";

const ivanRule = {
  answerValidation: {
    kind: "REQUIRED_BUDGET_SELECTION",
    budget: 10,
    itemPrices: {
      pies: 3,
      shirt: 4,
      map: 2,
      goblet: 5,
    },
    requiredGroups: [
      { label: "еда", itemIds: ["pies"] },
      { label: "тёплая одежда", itemIds: ["shirt"] },
    ],
  },
};

test("required budget selection accepts essentials with saved coins", () => {
  assert.equal(answerMatches(ivanRule, "pies,shirt"), true);
});

test("required budget selection rejects a cheap but incomplete basket", () => {
  assert.equal(answerMatches(ivanRule, "pies,map"), false);
});

test("required budget selection rejects an over-budget basket", () => {
  assert.equal(answerMatches(ivanRule, "pies,shirt,goblet"), false);
});

test("required budget selection rejects duplicates and unknown products", () => {
  assert.equal(answerMatches(ivanRule, "pies,pies,shirt"), false);
  assert.equal(answerMatches(ivanRule, "pies,shirt,crown"), false);
});

test("required budget selection can preserve a minimum reserve", () => {
  const reserveRule = {
    answerValidation: {
      kind: "REQUIRED_BUDGET_SELECTION",
      budget: 20,
      minimumRemaining: 3,
      itemPrices: { roof: 4, bed: 4, window: 3, shawl: 3, lamp: 3 },
      requiredGroups: [
        { itemIds: ["roof"] },
        { itemIds: ["bed"] },
        { itemIds: ["window"] },
        { itemIds: ["shawl"] },
      ],
    },
  };
  assert.equal(answerMatches(reserveRule, "roof,bed,window,shawl,lamp"), true);
  assert.equal(answerMatches(reserveRule, "roof,bed,window,shawl,lamp,lamp"), false);
  assert.equal(
    answerMatches(
      {
        ...reserveRule,
        answerValidation: {
          ...reserveRule.answerValidation,
          itemPrices: { ...reserveRule.answerValidation.itemPrices, vase: 6 },
        },
      },
      "roof,bed,window,shawl,vase",
    ),
    false,
  );
});
