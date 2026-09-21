CREATE TABLE purchases (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_user_id          uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    item_id                varchar(50) NOT NULL,
    item_kind              item_kind NOT NULL,
    transaction_id         uuid NOT NULL UNIQUE REFERENCES transactions (id) ON DELETE RESTRICT,
    quantity               int NOT NULL DEFAULT 1,
    unit_price             int NOT NULL,
    total_price            int NOT NULL,
    purchased_at           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_purchase_item_kind CHECK (item_kind IN ('NEED', 'WANT')),
    CONSTRAINT chk_purchase_amounts_positive CHECK (quantity > 0 AND unit_price > 0 AND total_price > 0),
    CONSTRAINT chk_purchase_total CHECK (total_price = quantity * unit_price),
    CONSTRAINT fk_purchase_item FOREIGN KEY (item_id, item_kind)
        REFERENCES shop_items (id, kind) ON DELETE RESTRICT
);

CREATE INDEX idx_purchase_child_time ON purchases (child_user_id, purchased_at);

-- "Сундук Морозко": freeze coins for 3 active days to earn a 10% bonus,
-- or withdraw early and keep only the principal.
CREATE TABLE frost_chests (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_user_id            uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    principal_amount         int NOT NULL,
    bonus_amount             int NOT NULL,
    required_active_days     smallint NOT NULL DEFAULT 3,
    status                   frost_chest_status NOT NULL DEFAULT 'ACTIVE',
    deposit_transaction_id      uuid NOT NULL UNIQUE REFERENCES transactions (id) ON DELETE RESTRICT,
    withdrawal_transaction_id   uuid UNIQUE REFERENCES transactions (id) ON DELETE RESTRICT,
    bonus_transaction_id        uuid UNIQUE REFERENCES transactions (id) ON DELETE RESTRICT,
    opened_at                timestamptz NOT NULL DEFAULT now(),
    available_at             timestamptz,
    closed_at                timestamptz,
    CONSTRAINT chk_frost_amounts CHECK (principal_amount > 0 AND bonus_amount = principal_amount / 10),
    CONSTRAINT chk_frost_required_days CHECK (required_active_days = 3),
    CONSTRAINT chk_frost_status_shape CHECK (
        (status = 'ACTIVE' AND withdrawal_transaction_id IS NULL AND bonus_transaction_id IS NULL AND closed_at IS NULL)
        OR (status = 'WITHDRAWN_EARLY' AND withdrawal_transaction_id IS NOT NULL AND bonus_transaction_id IS NULL AND closed_at IS NOT NULL)
        OR (status = 'COLLECTED' AND withdrawal_transaction_id IS NOT NULL AND bonus_transaction_id IS NOT NULL AND closed_at IS NOT NULL)
    )
);

-- Only one frost chest open per child at a time (matches the v1 game rule).
CREATE UNIQUE INDEX uq_frost_chest_active_child ON frost_chests (child_user_id) WHERE status = 'ACTIVE';
CREATE INDEX idx_frost_chest_child_status ON frost_chests (child_user_id, status);
