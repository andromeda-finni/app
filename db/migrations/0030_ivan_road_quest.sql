-- Four independently rewarded levels for "Сборы Ивана-царевича в дорогу".
-- A child completes the two levels of their selected guidance track in order.

-- The topic used to exist only in seed.sql, which runs after migrations, so a
-- fresh database failed this file on the topic foreign key. Create it here
-- the same way other quest migrations create theirs.
INSERT INTO education_topics (id, title, skill_description, sort_order)
VALUES ('BUDGETING', 'Бюджет', 'Учимся планировать траты', 1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO quest_definitions
  (id, topic_id, title, character_code, location_code, difficulty, reward_amount)
VALUES
  ('Q_IVAN_ROAD_EASY_1', 'BUDGETING', 'Сборы в дорогу: первые покупки', 'IVAN', 'SHOP', 'SIMPLE', 10),
  ('Q_IVAN_ROAD_EASY_2', 'BUDGETING', 'Сборы в дорогу: долгая дорога', 'IVAN', 'SHOP', 'SIMPLE', 10),
  ('Q_IVAN_ROAD_HARD_1', 'BUDGETING', 'Сборы в дорогу: самостоятельный выбор', 'IVAN', 'SHOP', 'ADVANCED', 12),
  ('Q_IVAN_ROAD_HARD_2', 'BUDGETING', 'Сборы в дорогу: путь через горы', 'IVAN', 'SHOP', 'ADVANCED', 12)
ON CONFLICT (id) DO UPDATE SET
  reward_amount = EXCLUDED.reward_amount,
  title = EXCLUDED.title,
  difficulty = EXCLUDED.difficulty,
  active = true;

INSERT INTO quest_steps
  (quest_id, step_no, instruction, expected_action_code, success_feedback, recovery_feedback, ui_spec)
VALUES
  ('Q_IVAN_ROAD_EASY_1', 1,
   'Собери еду и тёплую одежду, не превышая бюджет 10 монет.',
   'SELECT_GOODS',
   'Всё необходимое собрано, а бюджет сохранён.',
   'Сначала выбери еду и тёплую одежду и проверь итоговую сумму.',
   '{"gameId":"ivan","answerValidation":{"kind":"REQUIRED_BUDGET_SELECTION","budget":10,"itemPrices":{"pies":3,"warm_shirt_easy":4,"map":2,"rope":2,"lollipop_easy":2,"golden_goblet":5},"requiredGroups":[{"label":"еда","itemIds":["pies"]},{"label":"тёплая одежда","itemIds":["warm_shirt_easy"]}]}}'),
  ('Q_IVAN_ROAD_EASY_2', 1,
   'Собери еду, воду, тёплую одежду и свечку, не превышая бюджет 12 монет.',
   'SELECT_GOODS',
   'Все полезные вещи собраны точно по бюджету.',
   'Проверь, есть ли в рюкзаке еда, вода, тёплая одежда и свечка.',
   '{"gameId":"ivan","answerValidation":{"kind":"REQUIRED_BUDGET_SELECTION","budget":12,"itemPrices":{"bread_cheese":3,"warm_cloak":5,"candle":2,"flask":2,"toy_horse":4,"music_box":5},"requiredGroups":[{"label":"еда","itemIds":["bread_cheese"]},{"label":"тёплая одежда","itemIds":["warm_cloak"]},{"label":"вода","itemIds":["flask"]},{"label":"свечка","itemIds":["candle"]}]}}'),
  ('Q_IVAN_ROAD_HARD_1', 1,
   'Собери еду, воду и тёплую одежду, сравнивая пользу и цены.',
   'SELECT_GOODS',
   'Необходимые покупки выбраны, бюджет не превышен.',
   'Проверь обязательные вещи и общую стоимость покупок.',
   '{"gameId":"ivan","answerValidation":{"kind":"REQUIRED_BUDGET_SELECTION","budget":14,"itemPrices":{"pies":3,"warm_shirt_hard":5,"flask":2,"map_hard":3,"candle":2,"rope":2,"sturdy_boots":4,"magic_wand":8,"golden_goblet":5},"requiredGroups":[{"label":"еда","itemIds":["pies"]},{"label":"тёплая одежда","itemIds":["warm_shirt_hard"]},{"label":"вода","itemIds":["flask"]}]}}'),
  ('Q_IVAN_ROAD_HARD_2', 1,
   'Собери припасы, тепло, карту и вещь для трудного пути в пределах 15 монет.',
   'SELECT_GOODS',
   'Путь через горы продуман, а покупки уложились в бюджет.',
   'Сравни обычные и волшебные вещи и проверь все пять потребностей.',
   '{"gameId":"ivan","answerValidation":{"kind":"REQUIRED_BUDGET_SELECTION","budget":15,"itemPrices":{"pies":3,"warm_shirt_final":4,"flask":2,"simple_boots":3,"speed_boots":7,"map":2,"magic_map":5,"candle":2,"lantern":4,"rope":2,"lollipop_final":1,"firebird_feather":5},"requiredGroups":[{"label":"еда","itemIds":["pies"]},{"label":"тёплая одежда","itemIds":["warm_shirt_final"]},{"label":"вода","itemIds":["flask"]},{"label":"карта","itemIds":["map","magic_map"]},{"label":"вещь для трудного пути","itemIds":["rope","simple_boots","speed_boots"]}]}}')
ON CONFLICT (quest_id, step_no) DO UPDATE SET
  instruction = EXCLUDED.instruction,
  success_feedback = EXCLUDED.success_feedback,
  recovery_feedback = EXCLUDED.recovery_feedback,
  ui_spec = EXCLUDED.ui_spec;

INSERT INTO quest_prerequisites (quest_id, prerequisite_quest_id)
VALUES
  ('Q_IVAN_ROAD_EASY_1', 'Q_MOLE_FINE_PRINT'),
  ('Q_IVAN_ROAD_EASY_2', 'Q_IVAN_ROAD_EASY_1'),
  ('Q_IVAN_ROAD_HARD_1', 'Q_MOLE_FINE_PRINT'),
  ('Q_IVAN_ROAD_HARD_2', 'Q_IVAN_ROAD_HARD_1')
ON CONFLICT DO NOTHING;
