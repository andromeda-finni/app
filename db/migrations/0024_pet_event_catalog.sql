-- Keep the random-event catalog in the database aligned with the approved
-- child-facing copy. Existing ACTIVE occurrences retain their identity but
-- receive the approved price so a restart cannot surface stale prototype
-- amounts or wording.
INSERT INTO pet_event_definitions
  (id, title, description, cost_amount, trigger_weight, active)
VALUES
  ('POOR_PAW', 'Уколол лапку', 'Финни бегал по лесу за бабочкой и наступил на колючку. Нужен целебный подорожник и бинтик.', 10, 10, true),
  ('SICK', 'Питомец простудился', 'На полянке прошел холодный дождь, Финни чихает и дрожит. Нужен липовый мед и теплый шарфик.', 15, 10, true),
  ('HUNGRY', 'Внезапный аппетит', 'Запасы орехов кончились, а после активных игр в лесу Финни очень проголодался. Нужна горячая похлебка.', 10, 10, true),
  ('COLD_NIGHT', 'Печка остыла', 'Ночью обещают лесные заморозки. Нужна охапка сухих дров у Дровосека, чтобы в домике было тепло.', 8, 10, true),
  ('ROOF_LEAK', 'Прохудилась крыша', 'Ночью сильный ветер сдул пару веток с крыши, и теперь капает на пол. Нужна смола и береста для ремонта.', 14, 10, true),
  ('BEAVER_DAM', 'Лесной сбор Бобру', 'Бобры укрепили плотину и починили мостик к Лесной Ярмарке. Все жители леса сдают монетки на общее дело.', 7, 10, true)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  cost_amount = EXCLUDED.cost_amount,
  active = EXCLUDED.active;

UPDATE pet_event_definitions
   SET active = false
 WHERE id NOT IN ('POOR_PAW', 'SICK', 'HUNGRY', 'COLD_NIGHT', 'ROOF_LEAK', 'BEAVER_DAM');

UPDATE pet_event_occurrences peo
   SET amount_due = ped.cost_amount
  FROM pet_event_definitions ped
 WHERE peo.event_definition_id = ped.id
   AND peo.status = 'ACTIVE';

-- Repair legacy active occurrences created before the health effect became
-- atomic. Preserve genuinely lower health, but keep the humane 10% floor.
UPDATE pets p
   SET health_level = GREATEST(10, LEAST(55, p.health_level)),
       updated_at = now()
 WHERE EXISTS (
   SELECT 1
     FROM pet_event_occurrences peo
    WHERE peo.pet_id = p.id AND peo.status = 'ACTIVE'
 );
