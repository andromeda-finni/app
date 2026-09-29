-- The home tour follows the four-step story onboarding, but is tracked
-- separately so existing children see the new explanation exactly once.
ALTER TABLE child_profiles
    ADD COLUMN home_tour_completed_at timestamptz;

GRANT UPDATE (home_tour_completed_at, updated_at)
    ON child_profiles TO groshik_app;
