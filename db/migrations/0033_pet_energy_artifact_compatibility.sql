-- Preserve the established living-water quest protection while allowing the
-- same refillable vial to be spent manually for a full energy restore. The
-- manual action is audited with RESTORE_ENERGY_FULL by the inventory route;
-- the catalog code remains SECOND_CHANCE for automatic quest/event use.
UPDATE shop_items
   SET effect_code = 'SECOND_CHANCE'
 WHERE id = 'vial' AND kind = 'ARTIFACT';
