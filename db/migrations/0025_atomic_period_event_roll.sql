-- A period owns exactly one pet-event roll. Keeping the marker in PostgreSQL
-- makes day creation retry-safe: a client reconnect or screen refresh cannot
-- keep rolling until it gets an event, and a successful day can never exist
-- without knowing whether its event roll already happened.
ALTER TABLE game_periods
    ADD COLUMN event_rolled_at timestamptz;

COMMENT ON COLUMN game_periods.event_rolled_at IS
    'Set in the same transaction that performs this period pet-event roll, whether or not an event was triggered.';
