-- Content for v0.3 mini-game "Осторожно, мелкий шрифт".
-- The Flutter client owns the visual interaction; these rows let the server
-- start the assignment, verify its five stages, and issue the reward once.

INSERT INTO education_topics (id, title, skill_description, sort_order)
VALUES (
  'CONSUMER_RIGHTS',
  'Проверяем покупки',
  'Учимся замечать дополнительные условия и ошибки в чеках',
  5
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO quest_definitions
  (id, topic_id, title, character_code, location_code, difficulty, reward_amount)
VALUES (
  'Q_MOLE_FINE_PRINT',
  'CONSUMER_RIGHTS',
  'Осторожно, мелкий шрифт',
  'MOLE_ZEMELIK',
  'MARKET',
  'SIMPLE',
  15
)
-- 15 is the top of the economy's quest reward scale (10/12/15); the payout
-- rejects anything else. DO UPDATE also corrects databases that applied the
-- branch's earlier 0020 file with a reward of 20.
ON CONFLICT (id) DO UPDATE SET reward_amount = EXCLUDED.reward_amount;

INSERT INTO quest_steps
  (quest_id, step_no, instruction, expected_action_code, success_feedback, recovery_feedback, ui_spec)
VALUES
  ('Q_MOLE_FINE_PRINT', 1,
   'Найди стоимость доставки мешка зерна и рассчитай полную цену.',
   'INSPECT_AND_VERIFY',
   'Полная стоимость найдена: 12 монет.',
   'Проверь цену товара и отдельную строку о доставке.',
   '{"correctOptionCode":"VERIFIED","episodeId":"grain_delivery"}'),
  ('Q_MOLE_FINE_PRINT', 2,
   'Проверь условия акции на фонарь и найди цену одного фонаря.',
   'INSPECT_AND_VERIFY',
   'Условие акции найдено: один фонарь стоит 9 монет.',
   'Акционная цена действует только при покупке двух фонарей.',
   '{"correctOptionCode":"VERIFIED","episodeId":"lantern_offer"}'),
  ('Q_MOLE_FINE_PRINT', 3,
   'Сравни покупки с чеком, найди лишнюю строку и выбери правильное действие.',
   'INSPECT_AND_VERIFY',
   'Лишний леденец найден, чек передан продавцу на проверку.',
   'Сравни каждую строку чека со списком покупок.',
   '{"correctOptionCode":"VERIFIED","episodeId":"extra_receipt_item"}'),
  ('Q_MOLE_FINE_PRINT', 4,
   'Найди лишнюю услугу и ошибку в итоговой сумме длинного чека.',
   'INSPECT_AND_VERIFY',
   'Найдены лишняя упаковка и неверный итог.',
   'Проверь состав покупки, затем сложи все строки по порядку.',
   '{"correctOptionCode":"VERIFIED","episodeId":"wrong_total"}'),
  ('Q_MOLE_FINE_PRINT', 5,
   'Найди две ошибки в итоговом чеке и выбери безопасный способ исправления.',
   'INSPECT_AND_VERIFY',
   'Все ошибки найдены, продавец может выдать правильный чек.',
   'Не исправляй чек сам: покажи расхождения продавцу.',
   '{"correctOptionCode":"VERIFIED","episodeId":"two_error_challenge"}')
ON CONFLICT (quest_id, step_no) DO NOTHING;
