-- The Badger's park is a long-running story quest. It is intentionally kept
-- outside the rewarded quest-assignment pipeline: contributing is a choice,
-- not a way to buy a reward, and the park opens for every child.

ALTER TYPE transaction_event_type ADD VALUE 'PARK_CONTRIBUTION';

CREATE TABLE park_projects (
    id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_user_id              uuid NOT NULL UNIQUE REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    stage                      varchar(30) NOT NULL DEFAULT 'FIRST_OFFER',
    stage_completed_days       int NOT NULL,
    funded_after_completed_days int,
    child_contribution         int NOT NULL DEFAULT 0,
    first_decision             varchar(12),
    second_decision            varchar(12),
    completed_at               timestamptz,
    created_at                 timestamptz NOT NULL DEFAULT now(),
    updated_at                 timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_park_stage CHECK (
      stage IN ('FIRST_OFFER', 'WAITING_SECOND', 'SECOND_OFFER',
                'WAITING_COMMUNITY', 'FUNDED', 'COMPLETE')
    ),
    CONSTRAINT chk_park_days_nonnegative CHECK (
      stage_completed_days >= 0
      AND (funded_after_completed_days IS NULL OR funded_after_completed_days >= 0)
    ),
    CONSTRAINT chk_park_contribution CHECK (child_contribution IN (0, 8, 20)),
    CONSTRAINT chk_park_decisions CHECK (
      (first_decision IS NULL OR first_decision IN ('CONTRIBUTE', 'DECLINE'))
      AND (second_decision IS NULL OR second_decision IN ('CONTRIBUTE', 'DECLINE'))
    ),
    CONSTRAINT chk_park_funding_shape CHECK (
      (stage IN ('FUNDED', 'COMPLETE') AND funded_after_completed_days IS NOT NULL)
      OR (stage NOT IN ('FUNDED', 'COMPLETE') AND funded_after_completed_days IS NULL)
    ),
    CONSTRAINT chk_park_completion_shape CHECK (
      (stage = 'COMPLETE' AND completed_at IS NOT NULL)
      OR (stage <> 'COMPLETE' AND completed_at IS NULL)
    )
);

CREATE INDEX idx_park_projects_child_stage ON park_projects (child_user_id, stage);

-- 0017 removed UPDATE from defaults for new mutable tables.
GRANT SELECT, INSERT, UPDATE ON park_projects TO groshik_app;
