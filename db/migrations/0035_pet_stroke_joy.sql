-- Stroking the pet raises joy by half a point, with each stroke of a rapid
-- series worth 10% less than the one before. joy_level stays an integer for
-- every existing reader; the sub-point remainder accumulates separately.
ALTER TABLE pets
    ADD COLUMN joy_fraction numeric(6, 5) NOT NULL DEFAULT 0,
    ADD COLUMN stroke_streak integer NOT NULL DEFAULT 0,
    ADD COLUMN last_stroked_at timestamptz,
    ADD CONSTRAINT chk_pet_joy_fraction_range CHECK (joy_fraction >= 0 AND joy_fraction < 1),
    ADD CONSTRAINT chk_pet_stroke_streak_nonnegative CHECK (stroke_streak >= 0);
