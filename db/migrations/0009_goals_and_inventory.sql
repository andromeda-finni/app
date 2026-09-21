CREATE TABLE financial_goals (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_user_id            uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    target_item_id           varchar(50) NOT NULL,
    target_item_kind         item_kind NOT NULL DEFAULT 'ARTIFACT',
    target_amount            int NOT NULL,
    status                   goal_status NOT NULL DEFAULT 'ACTIVE',
    redemption_transaction_id  uuid UNIQUE REFERENCES transactions (id) ON DELETE RESTRICT,
    selected_at               timestamptz NOT NULL DEFAULT now(),
    achieved_at                timestamptz,
    redeemed_at                 timestamptz,
    cancelled_at                timestamptz,
    CONSTRAINT chk_goal_target_artifact CHECK (target_item_kind = 'ARTIFACT'),
    CONSTRAINT chk_goal_amount_positive CHECK (target_amount > 0),
    CONSTRAINT chk_goal_status_shape CHECK (
        (status IN ('ACTIVE', 'PAUSED') AND achieved_at IS NULL AND redeemed_at IS NULL AND cancelled_at IS NULL)
        OR (status = 'ACHIEVED' AND achieved_at IS NOT NULL AND redeemed_at IS NULL AND cancelled_at IS NULL)
        OR (status = 'REDEEMED' AND achieved_at IS NOT NULL AND redeemed_at IS NOT NULL AND cancelled_at IS NULL AND redemption_transaction_id IS NOT NULL)
        OR (status = 'CANCELLED' AND redeemed_at IS NULL AND cancelled_at IS NOT NULL)
    ),
    CONSTRAINT fk_goal_target_item FOREIGN KEY (target_item_id, target_item_kind)
        REFERENCES shop_items (id, kind) ON DELETE RESTRICT
);

-- Only one goal "in flight" (active/paused/achieved-but-not-yet-redeemed) per child.
CREATE UNIQUE INDEX uq_goal_open_child ON financial_goals (child_user_id)
    WHERE status IN ('ACTIVE', 'PAUSED', 'ACHIEVED');

CREATE TABLE inventory_items (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_user_id            uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    item_id                  varchar(50) NOT NULL,
    item_kind                item_kind NOT NULL DEFAULT 'ARTIFACT',
    financial_goal_id        uuid NOT NULL UNIQUE REFERENCES financial_goals (id) ON DELETE RESTRICT,
    acquired_at               timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_inventory_item_artifact CHECK (item_kind = 'ARTIFACT'),
    CONSTRAINT fk_inventory_item FOREIGN KEY (item_id, item_kind)
        REFERENCES shop_items (id, kind) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_inventory_child_item ON inventory_items (child_user_id, item_id);
CREATE UNIQUE INDEX uq_inventory_id_child ON inventory_items (id, child_user_id);

-- A single equip slot for the earned ARTIFACT (separate from the free FUR/ACCESSORY
-- cosmetics on pets, which are chosen at customization time, not earned).
-- Composite FK guarantees a child can only equip an item they own.
ALTER TABLE pets ADD COLUMN equipped_inventory_item_id uuid UNIQUE;
ALTER TABLE pets ADD CONSTRAINT fk_pet_equipped_item FOREIGN KEY (equipped_inventory_item_id, child_user_id)
    REFERENCES inventory_items (id, child_user_id) ON DELETE RESTRICT;
