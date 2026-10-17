-- Repeatable home mini-game. No connection to paid quest assignments or ledger.
-- The caller's UUID is an idempotency key scoped to the authenticated child.
CREATE TABLE catch_food_sessions (
    child_user_id uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    id uuid NOT NULL,
    energy_cost int NOT NULL CHECK (energy_cost BETWEEN 1 AND 100),
    score int NOT NULL DEFAULT 0 CHECK (score BETWEEN 0 AND 1000),
    misses int NOT NULL DEFAULT 0 CHECK (misses BETWEEN 0 AND 3),
    elapsed_ms int NOT NULL DEFAULT 0 CHECK (elapsed_ms BETWEEN 0 AND 60000),
    finish_reason varchar(12) CHECK (finish_reason IN ('MISSES', 'TIRED', 'STOPPED')),
    created_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz,
    PRIMARY KEY (child_user_id, id),
    CONSTRAINT chk_catch_food_finish CHECK (
      (finished_at IS NULL AND finish_reason IS NULL)
      OR (finished_at IS NOT NULL AND finish_reason IS NOT NULL AND finished_at >= created_at)
    )
);
CREATE INDEX idx_catch_food_best ON catch_food_sessions (child_user_id, score DESC)
    WHERE finished_at IS NOT NULL;
GRANT SELECT, INSERT, UPDATE ON catch_food_sessions TO groshik_app;
