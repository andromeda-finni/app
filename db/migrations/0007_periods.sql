-- Up to 7 active-day budgeting cycle.
CREATE TABLE game_periods (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_user_id          uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    sequence_no            int NOT NULL,
    status                 period_status NOT NULL DEFAULT 'ACTIVE',
    required_need_amount   int NOT NULL,
    opening_spendable      int NOT NULL,
    opening_savings        int NOT NULL,
    opening_frozen         int NOT NULL DEFAULT 0,
    opened_at              timestamptz NOT NULL DEFAULT now(),
    closed_at              timestamptz,
    CONSTRAINT chk_period_sequence_positive CHECK (sequence_no > 0),
    CONSTRAINT chk_period_amounts_nonnegative CHECK (
        required_need_amount >= 0 AND opening_spendable >= 0 AND opening_savings >= 0 AND opening_frozen >= 0
    ),
    CONSTRAINT chk_period_status_dates CHECK (
        (status = 'ACTIVE' AND closed_at IS NULL) OR (status = 'COMPLETED' AND closed_at IS NOT NULL AND closed_at > opened_at)
    )
);

CREATE UNIQUE INDEX uq_period_child_sequence ON game_periods (child_user_id, sequence_no);
-- Only one ACTIVE period per child.
CREATE UNIQUE INDEX uq_period_active_child ON game_periods (child_user_id) WHERE status = 'ACTIVE';

CREATE TABLE budget_plans (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    period_id           uuid NOT NULL UNIQUE REFERENCES game_periods (id) ON DELETE RESTRICT,
    child_user_id       uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    status              plan_status NOT NULL DEFAULT 'DRAFT',
    available_amount    int NOT NULL,
    need_amount         int NOT NULL DEFAULT 0,
    want_amount         int NOT NULL DEFAULT 0,
    savings_amount      int NOT NULL DEFAULT 0,
    created_at          timestamptz NOT NULL DEFAULT now(),
    confirmed_at        timestamptz,
    CONSTRAINT chk_plan_amounts_nonnegative CHECK (
        available_amount >= 0 AND need_amount >= 0 AND want_amount >= 0 AND savings_amount >= 0
    ),
    CONSTRAINT chk_plan_fully_allocated CHECK (
        status = 'DRAFT' OR need_amount + want_amount + savings_amount = available_amount
    ),
    CONSTRAINT chk_plan_status_dates CHECK (
        (status = 'DRAFT' AND confirmed_at IS NULL) OR (status = 'CONFIRMED' AND confirmed_at IS NOT NULL)
    )
);

-- Slim, queryable summary of a closed period; replaces the original ~25-column
-- immutable snapshot table with just what the results/history screen needs.
CREATE TABLE period_results (
    period_id                uuid PRIMARY KEY REFERENCES game_periods (id) ON DELETE RESTRICT,
    child_user_id             uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    need_covered              boolean NOT NULL,
    plan_followed             boolean NOT NULL,
    actual_need_amount        int NOT NULL DEFAULT 0,
    actual_want_amount        int NOT NULL DEFAULT 0,
    net_savings_contribution  int NOT NULL DEFAULT 0,
    pet_stage_before           smallint NOT NULL,
    pet_stage_after            smallint NOT NULL,
    feedback_text              varchar(500) NOT NULL,
    calculated_at              timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_result_pet_stage_range CHECK (pet_stage_before BETWEEN 1 AND 3 AND pet_stage_after BETWEEN 1 AND 3)
);
