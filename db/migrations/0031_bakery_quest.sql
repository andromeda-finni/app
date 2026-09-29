-- The bakery teaches the difference between revenue, expenses and profit.
-- Advanced guidance earns the top quest reward while the shared quest id keeps
-- progression and replay protection identical for both difficulty settings.

ALTER TABLE quest_definitions
  ADD COLUMN advanced_reward_amount int,
  ADD CONSTRAINT chk_quest_advanced_reward_positive
    CHECK (advanced_reward_amount IS NULL OR advanced_reward_amount > 0);

INSERT INTO education_topics (id, title, skill_description, sort_order)
VALUES (
  'PROFIT',
  'Выручка и прибыль',
  'Учимся вычитать расходы из выручки и отличать прибыль от денег в кошельке',
  7
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  skill_description = EXCLUDED.skill_description;

INSERT INTO quest_definitions
  (id, topic_id, title, character_code, location_code, difficulty,
   reward_amount, advanced_reward_amount)
VALUES (
  'Q_BAKERY_PROFIT',
  'PROFIT',
  'Пекарня',
  'BAKER',
  'TOWN',
  'SIMPLE',
  12,
  15
)
ON CONFLICT (id) DO UPDATE SET
  reward_amount = EXCLUDED.reward_amount,
  advanced_reward_amount = EXCLUDED.advanced_reward_amount,
  title = EXCLUDED.title,
  location_code = EXCLUDED.location_code;

INSERT INTO quest_steps
  (quest_id, step_no, instruction, expected_action_code,
   success_feedback, recovery_feedback, ui_spec)
VALUES (
  'Q_BAKERY_PROFIT',
  1,
  'Купи продукты, продай пирожки и вычисли прибыль после расходов.',
  'COMPLETE_STORY',
  'Верно: прибыль — это выручка за вычетом расходов.',
  'Вычти из выручки все купленные продукты, включая необязательные.',
  '{"answerValidation":{"kind":"ONE_OF","acceptedOptions":["8","2"]},"gameId":"bakery"}'
)
ON CONFLICT (quest_id, step_no) DO UPDATE SET
  instruction = EXCLUDED.instruction,
  expected_action_code = EXCLUDED.expected_action_code,
  success_feedback = EXCLUDED.success_feedback,
  recovery_feedback = EXCLUDED.recovery_feedback,
  ui_spec = EXCLUDED.ui_spec;

INSERT INTO quest_prerequisites (quest_id, prerequisite_quest_id)
VALUES ('Q_BAKERY_PROFIT', 'Q_MOLE_FINE_PRINT')
ON CONFLICT DO NOTHING;

DELETE FROM quest_prerequisites
 WHERE quest_id = 'Q_TUGRIKI_CURRENCY'
   AND prerequisite_quest_id = 'Q_MOLE_FINE_PRINT';

INSERT INTO quest_prerequisites (quest_id, prerequisite_quest_id)
SELECT 'Q_TUGRIKI_CURRENCY', 'Q_BAKERY_PROFIT'
 WHERE EXISTS (
   SELECT 1 FROM quest_definitions WHERE id = 'Q_TUGRIKI_CURRENCY'
 )
ON CONFLICT DO NOTHING;
