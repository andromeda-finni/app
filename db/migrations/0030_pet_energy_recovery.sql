-- Server-owned energy recovery. Partial tick progress survives application
-- restarts because the timestamp is stored next to the current energy value.
ALTER TABLE pets
    ADD COLUMN IF NOT EXISTS last_energy_tick_at timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS energy_depleted_at timestamptz;

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conname = 'chk_pet_energy_depleted_shape'
           AND conrelid = 'public.pets'::regclass
    ) THEN
        ALTER TABLE pets
            ADD CONSTRAINT chk_pet_energy_depleted_shape
            CHECK (energy_depleted_at IS NULL OR energy_level = 0);
    END IF;
END
$migration$;
