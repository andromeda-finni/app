CREATE TABLE wallets (
    child_user_id    uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    kind             wallet_kind NOT NULL,
    balance          int NOT NULL DEFAULT 0,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (child_user_id, kind),
    CONSTRAINT chk_wallet_balance_nonnegative CHECK (balance >= 0)
);

-- Append-only ledger; wallets.balance is a rebuildable cache of SUM(delta_amount).
-- reference_type/reference_id point at the row that caused the movement
-- (purchase, assignment, financial_goal, frost_chest, pet_event) for traceability;
-- kept loose (no FK) on purpose since it is polymorphic across several tables.
CREATE TABLE transactions (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_user_id      uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    wallet_kind        wallet_kind NOT NULL,
    event_type         transaction_event_type NOT NULL,
    delta_amount       int NOT NULL,
    balance_after      int NOT NULL,
    reference_type     varchar(40),
    reference_id       uuid,
    idempotency_key    varchar(120) NOT NULL,
    occurred_at        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_txn_delta_nonzero CHECK (delta_amount <> 0),
    CONSTRAINT chk_txn_balance_nonnegative CHECK (balance_after >= 0),
    CONSTRAINT fk_txn_wallet FOREIGN KEY (child_user_id, wallet_kind)
        REFERENCES wallets (child_user_id, kind) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_txn_idempotency ON transactions (child_user_id, idempotency_key);
CREATE INDEX idx_txn_child_occurred ON transactions (child_user_id, occurred_at);
CREATE INDEX idx_txn_reference ON transactions (reference_type, reference_id);
