-- Deploy the scoped backend reward validator before applying this catalog
-- update. This migration does not issue money or alter completed rewards.
UPDATE quest_definitions
   SET reward_amount = 20, advanced_reward_amount = 20
 WHERE id = 'Q_MOLE_FINE_PRINT';

-- Upgrade only unfinished system assignments. Completed snapshots and their
-- append-only ledger transactions keep their original amounts.
UPDATE assignments
   SET reward_amount = 20, updated_at = now()
 WHERE quest_id = 'Q_MOLE_FINE_PRINT'
   AND origin = 'SYSTEM'
   AND status = 'IN_PROGRESS';
