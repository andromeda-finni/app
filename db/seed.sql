-- Initial game catalogs — NOT a schema migration. Run after migrations:
--   psql "$DATABASE_URL" -f db/seed.sql

INSERT INTO cosmetic_options (id, kind, display_name, asset_code) VALUES
  ('FUR_ORANGE', 'FUR', 'Оранжевая шёрстка', 'fur_orange'),
  ('FUR_GRAY', 'FUR', 'Серая шёрстка', 'fur_gray'),
  ('FUR_WHITE', 'FUR', 'Белая шёрстка', 'fur_white'),
  ('ACC_COLLAR_RED', 'ACCESSORY', 'Красный ошейник', 'collar_red'),
  ('ACC_COLLAR_GREEN', 'ACCESSORY', 'Зелёный ошейник', 'collar_green'),
  ('ACC_COLLAR_BLUE', 'ACCESSORY', 'Синий ошейник', 'collar_blue'),
  ('ACC_SCARF', 'ACCESSORY', 'Шарфик', 'acc_scarf'),
  ('ACC_GLASSES', 'ACCESSORY', 'Очки', 'acc_glasses')
ON CONFLICT (id) DO NOTHING;

INSERT INTO education_topics (id, title, skill_description, sort_order) VALUES
  ('BUDGETING', 'Бюджет', 'Учимся планировать траты', 1),
  ('SAVING', 'Накопления', 'Учимся копить на цель', 2),
  ('SCAMS', 'Осторожно, обман', 'Учимся распознавать нечестные предложения', 3),
  ('CURRENCY', 'Иностранная валюта', 'Учимся переводить цены по курсу', 4),
  ('CONSUMER_RIGHTS', 'Проверяем покупки', 'Учимся замечать условия и ошибки в чеках', 5),
  ('INCOME', 'Откуда берутся деньги', 'Учимся понимать, что доход появляется из общего труда', 6)
ON CONFLICT (id) DO NOTHING;

INSERT INTO quest_definitions (id, topic_id, title, location_code, difficulty, reward_amount) VALUES
  ('Q_FIRST_BUDGET', 'BUDGETING', 'Первый бюджет', 'FOREST', 'SIMPLE', 10),
  ('Q_SAVING_JAR', 'SAVING', 'Копилка мечты', 'FOREST', 'SIMPLE', 12),
  ('Q_SAFE_CHOICE', 'SCAMS', 'Разговор с хитрым Лисом', 'TOWN', 'SIMPLE', 15),
  -- Five-stage mini-games take the top step of the economy's 10/12/15 scale;
  -- any other value is refused when the reward is paid out.
  ('Q_TUGRIKI_CURRENCY', 'CURRENCY', 'Ярмарка тугриков', 'MARKET', 'SIMPLE', 15),
  ('Q_MOLE_FINE_PRINT', 'CONSUMER_RIGHTS', 'Осторожно, мелкий шрифт', 'MARKET', 'SIMPLE', 15),
  ('Q_TURNIP_HARVEST', 'INCOME', 'Репка', 'VILLAGE', 'SIMPLE', 10)
ON CONFLICT (id) DO UPDATE SET
  reward_amount = EXCLUDED.reward_amount,
  title = EXCLUDED.title,
  location_code = EXCLUDED.location_code;

INSERT INTO quest_steps (quest_id, step_no, instruction, expected_action_code, success_feedback, recovery_feedback, ui_spec) VALUES
  ('Q_FIRST_BUDGET', 1,
   'У тебя есть 30 монет. Сколько лучше отложить на нужное — еду для питомца?',
   'CHOOSE_OPTION', 'Верно! Нужное — в первую очередь.', 'Подумай ещё раз — что важнее прямо сейчас?',
   '{"options": [{"code": "A", "label": "10 монет"}, {"code": "B", "label": "0 монет"}], "correctOptionCode": "A"}'),
  ('Q_SAVING_JAR', 1,
   'Что выгоднее: потратить все монеты сразу или отложить часть в копилку?',
   'CHOOSE_OPTION', 'Точно! Накопления помогают достичь большой цели.', 'Попробуй ещё раз, подумай про будущее.',
   '{"options": [{"code": "A", "label": "Потратить всё"}, {"code": "B", "label": "Отложить часть"}], "correctOptionCode": "B"}'),
  ('Q_SAFE_CHOICE', 1,
   'Лис обещает удвоить монеты, если отдать их сейчас. Что выбрать?',
   'CHOOSE_OPTION', 'Верно! Слишком щедрое обещание лучше проверить.', 'Подумай, почему незнакомцу нельзя отдавать накопления.',
   '{"options": [{"code": "A", "label": "Отдать монеты"}, {"code": "B", "label": "Отказаться"}], "correctOptionCode": "B"}'),
  -- The fair is one interactive story. The client sends the chosen goods and
  -- the server independently checks that every item exists and the total fits
  -- the 20-coin budget.
  ('Q_TUGRIKI_CURRENCY', 1,
   'Пересчитай цены ярмарки из тугриков в монеты и уложись в бюджет.',
   'COMPLETE_STORY',
   'Ярмарка пройдена: ты умеешь пересчитывать цены по курсу.',
   'Вспомни курс: за 1 тугрик отдают 2 монетки.',
   '{"answerValidation":{"kind":"BUDGET_SELECTION","budget":20,"itemPrices":{"soup":8,"juice":4,"fruits":6,"pie":4}}}')
ON CONFLICT (quest_id, step_no) DO NOTHING;

INSERT INTO shop_items (id, kind, name, price, rarity, energy_delta, joy_delta) VALUES
  ('FOOD_APPLE', 'NEED', 'Яблоко', 5, NULL, 10, 0),
  ('FOOD_CARROT', 'NEED', 'Морковка', 5, NULL, 10, 0),
  ('PET_MEAL', 'NEED', 'Обед для питомца', 10, NULL, 25, 0),
  ('TOY_BALL', 'WANT', 'Мячик', 8, NULL, 0, 20),
  ('CANDY', 'WANT', 'Конфета', 6, NULL, 0, 8),
  ('saucer', 'ARTIFACT', 'Серебряное блюдечко и наливное яблочко', 80, 'RARE', 0, 0),
  ('vial', 'ARTIFACT', 'Склянка с живой водой', 90, 'RARE', 0, 0),
  ('tablecloth', 'ARTIFACT', 'Скатерть-самобранка', 105, 'EPIC', 0, 0),
  ('horseshoe', 'ARTIFACT', 'Золотая подкова', 120, 'EPIC', 0, 0),
  ('shield', 'ARTIFACT', 'Богатырский щит', 130, 'EPIC', 0, 0),
  ('purse', 'ARTIFACT', 'Кошель-самотряс', 140, 'LEGENDARY', 0, 0),
  ('boots', 'ARTIFACT', 'Сапоги-скороходы', 150, 'LEGENDARY', 0, 0)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  price = EXCLUDED.price,
  rarity = EXCLUDED.rarity,
  energy_delta = EXCLUDED.energy_delta,
  joy_delta = EXCLUDED.joy_delta,
  active = true;

INSERT INTO quest_prerequisites (quest_id, prerequisite_quest_id)
VALUES ('Q_TUGRIKI_CURRENCY', 'Q_MOLE_FINE_PRINT'),
       ('Q_MOLE_FINE_PRINT', 'Q_TURNIP_HARVEST')
ON CONFLICT DO NOTHING;

UPDATE shop_items
   SET active = false
 WHERE kind = 'ARTIFACT'
   AND id NOT IN ('saucer', 'vial', 'tablecloth', 'horseshoe', 'shield', 'purse', 'boots');

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
