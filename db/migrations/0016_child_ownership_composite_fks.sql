-- Several tables store both child_user_id and a reference to another
-- child-scoped row (a transaction, a game_period, a financial_goal, a pet,
-- a parent_child_link) without tying the two together. Today only app code
-- (`WHERE child_user_id = $1 AND ...`) prevents one child's row from
-- pointing at another child's resource — the database itself would accept
-- it. Add (id, child_user_id) uniqueness on each referenced table and widen
-- the referencing FKs to composite, following the same pattern already used
-- for pets.equipped_inventory_item_id -> inventory_items (0009).

-- 1. Let referenced tables be looked up by (id, child_user_id).
CREATE UNIQUE INDEX uq_txn_id_child ON transactions (id, child_user_id);
CREATE UNIQUE INDEX uq_period_id_child ON game_periods (id, child_user_id);
CREATE UNIQUE INDEX uq_goal_id_child ON financial_goals (id, child_user_id);
CREATE UNIQUE INDEX uq_pet_id_child ON pets (id, child_user_id);
-- parent_child_links.child_user_id is NULL while PENDING; a composite unique
-- index still works (each NULL is distinct) and only matters once ACTIVE,
-- which is exactly when assignments start referencing a link.
CREATE UNIQUE INDEX uq_link_id_child ON parent_child_links (id, child_user_id);

-- 2. purchases.transaction_id -> transactions
ALTER TABLE purchases DROP CONSTRAINT purchases_transaction_id_fkey;
ALTER TABLE purchases ADD CONSTRAINT fk_purchase_transaction_child
    FOREIGN KEY (transaction_id, child_user_id) REFERENCES transactions (id, child_user_id)
    ON DELETE RESTRICT;

-- 3. frost_chests.*_transaction_id -> transactions
ALTER TABLE frost_chests DROP CONSTRAINT frost_chests_deposit_transaction_id_fkey;
ALTER TABLE frost_chests ADD CONSTRAINT fk_frost_deposit_txn_child
    FOREIGN KEY (deposit_transaction_id, child_user_id) REFERENCES transactions (id, child_user_id)
    ON DELETE RESTRICT;

ALTER TABLE frost_chests DROP CONSTRAINT frost_chests_withdrawal_transaction_id_fkey;
ALTER TABLE frost_chests ADD CONSTRAINT fk_frost_withdrawal_txn_child
    FOREIGN KEY (withdrawal_transaction_id, child_user_id) REFERENCES transactions (id, child_user_id)
    ON DELETE RESTRICT;

ALTER TABLE frost_chests DROP CONSTRAINT frost_chests_bonus_transaction_id_fkey;
ALTER TABLE frost_chests ADD CONSTRAINT fk_frost_bonus_txn_child
    FOREIGN KEY (bonus_transaction_id, child_user_id) REFERENCES transactions (id, child_user_id)
    ON DELETE RESTRICT;

-- 4. game_periods-scoped tables: budget_plans, period_results, and the
--    nullable period_id on assignments/pet_event_occurrences/scam_offer_occurrences.
ALTER TABLE budget_plans DROP CONSTRAINT budget_plans_period_id_fkey;
ALTER TABLE budget_plans ADD CONSTRAINT fk_budget_plan_period_child
    FOREIGN KEY (period_id, child_user_id) REFERENCES game_periods (id, child_user_id)
    ON DELETE RESTRICT;

ALTER TABLE period_results DROP CONSTRAINT period_results_period_id_fkey;
ALTER TABLE period_results ADD CONSTRAINT fk_period_result_period_child
    FOREIGN KEY (period_id, child_user_id) REFERENCES game_periods (id, child_user_id)
    ON DELETE RESTRICT;

ALTER TABLE assignments DROP CONSTRAINT assignments_period_id_fkey;
ALTER TABLE assignments ADD CONSTRAINT fk_assignment_period_child
    FOREIGN KEY (period_id, child_user_id) REFERENCES game_periods (id, child_user_id)
    ON DELETE RESTRICT;

