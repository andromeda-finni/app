-- Onboarding completion is a separate fact from pet existence. A child may
-- create a pet on step 1 and close the app before seeing the tutorial, so the
-- server must persist the next required step explicitly.
ALTER TABLE child_profiles
    ADD COLUMN onboarding_step smallint NOT NULL DEFAULT 1,
    ADD COLUMN onboarding_completed_at timestamptz,
    ADD CONSTRAINT chk_child_onboarding_step CHECK (onboarding_step BETWEEN 1 AND 4);

-- This project has not been deployed yet. Existing development profiles that
-- already own a pet are known to have completed at least step 1, but there is
-- no trustworthy evidence that they saw steps 2-4. Resume them at step 2.
UPDATE child_profiles cp
   SET onboarding_step = 2,
       updated_at = now()
 WHERE EXISTS (SELECT 1 FROM pets p WHERE p.child_user_id = cp.user_id);

-- 0017 removed UPDATE from child_profiles. The app only needs to advance
-- these two onboarding fields and the existing freshness timestamp.
GRANT UPDATE (onboarding_step, onboarding_completed_at, updated_at)
    ON child_profiles TO groshik_app;
