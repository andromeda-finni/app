-- Rewarded mini-games submit the educational result itself, not a generic
-- "VERIFIED" flag. Validation remains server-owned and data-driven so adding
-- a new quest does not require another route-level special case.

UPDATE quest_steps
   SET ui_spec = jsonb_set(ui_spec, '{correctOptionCode}', '"12"'::jsonb, true)
 WHERE quest_id = 'Q_MOLE_FINE_PRINT' AND step_no = 1;

UPDATE quest_steps
   SET ui_spec = jsonb_set(ui_spec, '{correctOptionCode}', '"9"'::jsonb, true)
 WHERE quest_id = 'Q_MOLE_FINE_PRINT' AND step_no = 2;

UPDATE quest_steps
   SET ui_spec = jsonb_set(ui_spec, '{correctOptionCode}', '"ask"'::jsonb, true)
 WHERE quest_id = 'Q_MOLE_FINE_PRINT' AND step_no = 3;

UPDATE quest_steps
   SET ui_spec = jsonb_set(ui_spec, '{correctOptionCode}', '"19"'::jsonb, true)
 WHERE quest_id = 'Q_MOLE_FINE_PRINT' AND step_no = 4;

UPDATE quest_steps
   SET ui_spec = jsonb_set(ui_spec, '{correctOptionCode}', '"seller"'::jsonb, true)
 WHERE quest_id = 'Q_MOLE_FINE_PRINT' AND step_no = 5;

UPDATE quest_steps
   SET ui_spec = (ui_spec - 'correctOptionCode') || jsonb_build_object(
     'answerValidation', jsonb_build_object(
       'kind', 'ORDERED_SEQUENCE',
       'expectedSequence', jsonb_build_array(
         'grandmother', 'granddaughter', 'zhuchka', 'cat', 'mouse'
       )
     )
   )
 WHERE quest_id = 'Q_TURNIP_HARVEST' AND step_no = 1;

UPDATE quest_steps
   SET ui_spec = (ui_spec - 'correctOptionCode') || jsonb_build_object(
     'answerValidation', jsonb_build_object(
       'kind', 'BUDGET_SELECTION',
       'budget', 20,
       'itemPrices', jsonb_build_object(
         'soup', 8,
         'juice', 4,
         'fruits', 6,
         'pie', 4
       )
     )
   )
 WHERE quest_id = 'Q_TUGRIKI_CURRENCY' AND step_no = 1;
