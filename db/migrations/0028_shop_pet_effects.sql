-- Everyday purchases must visibly care for the pet. Effects belong to catalog
-- data rather than route code, so new items can be balanced without adding
-- item-id conditionals to the API.
ALTER TABLE shop_items
  ADD COLUMN energy_delta smallint NOT NULL DEFAULT 0,
  ADD COLUMN joy_delta smallint NOT NULL DEFAULT 0,
  ADD CONSTRAINT chk_shop_energy_delta_range CHECK (energy_delta BETWEEN -100 AND 100),
  ADD CONSTRAINT chk_shop_joy_delta_range CHECK (joy_delta BETWEEN -100 AND 100);

UPDATE shop_items
   SET energy_delta = CASE id
     WHEN 'FOOD_APPLE' THEN 10
     WHEN 'FOOD_CARROT' THEN 10
     WHEN 'PET_MEAL' THEN 25
     ELSE energy_delta
   END,
       joy_delta = CASE id
     WHEN 'TOY_BALL' THEN 20
     WHEN 'CANDY' THEN 8
     ELSE joy_delta
   END
 WHERE id IN ('FOOD_APPLE', 'FOOD_CARROT', 'PET_MEAL', 'TOY_BALL', 'CANDY');
