ALTER TABLE inventory_items
    ADD COLUMN durability_current int NOT NULL DEFAULT 100,
    ADD COLUMN durability_max int NOT NULL DEFAULT 100,
    ADD COLUMN is_broken boolean NOT NULL DEFAULT false;

ALTER TABLE inventory_items
    ADD CONSTRAINT chk_durability
        CHECK (
            durability_max > 0
            AND durability_current >= 0
            AND durability_current <= durability_max
        ),
    ADD CONSTRAINT chk_broken_matches_durability
        CHECK (is_broken = (durability_current = 0));

-- Living water is a refillable single-use artifact. Existing inventory rows
-- must use the same 1/1 durability model as newly redeemed vials.
UPDATE inventory_items
SET durability_current = 1,
    durability_max = 1,
    is_broken = false
WHERE item_id = 'vial';

ALTER TABLE shop_items
    ADD COLUMN repair_cost_per_point numeric(5,2) NOT NULL DEFAULT 0.20,
    ADD CONSTRAINT chk_repair_cost_nonnegative
        CHECK (repair_cost_per_point >= 0);

-- A blocked scam remains an ACCEPTED decision (the child did press the risky
-- button), but no money leaves the wallet. Keeping the blocking inventory id
-- makes that outcome auditable without inventing a second ledger movement.
ALTER TABLE scam_offer_occurrences
    ADD COLUMN blocked_by_inventory_item_id uuid
        REFERENCES inventory_items (id) ON DELETE RESTRICT;

ALTER TABLE scam_offer_occurrences
    DROP CONSTRAINT chk_scam_offer_status_shape;

ALTER TABLE scam_offer_occurrences
    ADD CONSTRAINT chk_scam_offer_status_shape CHECK (
        (status = 'ACTIVE' AND decision IS NULL AND resolved_at IS NULL
            AND cost_transaction_id IS NULL AND blocked_by_inventory_item_id IS NULL)
        OR (status = 'RESOLVED' AND decision IS NOT NULL AND resolved_at IS NOT NULL
            AND (
                (decision = 'DECLINED' AND cost_transaction_id IS NULL
                    AND blocked_by_inventory_item_id IS NULL)
                OR (decision = 'ACCEPTED' AND (
                    (cost_transaction_id IS NOT NULL AND blocked_by_inventory_item_id IS NULL)
                    OR (cost_transaction_id IS NULL AND blocked_by_inventory_item_id IS NOT NULL)
                ))
            ))
        OR (status = 'EXPIRED' AND decision IS NULL AND resolved_at IS NOT NULL
            AND cost_transaction_id IS NULL AND blocked_by_inventory_item_id IS NULL)
    );

ALTER TABLE pet_event_occurrences
    ADD COLUMN prevented_by_inventory_item_id uuid
        REFERENCES inventory_items (id) ON DELETE RESTRICT;

ALTER TABLE pet_event_occurrences
    DROP CONSTRAINT chk_pet_event_status_shape;

ALTER TABLE pet_event_occurrences
    ADD CONSTRAINT chk_pet_event_status_shape CHECK (
        (status = 'ACTIVE' AND resolved_at IS NULL
            AND prevented_by_inventory_item_id IS NULL)
        OR (status = 'RESOLVED' AND resolved_at IS NOT NULL AND (
            ((spendable_transaction_id IS NOT NULL
                OR savings_transaction_id IS NOT NULL)
                AND prevented_by_inventory_item_id IS NULL)
            OR (spendable_transaction_id IS NULL
                AND savings_transaction_id IS NULL
                AND prevented_by_inventory_item_id IS NOT NULL)
        ))
    );

-- Append-only audit trail for every real perk activation and durability loss.
CREATE TABLE artifact_effect_events (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_user_id         uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    inventory_item_id     uuid NOT NULL REFERENCES inventory_items (id) ON DELETE RESTRICT,
    effect_code           varchar(64) NOT NULL,
    durability_spent      int NOT NULL,
    durability_after      int NOT NULL,
    reference_type        varchar(40) NOT NULL,
    reference_id          varchar(80) NOT NULL,
    occurred_at           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_artifact_effect_spent_positive CHECK (durability_spent > 0),
    CONSTRAINT chk_artifact_effect_after_nonnegative CHECK (durability_after >= 0),
    CONSTRAINT uq_artifact_effect_reference
        UNIQUE (inventory_item_id, effect_code, reference_type, reference_id)
);

CREATE INDEX idx_artifact_effect_child_time
    ON artifact_effect_events (child_user_id, occurred_at DESC);

ALTER TYPE transaction_event_type ADD VALUE 'CASHBACK';
ALTER TYPE transaction_event_type ADD VALUE 'ARTIFACT_BONUS';
ALTER TYPE transaction_event_type ADD VALUE 'ARTIFACT_REPAIR';

GRANT UPDATE ON inventory_items TO groshik_app;
GRANT SELECT, INSERT ON artifact_effect_events TO groshik_app;