ALTER TABLE pet_event_occurrences DROP CONSTRAINT pet_event_occurrences_period_id_fkey;
ALTER TABLE pet_event_occurrences ADD CONSTRAINT fk_pet_event_period_child
    FOREIGN KEY (period_id, child_user_id) REFERENCES game_periods (id, child_user_id)
    ON DELETE RESTRICT;

ALTER TABLE scam_offer_occurrences DROP CONSTRAINT scam_offer_occurrences_period_id_fkey;
ALTER TABLE scam_offer_occurrences ADD CONSTRAINT fk_scam_offer_period_child
    FOREIGN KEY (period_id, child_user_id) REFERENCES game_periods (id, child_user_id)
    ON DELETE RESTRICT;

-- 5. assignments: reward transaction + the parent link that assigned it.
ALTER TABLE assignments DROP CONSTRAINT assignments_reward_transaction_id_fkey;
ALTER TABLE assignments ADD CONSTRAINT fk_assignment_reward_txn_child
    FOREIGN KEY (reward_transaction_id, child_user_id) REFERENCES transactions (id, child_user_id)
    ON DELETE RESTRICT;

ALTER TABLE assignments DROP CONSTRAINT assignments_assigned_by_parent_link_id_fkey;
ALTER TABLE assignments ADD CONSTRAINT fk_assignment_parent_link_child
    FOREIGN KEY (assigned_by_parent_link_id, child_user_id) REFERENCES parent_child_links (id, child_user_id)
    ON DELETE RESTRICT;

-- 6. financial_goals.redemption_transaction_id -> transactions
ALTER TABLE financial_goals DROP CONSTRAINT financial_goals_redemption_transaction_id_fkey;
ALTER TABLE financial_goals ADD CONSTRAINT fk_goal_redemption_txn_child
    FOREIGN KEY (redemption_transaction_id, child_user_id) REFERENCES transactions (id, child_user_id)
    ON DELETE RESTRICT;

-- 7. inventory_items.financial_goal_id -> financial_goals
ALTER TABLE inventory_items DROP CONSTRAINT inventory_items_financial_goal_id_fkey;
ALTER TABLE inventory_items ADD CONSTRAINT fk_inventory_goal_child
    FOREIGN KEY (financial_goal_id, child_user_id) REFERENCES financial_goals (id, child_user_id)
    ON DELETE RESTRICT;

-- 8. pet_event_occurrences: the pet itself, plus both settlement legs.
ALTER TABLE pet_event_occurrences DROP CONSTRAINT pet_event_occurrences_pet_id_fkey;
ALTER TABLE pet_event_occurrences ADD CONSTRAINT fk_pet_event_pet_child
    FOREIGN KEY (pet_id, child_user_id) REFERENCES pets (id, child_user_id)
    ON DELETE RESTRICT;

ALTER TABLE pet_event_occurrences DROP CONSTRAINT pet_event_occurrences_spendable_transaction_id_fkey;
ALTER TABLE pet_event_occurrences ADD CONSTRAINT fk_pet_event_spendable_txn_child
    FOREIGN KEY (spendable_transaction_id, child_user_id) REFERENCES transactions (id, child_user_id)
    ON DELETE RESTRICT;

ALTER TABLE pet_event_occurrences DROP CONSTRAINT pet_event_occurrences_savings_transaction_id_fkey;
ALTER TABLE pet_event_occurrences ADD CONSTRAINT fk_pet_event_savings_txn_child
    FOREIGN KEY (savings_transaction_id, child_user_id) REFERENCES transactions (id, child_user_id)
    ON DELETE RESTRICT;

-- 9. scam_offer_occurrences.cost_transaction_id -> transactions
ALTER TABLE scam_offer_occurrences DROP CONSTRAINT scam_offer_occurrences_cost_transaction_id_fkey;
ALTER TABLE scam_offer_occurrences ADD CONSTRAINT fk_scam_offer_cost_txn_child
    FOREIGN KEY (cost_transaction_id, child_user_id) REFERENCES transactions (id, child_user_id)
    ON DELETE RESTRICT;
