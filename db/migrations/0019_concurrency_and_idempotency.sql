-- Closes three concurrency gaps that route-level checks alone cannot cover,
-- because every one of them is a check-then-act race that two simultaneous
-- requests can both win.

-- 1. Replay/idempotency record.
--
-- Previously each money endpoint did its own "has this key been used?" SELECT
-- outside the transaction that then spent the money, so two concurrent retries
-- of the same request both saw "no" and both proceeded; the loser hit the raw
-- unique violation on transactions.idempotency_key and surfaced as a 500.
--
-- Claiming the key is now the first write of the transaction, which makes the
-- database the arbiter: the second request blocks on the conflicting row until
-- the first commits, then reads back its stored response and replays it.
-- request_fingerprint additionally catches a key reused with *different*
-- parameters, which must be an error rather than a silent wrong answer.
CREATE TABLE idempotency_keys (
    child_user_id       uuid NOT NULL REFERENCES child_profiles (user_id) ON DELETE RESTRICT,
    scope               varchar(40) NOT NULL,
    idempotency_key     varchar(120) NOT NULL,
    request_fingerprint text NOT NULL,
    -- NULL only while the claiming transaction is still in flight; a row is
    -- never visible to another transaction in that state, since an uncommitted
    -- claim blocks readers and a rolled-back one disappears entirely.
    response_json       jsonb,
    created_at          timestamptz NOT NULL DEFAULT now(),
    completed_at        timestamptz,
    PRIMARY KEY (child_user_id, scope, idempotency_key)
);

-- 2. One live SYSTEM quest assignment per child per quest.
--
-- POST /quests/:questId/start checked for an existing assignment and inserted
-- as two separate statements, so two parallel starts both passed the check and
-- created two assignments — each of which could then be completed for the full
-- reward. AVAILABLE/CANCELLED rows stay out of the index so a cancelled quest
-- can still be legitimately restarted.
CREATE UNIQUE INDEX uq_assignment_active_system_quest
    ON assignments (child_user_id, quest_id)
 WHERE origin = 'SYSTEM' AND status IN ('IN_PROGRESS', 'COMPLETED');

-- 3. Grants.
--
-- 0017 revoked UPDATE/DELETE by default on new tables, so the app role needs
-- an explicit UPDATE here to write response_json back after the operation.
GRANT SELECT, INSERT, UPDATE ON idempotency_keys TO groshik_app;

-- 0017 revoked ALL on schema_migrations. /health now reads it to prove the
-- schema is actually migrated before reporting ready, so give back read-only
-- access — and only that.
GRANT SELECT ON schema_migrations TO groshik_app;
