-- The pet screen shows three stats. Two already existed (energy_level as
-- "Сытость", joy_level as "Радость"); health had nowhere to live.
--
-- It is not a decorative third bar: a pet event (illness, see
-- pet_event_definitions) is exactly the moment the pet stops being well, and
-- paying the bill is what makes it well again. This column gives that
-- mechanic somewhere to land instead of leaving the event invisible until the
-- child happens to open the events list.
ALTER TABLE pets
    ADD COLUMN health_level smallint NOT NULL DEFAULT 100,
    ADD CONSTRAINT chk_pet_health_range CHECK (health_level BETWEEN 0 AND 100);
