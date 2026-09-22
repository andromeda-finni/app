-- No email/password (no PII collected). Each account is authenticated by an
-- opaque bearer token generated server-side at registration/link time and
-- stored on-device (e.g. flutter_secure_storage). The server only ever stores
-- a SHA-256 hash of the token, never the token itself, so a DB read (or a
-- leaked backup) cannot be replayed as a valid credential.
CREATE TABLE auth_credentials (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        uuid NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    token_hash     varchar(64) NOT NULL UNIQUE, -- hex-encoded SHA-256, 64 chars
    created_at     timestamptz NOT NULL DEFAULT now(),
    last_used_at   timestamptz,
    revoked_at     timestamptz
);

CREATE INDEX idx_auth_credentials_user ON auth_credentials (user_id) WHERE revoked_at IS NULL;
