-- Quest availability is a server-side rule. Keeping prerequisites in data
-- prevents a modified or stale client from starting a later rewarded quest by
-- calling its endpoint directly, and allows future quest graphs without route
-- code changes.
CREATE TABLE quest_prerequisites (
    quest_id               varchar(50) NOT NULL REFERENCES quest_definitions (id) ON DELETE RESTRICT,
    prerequisite_quest_id  varchar(50) NOT NULL REFERENCES quest_definitions (id) ON DELETE RESTRICT,
    PRIMARY KEY (quest_id, prerequisite_quest_id),
    CONSTRAINT chk_quest_prerequisite_not_self CHECK (quest_id <> prerequisite_quest_id)
);

INSERT INTO quest_prerequisites (quest_id, prerequisite_quest_id)
SELECT 'Q_TUGRIKI_CURRENCY', 'Q_MOLE_FINE_PRINT'
 WHERE EXISTS (SELECT 1 FROM quest_definitions WHERE id = 'Q_TUGRIKI_CURRENCY')
   AND EXISTS (SELECT 1 FROM quest_definitions WHERE id = 'Q_MOLE_FINE_PRINT')
ON CONFLICT DO NOTHING;

-- The child names the pet. Catalog copy without a live pet context must stay
-- generic instead of reviving the prototype name in the shop UI.
UPDATE shop_items
   SET name = 'Обед для питомца'
 WHERE id = 'PET_MEAL';

-- A chest must retain the term promised when it was opened. Earlier code
-- displayed five days but left the legacy database value at three and then
-- ignored the column. Store the real term and make future inserts explicit.
ALTER TABLE frost_chests DROP CONSTRAINT chk_frost_required_days;
UPDATE frost_chests SET required_active_days = 5;
ALTER TABLE frost_chests ALTER COLUMN required_active_days SET DEFAULT 5;
ALTER TABLE frost_chests
  ADD CONSTRAINT chk_frost_required_days CHECK (required_active_days > 0);

GRANT SELECT ON quest_prerequisites TO groshik_app;
