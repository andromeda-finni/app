-- Catalog of random pet events (sickness, hunger, ...). Resolved only by paying
-- the cost: from SPENDABLE first, then SAVINGS if SPENDABLE is short.
CREATE TABLE pet_event_definitions (
    id               varchar(50) PRIMARY KEY,
    title            varchar(120) NOT NULL,
    description      varchar(300) NOT NULL,
    cost_amount      int NOT NULL,
    trigger_weight   int NOT NULL DEFAULT 10,
    active           boolean NOT NULL DEFAULT true,
    CONSTRAINT chk_pet_event_cost_positive CHECK (cost_amount > 0),
    CONSTRAINT chk_pet_event_weight_positive CHECK (trigger_weight > 0)
);

CREATE TABLE pet_event_occurrences (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_user_id          uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    pet_id                 uuid NOT NULL REFERENCES pets (id) ON DELETE RESTRICT,
    event_definition_id    varchar(50) NOT NULL REFERENCES pet_event_definitions (id) ON DELETE RESTRICT,
    period_id              uuid REFERENCES game_periods (id) ON DELETE RESTRICT,
    status                 pet_event_status NOT NULL DEFAULT 'ACTIVE',
    amount_due             int NOT NULL,
    spendable_transaction_id  uuid UNIQUE REFERENCES transactions (id) ON DELETE RESTRICT,
    savings_transaction_id    uuid UNIQUE REFERENCES transactions (id) ON DELETE RESTRICT,
    triggered_at             timestamptz NOT NULL DEFAULT now(),
    resolved_at               timestamptz,
    CONSTRAINT chk_pet_event_amount_positive CHECK (amount_due > 0),
    CONSTRAINT chk_pet_event_status_shape CHECK (
        (status = 'ACTIVE' AND resolved_at IS NULL)
        OR (status = 'RESOLVED' AND resolved_at IS NOT NULL AND spendable_transaction_id IS NOT NULL)
    )
);

-- At most one unresolved event per pet at a time.
CREATE UNIQUE INDEX uq_pet_event_active_pet ON pet_event_occurrences (pet_id) WHERE status = 'ACTIVE';
CREATE INDEX idx_pet_event_child_status ON pet_event_occurrences (child_user_id, status);
