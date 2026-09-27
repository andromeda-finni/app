-- "Внимательный покупатель": the client runs two visual stages and reports
-- the completed story once. The server remains the only authority that pays.

INSERT INTO quest_definitions
  (id, topic_id, title, character_code, location_code, difficulty, reward_amount)
VALUES
  ('Q_SQUIRREL_QUALITY_SIMPLE', 'CONSUMER_RIGHTS',
   'Внимательный покупатель', 'SQUIRREL', 'FOREST_MARKET', 'SIMPLE', 10),
  ('Q_SQUIRREL_QUALITY_ADVANCED', 'CONSUMER_RIGHTS',
   'Внимательный покупатель', 'SQUIRREL', 'FOREST_MARKET', 'ADVANCED', 12)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  character_code = EXCLUDED.character_code,
  location_code = EXCLUDED.location_code,
  reward_amount = EXCLUDED.reward_amount,
  active = true;

INSERT INTO quest_steps
  (quest_id, step_no, instruction, expected_action_code,
   success_feedback, recovery_feedback, ui_spec)
VALUES
  ('Q_SQUIRREL_QUALITY_SIMPLE', 1,
   'Выбери для зимних запасов только свежие грибы, ягоды и орехи.',
   'COMPLETE_STORY',
   'Все запасы свежие, а монеты потрачены мудро.',
   'Проверяй каждый товар перед покупкой.',
   '{"correctOptionCode":"VERIFIED","mode":"simple"}'),
  ('Q_SQUIRREL_QUALITY_ADVANCED', 1,
   'Собери список покупок в рамках бюджета и осмотри товары со всех сторон.',
   'COMPLETE_STORY',
   'Список собран, все товары проверены, бюджет соблюдён.',
   'Не доверяй первому впечатлению: осмотри товар и сверься со списком.',
   '{"correctOptionCode":"VERIFIED","mode":"advanced"}')
ON CONFLICT (quest_id, step_no) DO UPDATE SET
  instruction = EXCLUDED.instruction,
  success_feedback = EXCLUDED.success_feedback,
  recovery_feedback = EXCLUDED.recovery_feedback,
  ui_spec = EXCLUDED.ui_spec;

-- The simple route follows the already available "fine print" lesson. The
-- advanced profile has its own independent version and is not blocked by a
-- SIMPLE-only quest that does not appear in its catalogue.
INSERT INTO quest_prerequisites (quest_id, prerequisite_quest_id)
VALUES ('Q_SQUIRREL_QUALITY_SIMPLE', 'Q_MOLE_FINE_PRINT')
ON CONFLICT DO NOTHING;
