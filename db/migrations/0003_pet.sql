-- There is exactly one pet species in the whole game; only look (fur color) and
-- an accessory are customizable, so no pet-species catalog table is needed.

CREATE TABLE cosmetic_options (
    id            varchar(50) PRIMARY KEY,
    kind          cosmetic_kind NOT NULL,
    display_name  varchar(120) NOT NULL,
    asset_code    varchar(80) NOT NULL,
    active        boolean NOT NULL DEFAULT true
);

CREATE INDEX idx_cosmetic_kind_active ON cosmetic_options (kind, active);
-- Lets us enforce "this option is actually a FUR/ACCESSORY option" via a composite FK below,
-- instead of a CHECK constraint with a subquery (Postgres does not reliably re-evaluate those).
CREATE UNIQUE INDEX uq_cosmetic_id_kind ON cosmetic_options (id, kind);

CREATE TABLE pets (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_user_id               uuid NOT NULL UNIQUE REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    pet_name                    varchar(24) NOT NULL,
    pet_name_status             pet_name_status NOT NULL DEFAULT 'APPROVED',
    pet_name_flag_reason        varchar(64),
    fur_option_id                varchar(50) NOT NULL,
    fur_option_kind               cosmetic_kind GENERATED ALWAYS AS ('FUR'::cosmetic_kind) STORED,
    accessory_option_id          varchar(50),
    accessory_option_kind         cosmetic_kind GENERATED ALWAYS AS (
        CASE WHEN accessory_option_id IS NOT NULL THEN 'ACCESSORY'::cosmetic_kind END
    ) STORED,
    energy_level                smallint NOT NULL DEFAULT 100,
    joy_level                   smallint NOT NULL DEFAULT 50,
    evolution_stage              smallint NOT NULL DEFAULT 1,
    successful_period_streak    int NOT NULL DEFAULT 0,
    created_at                  timestamptz NOT NULL DEFAULT now(),
    updated_at                  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_pet_name_length CHECK (char_length(btrim(pet_name)) BETWEEN 1 AND 24),
    CONSTRAINT chk_pet_name_status_reason CHECK (
        (pet_name_status = 'APPROVED' AND pet_name_flag_reason IS NULL)
        OR (pet_name_status = 'FLAGGED' AND pet_name_flag_reason IS NOT NULL)
    ),
    CONSTRAINT chk_pet_energy_range CHECK (energy_level BETWEEN 0 AND 100),
    CONSTRAINT chk_pet_joy_range CHECK (joy_level BETWEEN 0 AND 100),
    CONSTRAINT chk_pet_stage_range CHECK (evolution_stage BETWEEN 1 AND 3),
    CONSTRAINT chk_pet_streak_nonnegative CHECK (successful_period_streak >= 0),
    CONSTRAINT chk_pet_updated_after_created CHECK (updated_at >= created_at),
    CONSTRAINT fk_pet_fur_option FOREIGN KEY (fur_option_id, fur_option_kind)
        REFERENCES cosmetic_options (id, kind) ON DELETE RESTRICT,
    CONSTRAINT fk_pet_accessory_option FOREIGN KEY (accessory_option_id, accessory_option_kind)
        REFERENCES cosmetic_options (id, kind) ON DELETE RESTRICT
);
