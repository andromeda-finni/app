CREATE TABLE education_topics (
    id                  varchar(40) PRIMARY KEY,
    title               varchar(120) NOT NULL,
    skill_description   varchar(300) NOT NULL,
    sort_order          smallint NOT NULL DEFAULT 0,
    active              boolean NOT NULL DEFAULT true,
    CONSTRAINT chk_topic_sort_nonnegative CHECK (sort_order >= 0)
);

-- System quests told by "Хитрый Лис" (Clever Fox).
CREATE TABLE quest_definitions (
    id                varchar(50) PRIMARY KEY,
    topic_id          varchar(40) NOT NULL REFERENCES education_topics (id) ON DELETE RESTRICT,
    title             varchar(120) NOT NULL,
    character_code    varchar(40) NOT NULL DEFAULT 'CLEVER_FOX',
    location_code     varchar(40) NOT NULL,
    difficulty        difficulty_level NOT NULL,
    reward_amount     int NOT NULL,
    active            boolean NOT NULL DEFAULT true,
    CONSTRAINT chk_quest_reward_positive CHECK (reward_amount > 0)
);

CREATE INDEX idx_quest_topic_difficulty_active ON quest_definitions (topic_id, difficulty, active);

CREATE TABLE quest_steps (
    quest_id                varchar(50) NOT NULL REFERENCES quest_definitions (id) ON DELETE RESTRICT,
    step_no                 smallint NOT NULL,
    instruction              varchar(500) NOT NULL,
    expected_action_code    varchar(80) NOT NULL,
    success_feedback        varchar(500) NOT NULL,
    recovery_feedback       varchar(500) NOT NULL,
    ui_spec                 jsonb,
    PRIMARY KEY (quest_id, step_no),
    CONSTRAINT chk_quest_step_positive CHECK (step_no > 0),
    CONSTRAINT chk_quest_ui_spec_object CHECK (ui_spec IS NULL OR jsonb_typeof(ui_spec) = 'object')
);

-- Shop catalog: NEED/WANT are everyday spendable items, ARTIFACT items are earned
-- only through financial_goals (see 0009) and equipped onto the pet.
CREATE TABLE shop_items (
    id             varchar(50) PRIMARY KEY,
    kind           item_kind NOT NULL,
    name           varchar(120) NOT NULL,
    price          int NOT NULL,
    rarity         rarity_kind,
    effect_code    varchar(64),
    active         boolean NOT NULL DEFAULT true,
    CONSTRAINT chk_shop_price_positive CHECK (price > 0),
    CONSTRAINT chk_shop_rarity_only_artifact CHECK (
        (kind = 'ARTIFACT') OR (kind IN ('NEED', 'WANT') AND rarity IS NULL)
    )
);

CREATE INDEX idx_shop_kind_active ON shop_items (kind, active);
CREATE UNIQUE INDEX uq_shop_id_kind ON shop_items (id, kind);
