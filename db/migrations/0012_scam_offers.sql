-- "Вредные советы": a sly NPC periodically offers a too-good-to-be-true deal
-- (e.g. "отдай все монеты сейчас — получишь вдвое больше завтра!"). Teaches
-- scam recognition: DECLINE is (almost always) the right answer. Modeled the
-- same way as pet_event_occurrences (definitions catalog + occurrence instance).

CREATE TYPE scam_offer_status AS ENUM ('ACTIVE', 'RESOLVED', 'EXPIRED');
CREATE TYPE scam_offer_decision AS ENUM ('ACCEPTED', 'DECLINED');

-- New ledger event for the cost paid when a child falls for a scam offer.
ALTER TYPE transaction_event_type ADD VALUE 'SCAM_OFFER_LOSS';

CREATE TABLE scam_offer_definitions (
    id                     varchar(50) PRIMARY KEY,
    npc_character_code     varchar(40) NOT NULL DEFAULT 'SLY_FOX',
    pitch_text             varchar(500) NOT NULL,
    promised_amount        int NOT NULL,
    cost_if_accepted       int NOT NULL,
    decline_feedback       varchar(500) NOT NULL,
    accept_feedback        varchar(500) NOT NULL,
    trigger_weight         int NOT NULL DEFAULT 10,
    active                 boolean NOT NULL DEFAULT true,
    CONSTRAINT chk_scam_offer_amounts_positive CHECK (promised_amount > 0 AND cost_if_accepted > 0),
    CONSTRAINT chk_scam_offer_weight_positive CHECK (trigger_weight > 0)
);

-- Accepting never actually pays out the promised_amount (it is a scam) — it
-- only costs cost_if_accepted, taken from SPENDABLE. This is the comedic,
-- non-punishing consequence: the child loses a small, bounded amount and gets
-- an explanatory nudge, never a wipe-out.
CREATE TABLE scam_offer_occurrences (
    id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_user_id             uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    period_id                 uuid REFERENCES game_periods (id) ON DELETE RESTRICT,
    offer_definition_id       varchar(50) NOT NULL REFERENCES scam_offer_definitions (id) ON DELETE RESTRICT,
    status                    scam_offer_status NOT NULL DEFAULT 'ACTIVE',
    decision                  scam_offer_decision,
    cost_transaction_id       uuid UNIQUE REFERENCES transactions (id) ON DELETE RESTRICT,
    triggered_at               timestamptz NOT NULL DEFAULT now(),
    resolved_at                 timestamptz,
    CONSTRAINT chk_scam_offer_status_shape CHECK (
        (status = 'ACTIVE' AND decision IS NULL AND resolved_at IS NULL)
        OR (status = 'RESOLVED' AND decision IS NOT NULL AND resolved_at IS NOT NULL
            AND ((decision = 'DECLINED' AND cost_transaction_id IS NULL)
                 OR (decision = 'ACCEPTED' AND cost_transaction_id IS NOT NULL)))
        OR (status = 'EXPIRED' AND decision IS NULL AND resolved_at IS NOT NULL AND cost_transaction_id IS NULL)
    )
);

CREATE UNIQUE INDEX uq_scam_offer_active_child ON scam_offer_occurrences (child_user_id) WHERE status = 'ACTIVE';
CREATE INDEX idx_scam_offer_child_status ON scam_offer_occurrences (child_user_id, status);
