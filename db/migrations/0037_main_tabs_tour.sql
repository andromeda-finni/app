-- The map, shop and savings tour is versioned separately from the original
-- home tour so children who already learned the Home screen still see the
-- newly added guidance once.
ALTER TABLE child_profiles
    ADD COLUMN main_tabs_tour_completed_at timestamptz;

GRANT UPDATE (main_tabs_tour_completed_at, updated_at)
    ON child_profiles TO groshik_app;
