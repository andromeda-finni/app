-- Unified table for both SYSTEM quests (from quest_definitions) and PARENT
-- real-life tasks (free text set by the parent, e.g. "вынес мусор").
CREATE TABLE assignments (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_user_id               uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    period_id                   uuid REFERENCES game_periods (id) ON DELETE RESTRICT,
    origin                      assignment_origin NOT NULL,
    quest_id                    varchar(50) REFERENCES quest_definitions (id) ON DELETE RESTRICT,
    assigned_by_parent_link_id  uuid REFERENCES parent_child_links (id) ON DELETE RESTRICT,
    title                       varchar(160),
    reward_amount               int NOT NULL,
    status                      assignment_status NOT NULL DEFAULT 'AVAILABLE',
    reward_transaction_id       uuid UNIQUE REFERENCES transactions (id) ON DELETE RESTRICT,
    created_at                  timestamptz NOT NULL DEFAULT now(),
    updated_at                  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_assignment_reward_positive CHECK (reward_amount > 0),
    CONSTRAINT chk_assignment_origin_shape CHECK (
        (origin = 'SYSTEM' AND quest_id IS NOT NULL AND assigned_by_parent_link_id IS NULL)
        OR (origin = 'PARENT' AND quest_id IS NULL AND assigned_by_parent_link_id IS NOT NULL AND title IS NOT NULL)
    ),
    CONSTRAINT chk_assignment_updated_after_created CHECK (updated_at >= created_at)
);

CREATE INDEX idx_assignment_child_status ON assignments (child_user_id, status);
CREATE INDEX idx_assignment_period ON assignments (period_id, child_user_id);

-- Per-step results for SYSTEM quests only (PARENT tasks have no steps).
CREATE TABLE quest_step_progress (
    assignment_id          uuid NOT NULL REFERENCES assignments (id) ON DELETE RESTRICT,
    step_no                 smallint NOT NULL,
    outcome                  step_outcome NOT NULL,
    selected_option_code     varchar(80),
    completed_at              timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (assignment_id, step_no),
    CONSTRAINT chk_step_progress_positive CHECK (step_no > 0)
);
