import assert from "node:assert/strict";
import test from "node:test";

test("period feedback uses the child's chosen pet name", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const { buildPeriodFeedback } = await import("../src/modules/periods/routes.js");

  assert.equal(
    buildPeriodFeedback({ planFollowed: true, needCovered: true, petName: "Мурзик" }),
    "Ты молодец! Сегодня мы уложились в план. Мурзик доволен и растёт.",
  );
  assert.equal(
    buildPeriodFeedback({ planFollowed: false, needCovered: false, petName: "Рыжик" }),
    "Сегодня план и действия немного разошлись. Рыжик ждёт заботы, а завтра попробуем ещё раз.",
  );
});

test("period feedback stays encouraging when only the allocation missed", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const { buildPeriodFeedback } = await import("../src/modules/periods/routes.js");

  const text = buildPeriodFeedback({
    planFollowed: false,
    needCovered: true,
    petName: "Рыжик",
  });
  assert.equal(
    text,
    "Сегодня план и действия немного разошлись. Завтра попробуем ещё раз.",
  );
  assert.doesNotMatch(text, /расстро/);
});

test("a day does not count as following the plan when planned needs were skipped", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const { calculateDayOutcome } = await import("../src/modules/economy/rules.js");

  const outcome = calculateDayOutcome({
    requiredNeed: 10,
    plannedNeed: 20,
    plannedWant: 10,
    plannedSavings: 0,
    actualNeed: 10,
    actualWant: 0,
    netSavings: 0,
  });

  assert.equal(outcome.needCovered, true);
  assert.equal(outcome.planFollowed, false);
  assert.match(outcome.recommendations.join(" "), /меньше, чем было в плане/);
});
