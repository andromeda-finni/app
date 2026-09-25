import assert from "node:assert/strict";
import test from "node:test";

test("period feedback uses the child's chosen pet name", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const { buildPeriodFeedback } = await import("../src/modules/periods/routes.js");

  assert.equal(
    buildPeriodFeedback({ planFollowed: true, needCovered: true, petName: "Мурзик" }),
    "Игровой день завершён: план выполнен, Мурзик доволен и растёт.",
  );
  assert.equal(
    buildPeriodFeedback({ planFollowed: false, needCovered: false, petName: "Рыжик" }),
    "В этот раз не хватило на нужное. Рыжик расстроился, но ничего страшного.",
  );
});

test("period feedback appends the day's recommendations after the opener", async () => {
  process.env["APP_DATABASE_URL"] =
    "postgres://test:test@localhost:5432/test?sslmode=disable";
  const { buildPeriodFeedback } = await import("../src/modules/periods/routes.js");

  const text = buildPeriodFeedback({
    planFollowed: false,
    needCovered: false,
    petName: "Рыжик",
    recommendations: ["Сначала закрой обязательные траты на питомца."],
  });
  assert.match(text, /Рыжик/);
  assert.match(text, /Сначала закрой обязательные траты на питомца\.$/);
  assert.doesNotMatch(text, /Грошик/);
});
