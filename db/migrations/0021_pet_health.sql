-- The pet screen shows three stats. Two already existed (energy_level as
-- "Сытость", joy_level as "Радость"); health had nowhere to live.
--
-- IF NOT EXISTS keeps this migration compatible with developer databases that
-- briefly applied the pre-merge file named 0020_pet_health.sql. The migration
-- runner tracks full filenames, so those databases still need this canonical
-- 0021 marker without attempting to recreate the column or constraint.
ALTER TABLE pets
    ADD COLUMN IF NOT EXISTS health_level smallint NOT NULL DEFAULT 100;

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conname = 'chk_pet_health_range'
           AND conrelid = 'public.pets'::regclass
    ) THEN
        ALTER TABLE pets
            ADD CONSTRAINT chk_pet_health_range
            CHECK (health_level BETWEEN 0 AND 100);
    END IF;
END
$migration$;
