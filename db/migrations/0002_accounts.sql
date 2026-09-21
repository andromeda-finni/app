-- Identity. No name/age/email/phone is ever stored for parent or child.

CREATE TABLE users (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    role        user_role NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_user_updated_after_created CHECK (updated_at >= created_at)
);

CREATE TABLE parent_profiles (
    user_id     uuid PRIMARY KEY REFERENCES users (id) ON DELETE RESTRICT,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE child_profiles (
    user_id                 uuid PRIMARY KEY REFERENCES users (id) ON DELETE RESTRICT,
    mode                    profile_mode NOT NULL DEFAULT 'STANDARD',
    difficulty              difficulty_level NOT NULL DEFAULT 'SIMPLE',
    parent_gate             parent_gate_mode NOT NULL DEFAULT 'MATH_TASK',
    sound_enabled           boolean NOT NULL DEFAULT true,
    music_enabled           boolean NOT NULL DEFAULT true,
    animations_enabled      boolean NOT NULL DEFAULT true,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_child_updated_after_created CHECK (updated_at >= created_at)
);

-- A parent invites a child with a one-time code; the child redeems it to activate the link.
CREATE TABLE parent_child_links (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_user_id     uuid NOT NULL REFERENCES parent_profiles (user_id) ON DELETE RESTRICT,
    child_user_id      uuid REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    invite_code_hash   varchar(128) NOT NULL,
    status             parent_child_link_status NOT NULL DEFAULT 'PENDING',
    created_at         timestamptz NOT NULL DEFAULT now(),
    expires_at         timestamptz NOT NULL,
    linked_at          timestamptz,
    revoked_at         timestamptz,
    CONSTRAINT chk_link_status_shape CHECK (
        (status = 'PENDING' AND child_user_id IS NULL AND linked_at IS NULL AND revoked_at IS NULL)
        OR (status = 'ACTIVE' AND child_user_id IS NOT NULL AND linked_at IS NOT NULL AND revoked_at IS NULL)
        OR (status = 'REVOKED' AND child_user_id IS NOT NULL AND linked_at IS NOT NULL AND revoked_at IS NOT NULL)
    ),
    CONSTRAINT chk_link_expires_after_created CHECK (expires_at > created_at)
);

CREATE UNIQUE INDEX uq_link_invite_code ON parent_child_links (invite_code_hash);
-- Only one ACTIVE link per (parent, child) pair.
CREATE UNIQUE INDEX uq_link_active_pair ON parent_child_links (parent_user_id, child_user_id)
    WHERE status = 'ACTIVE';
CREATE INDEX idx_link_child_status ON parent_child_links (child_user_id, status);
