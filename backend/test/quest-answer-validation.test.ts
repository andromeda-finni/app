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
