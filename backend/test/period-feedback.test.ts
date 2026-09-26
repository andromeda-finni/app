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
