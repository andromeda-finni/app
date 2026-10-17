-- The tutorial budget from onboarding step 3 becomes the child's first real
-- game day: its ten coins are granted and the same split is confirmed as that
-- day's plan. The split is stored when step 3 is completed so a child who
-- closes the app before step 4 still gets the plan they actually chose.
ALTER TABLE child_profiles
    ADD COLUMN tutorial_need_amount smallint,
    ADD COLUMN tutorial_want_amount smallint,
    ADD COLUMN tutorial_savings_amount smallint,
    ADD CONSTRAINT chk_child_tutorial_plan CHECK (
        (tutorial_need_amount IS NULL
            AND tutorial_want_amount IS NULL
            AND tutorial_savings_amount IS NULL)
        OR (tutorial_need_amount >= 0
            AND tutorial_want_amount >= 0
            AND tutorial_savings_amount >= 0
            AND tutorial_need_amount + tutorial_want_amount + tutorial_savings_amount = 10)
    );

GRANT UPDATE (tutorial_need_amount, tutorial_want_amount, tutorial_savings_amount)
    ON child_profiles TO groshik_app;
