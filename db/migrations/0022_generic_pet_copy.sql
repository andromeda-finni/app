-- Child-selected pet names must not be replaced by the old prototype name in
-- persisted demo content. Copy that does not have a live pet context stays
-- deliberately generic; runtime feedback that does have the pet row uses its
-- actual pet_name in the backend.
UPDATE quest_steps
   SET instruction = 'У тебя есть 30 монет. Сколько лучше отложить на нужное — еду для питомца?'
 WHERE quest_id = 'Q_FIRST_BUDGET'
   AND step_no = 1;

UPDATE pet_event_definitions
   SET title = CASE id
       WHEN 'SICK' THEN 'Питомец заболел'
       WHEN 'HUNGRY' THEN 'Питомец проголодался'
       ELSE title
   END
 WHERE id IN ('SICK', 'HUNGRY');
