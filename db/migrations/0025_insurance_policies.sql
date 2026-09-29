-- One-day voluntary protection bought during day N and settled when day N+1
-- starts. The premium is a NEED expense from SPENDABLE; a covered event never
-- creates a debt and never lowers the pet's health.
CREATE TYPE insurance_policy_status AS ENUM ('ACTIVE', 'USED', 'EXPIRED');

ALTER TYPE transaction_event_type ADD VALUE 'INSURANCE_PREMIUM';

CREATE TABLE insurance_policies (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_user_id               uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    purchased_period_id         uuid NOT NULL REFERENCES game_periods (id) ON DELETE RESTRICT,
    coverage_sequence_no        int NOT NULL,
    premium_amount              int NOT NULL DEFAULT 5,
    status                      insurance_policy_status NOT NULL DEFAULT 'ACTIVE',
    purchase_transaction_id     uuid NOT NULL UNIQUE REFERENCES transactions (id) ON DELETE RESTRICT,
    covered_event_definition_id varchar(50) REFERENCES pet_event_definitions (id) ON DELETE RESTRICT,
    purchased_at                timestamptz NOT NULL DEFAULT now(),
    resolved_at                 timestamptz,
    CONSTRAINT chk_insurance_coverage_day CHECK (coverage_sequence_no > 1),
    CONSTRAINT chk_insurance_fixed_premium CHECK (premium_amount = 5),
    CONSTRAINT chk_insurance_status_shape CHECK (
        (status = 'ACTIVE' AND covered_event_definition_id IS NULL AND resolved_at IS NULL)
        OR (status = 'USED' AND covered_event_definition_id IS NOT NULL AND resolved_at IS NOT NULL)
        OR (status = 'EXPIRED' AND covered_event_definition_id IS NULL AND resolved_at IS NOT NULL)
    )
);

-- A child can buy protection for a particular game day only once, including
-- after that day has passed. This is the server-side replay/race guard.
CREATE UNIQUE INDEX uq_insurance_child_coverage_day
    ON insurance_policies (child_user_id, coverage_sequence_no);
CREATE UNIQUE INDEX uq_insurance_active_child
    ON insurance_policies (child_user_id) WHERE status = 'ACTIVE';

GRANT SELECT, INSERT, UPDATE ON insurance_policies TO groshik_app;
