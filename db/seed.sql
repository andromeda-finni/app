-- Sample content data — NOT a schema migration, run manually for local/demo use:
--   psql "$DATABASE_URL" -f db/seed.sql

INSERT INTO cosmetic_options (id, kind, display_name, asset_code) VALUES
  ('FUR_ORANGE', 'FUR', 'Оранжевая шёрстка', 'fur_orange'),
  ('FUR_GRAY', 'FUR', 'Серая шёрстка', 'fur_gray'),
  ('FUR_WHITE', 'FUR', 'Белая шёрстка', 'fur_white'),
  ('ACC_SCARF', 'ACCESSORY', 'Шарфик', 'acc_scarf'),
  ('ACC_GLASSES', 'ACCESSORY', 'Очки', 'acc_glasses')
ON CONFLICT (id) DO NOTHING;

INSERT INTO education_topics (id, title, skill_description, sort_order) VALUES
  ('BUDGETING', 'Бюджет', 'Учимся планировать траты', 1),
  ('SAVING', 'Накопления', 'Учимся копить на цель', 2),
  ('SCAMS', 'Осторожно, обман', 'Учимся распознавать нечестные предложения', 3)
ON CONFLICT (id) DO NOTHING;

INSERT INTO quest_definitions (id, topic_id, title, location_code, difficulty, reward_amount) VALUES
  ('Q_FIRST_BUDGET', 'BUDGETING', 'Первый бюджет', 'FOREST', 'SIMPLE', 20),
  ('Q_SAVING_JAR', 'SAVING', 'Копилка мечты', 'FOREST', 'SIMPLE', 20)
ON CONFLICT (id) DO NOTHING;

INSERT INTO quest_steps (quest_id, step_no, instruction, expected_action_code, success_feedback, recovery_feedback, ui_spec) VALUES
  ('Q_FIRST_BUDGET', 1,
   'У тебя есть 30 монет. Сколько лучше отложить на нужное — еду для питомца?',
   'CHOOSE_OPTION', 'Верно! Нужное — в первую очередь.', 'Подумай ещё раз — что важнее прямо сейчас?',
   '{"options": [{"code": "A", "label": "10 монет"}, {"code": "B", "label": "0 монет"}], "correctOptionCode": "A"}'),
  ('Q_SAVING_JAR', 1,
   'Что выгоднее: потратить все монеты сразу или отложить часть в копилку?',
   'CHOOSE_OPTION', 'Точно! Накопления помогают достичь большой цели.', 'Попробуй ещё раз, подумай про будущее.',
   '{"options": [{"code": "A", "label": "Потратить всё"}, {"code": "B", "label": "Отложить часть"}], "correctOptionCode": "B"}')
ON CONFLICT (quest_id, step_no) DO NOTHING;

INSERT INTO shop_items (id, kind, name, price, rarity) VALUES
  ('FOOD_APPLE', 'NEED', 'Яблоко', 5, NULL),
  ('FOOD_CARROT', 'NEED', 'Морковка', 5, NULL),
  ('TOY_BALL', 'WANT', 'Мячик', 8, NULL),
  ('CANDY', 'WANT', 'Конфета', 6, NULL),
  ('HAT_GOLD', 'ARTIFACT', 'Золотая шляпа', 150, 'EPIC'),
  ('CROWN_LEGEND', 'ARTIFACT', 'Легендарная корона', 300, 'LEGENDARY')
ON CONFLICT (id) DO NOTHING;

INSERT INTO pet_event_definitions (id, title, description, cost_amount) VALUES
  ('SICK', 'Питомец заболел', 'Нужно купить лекарство', 15),
  ('HUNGRY', 'Питомец проголодался', 'Нужно срочно покормить', 10)
ON CONFLICT (id) DO NOTHING;

INSERT INTO scam_offer_definitions
  (id, npc_character_code, pitch_text, promised_amount, cost_if_accepted, decline_feedback, accept_feedback) VALUES
  ('DOUBLE_COINS', 'SLY_FOX',
   'Отдай мне 10 монет сейчас — завтра верну 20!',
   20, 10,
   'Молодец! Ты распознал обман — так деньги не удваиваются.',
   'Ой! Лис обманул тебя и забрал монеты. Настоящие сделки так не работают — если обещают слишком много, стоит насторожиться.')
ON CONFLICT (id) DO NOTHING;
