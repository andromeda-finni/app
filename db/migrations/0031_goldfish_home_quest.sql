-- Four independently rewarded levels for "Золотая рыбка. Обустрой домик".
-- The client sends selected item ids; the server validates needs, budget and
-- the final level's minimum reserve before issuing an idempotent reward.

INSERT INTO quest_definitions
  (id, topic_id, title, character_code, location_code, difficulty, reward_amount)
VALUES
  ('Q_GOLDFISH_HOME_SIMPLE_1', 'BUDGETING', 'Обустрой домик: самое необходимое', 'GOLDFISH', 'SEASIDE_HOUSE', 'SIMPLE', 10),
  ('Q_GOLDFISH_HOME_SIMPLE_2', 'BUDGETING', 'Обустрой домик: готовимся к холодам', 'GOLDFISH', 'SEASIDE_HOUSE', 'SIMPLE', 10),
  ('Q_GOLDFISH_HOME_ADVANCED_1', 'BUDGETING', 'Обустрой домик: красиво или разумно', 'GOLDFISH', 'SEASIDE_HOUSE', 'ADVANCED', 12),
  ('Q_GOLDFISH_HOME_ADVANCED_2', 'BUDGETING', 'Обустрой домик: запас на зиму', 'GOLDFISH', 'SEASIDE_HOUSE', 'ADVANCED', 15)
ON CONFLICT (id) DO UPDATE SET
  reward_amount = EXCLUDED.reward_amount,
  title = EXCLUDED.title,
  difficulty = EXCLUDED.difficulty,
  active = true;

INSERT INTO quest_steps
  (quest_id, step_no, instruction, expected_action_code, success_feedback, recovery_feedback, ui_spec)
VALUES
  ('Q_GOLDFISH_HOME_SIMPLE_1', 1,
   'Купи крышу, кровать и окно, не превышая бюджет 12 монет.',
   'SELECT_GOODS',
   'Все обязательные вещи куплены, бюджет соблюдён.',
   'Сначала выбери крышу, кровать и окно.',
   '{"gameId":"goldfish","answerValidation":{"kind":"REQUIRED_BUDGET_SELECTION","budget":12,"itemPrices":{"roof_basic":5,"roof_ornate":8,"bed_basic":4,"bed_ornate":7,"window_basic":3,"window_ornate":6},"requiredGroups":[{"label":"крыша","itemIds":["roof_basic","roof_ornate"]},{"label":"кровать","itemIds":["bed_basic","bed_ornate"]},{"label":"окно","itemIds":["window_basic","window_ornate"]}]}}'),
  ('Q_GOLDFISH_HOME_SIMPLE_2', 1,
   'Подготовь домик к холодам в рамках бюджета 14 монет.',
   'SELECT_GOODS',
   'Крыша, окно и тёплая вещь выбраны, бюджет соблюдён.',
   'Проверь крышу, окно и тёплую вещь.',
   '{"gameId":"goldfish","answerValidation":{"kind":"REQUIRED_BUDGET_SELECTION","budget":14,"itemPrices":{"roof_basic":5,"roof_ornate":8,"blanket_down":4,"cover_silk":7,"window_basic":3,"window_ornate":5,"lollipop":2,"vase_basic":3},"requiredGroups":[{"label":"крыша","itemIds":["roof_basic","roof_ornate"]},{"label":"тёплая вещь","itemIds":["blanket_down"]},{"label":"окно","itemIds":["window_basic","window_ornate"]}]}}'),
  ('Q_GOLDFISH_HOME_ADVANCED_1', 1,
   'Закрой четыре потребности и не превысь бюджет 17 монет.',
   'SELECT_GOODS',
   'Разумное сочетание покупок найдено.',
   'Нужны крыша, кровать, окно и тёплая вещь.',
   '{"gameId":"goldfish","answerValidation":{"kind":"REQUIRED_BUDGET_SELECTION","budget":17,"itemPrices":{"roof_basic":5,"roof_ornate":7,"bed_basic":4,"bed_ornate":6,"window_basic":3,"window_ornate":5,"blanket_down":3,"blanket_ornate":5,"frame_gold":3,"vase_basic":2},"requiredGroups":[{"label":"крыша","itemIds":["roof_basic","roof_ornate"]},{"label":"кровать","itemIds":["bed_basic","bed_ornate"]},{"label":"окно","itemIds":["window_basic","window_ornate"]},{"label":"тёплая вещь","itemIds":["blanket_down","blanket_ornate"]}]}}'),
  ('Q_GOLDFISH_HOME_ADVANCED_2', 1,
   'Купи всё необходимое из 20 монет и оставь минимум 3 монеты в запасе.',
   'SELECT_GOODS',
   'Дом обустроен, а запас на зиму сохранён.',
   'Проверь обязательные вещи и оставь минимум 3 монеты.',
   '{"gameId":"goldfish","answerValidation":{"kind":"REQUIRED_BUDGET_SELECTION","budget":20,"minimumRemaining":3,"itemPrices":{"bed_basic":4,"bed_ornate":7,"roof_basic":4,"roof_ornate":7,"window_basic":3,"window_ornate":5,"shawl_down":3,"shawl_ornate":5,"lamp":3,"music_box":5,"vase_gold":6},"requiredGroups":[{"label":"кровать","itemIds":["bed_basic","bed_ornate"]},{"label":"крыша","itemIds":["roof_basic","roof_ornate"]},{"label":"окно","itemIds":["window_basic","window_ornate"]},{"label":"тёплая вещь","itemIds":["shawl_down","shawl_ornate"]}]}}')
ON CONFLICT (quest_id, step_no) DO UPDATE SET
  instruction = EXCLUDED.instruction,
  success_feedback = EXCLUDED.success_feedback,
  recovery_feedback = EXCLUDED.recovery_feedback,
  ui_spec = EXCLUDED.ui_spec;

INSERT INTO quest_prerequisites (quest_id, prerequisite_quest_id)
VALUES
  ('Q_GOLDFISH_HOME_SIMPLE_1', 'Q_IVAN_ROAD_EASY_2'),
  ('Q_GOLDFISH_HOME_SIMPLE_2', 'Q_GOLDFISH_HOME_SIMPLE_1'),
  ('Q_GOLDFISH_HOME_ADVANCED_1', 'Q_IVAN_ROAD_HARD_2'),
  ('Q_GOLDFISH_HOME_ADVANCED_2', 'Q_GOLDFISH_HOME_ADVANCED_1')
ON CONFLICT DO NOTHING;
