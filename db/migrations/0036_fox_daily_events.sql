ALTER TYPE transaction_event_type ADD VALUE 'FOX_EVENT';

-- A failed roll is saved too: reopening Home cannot reroll the same day.
CREATE TABLE fox_event_states (
    child_user_id uuid PRIMARY KEY REFERENCES child_profiles(user_id) ON DELETE RESTRICT,
    state jsonb NOT NULL DEFAULT '{"lastRollDay":0,"completedScriptIds":[],"session":null}',
    updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON fox_event_states TO groshik_app;
