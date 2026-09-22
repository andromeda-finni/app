-- When SPENDABLE is already 0, postSpendableThenSavings() legitimately skips
-- posting a SPENDABLE leg entirely (a $0 transaction would violate
-- transactions' CHECK (delta_amount <> 0)) and pays the full amount from
-- SAVINGS instead. The original shape check required spendable_transaction_id
-- on every RESOLVED row, which made that valid all-from-savings case
-- impossible to record. Require at least one of the two legs instead.
ALTER TABLE pet_event_occurrences DROP CONSTRAINT chk_pet_event_status_shape;

ALTER TABLE pet_event_occurrences ADD CONSTRAINT chk_pet_event_status_shape CHECK (
    (status = 'ACTIVE' AND resolved_at IS NULL)
    OR (
        status = 'RESOLVED' AND resolved_at IS NOT NULL
        AND (spendable_transaction_id IS NOT NULL OR savings_transaction_id IS NOT NULL)
    )
);
