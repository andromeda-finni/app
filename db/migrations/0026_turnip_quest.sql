-- Content for the v0.3 mini-game "Репка", the first stop on the quest map.
-- The Flutter client owns the drag-and-drop interaction; this row lets the
-- server start the assignment, verify the harvest, and pay the reward once.

INSERT INTO education_topics (id, title, skill_description, sort_order)
VALUES (
  'INCOME',
  'Откуда берутся деньги',
  'Учимся понимать, что доход появляется из общего труда',
  6
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO quest_definitions
  (id, topic_id, title, character_code, location_code, difficulty, reward_amount)
VALUES (
  'Q_TURNIP_HARVEST',
  'INCOME',
  'Репка',
  'GRANDFATHER',
  'VILLAGE',
  'SIMPLE',
  10
)
-- 10 is the base step of the economy's quest reward scale (10/12/15).
ON CONFLICT (id) DO UPDATE SET reward_amount = EXCLUDED.reward_amount;

INSERT INTO quest_steps
  (quest_id, step_no, instruction, expected_action_code, success_feedback, recovery_feedback, ui_spec)
VALUES
  ('Q_TURNIP_HARVEST', 1,
   'Расставь помощников за Дедушкой и вытяните репку вместе.',
   'ARRANGE_AND_VERIFY',
   'Вместе вытянули репку! Урожай поедет на ярмарку.',
   'Попробуй поставить героев по росту.',
   '{"correctOptionCode":"VERIFIED","gameId":"turnip"}')
ON CONFLICT DO NOTHING;

-- The map opens from the village: the mole's market comes after the harvest.
INSERT INTO quest_prerequisites (quest_id, prerequisite_quest_id)
SELECT 'Q_MOLE_FINE_PRINT', 'Q_TURNIP_HARVEST'
 WHERE EXISTS (SELECT 1 FROM quest_definitions WHERE id = 'Q_MOLE_FINE_PRINT')
ON CONFLICT DO NOTHING;
