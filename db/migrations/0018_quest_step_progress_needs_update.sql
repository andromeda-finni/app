-- 0017 revoked UPDATE/DELETE from every table then re-granted UPDATE only on
-- the tables a plain-text `UPDATE <table>` grep found — but
-- `INSERT ... ON CONFLICT (...) DO UPDATE SET ...` (used by
-- backend/src/modules/quests/routes.ts to let a child retry a quest step)
-- also requires UPDATE privilege on the target table, and that upsert
-- pattern doesn't match that grep. Discovered live: retrying/answering a
-- quest step failed with "permission denied for table quest_step_progress".
GRANT UPDATE ON quest_step_progress TO groshik_app;
