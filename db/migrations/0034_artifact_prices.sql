-- Rebalance artifact prices for existing installations. An open goal stores
-- its own target_amount, so update it along with the catalog. Keep redeemed
-- goals unchanged because their recorded redemption amounts are historical.
UPDATE shop_items AS item
   SET price = revised.price
  FROM (VALUES
    ('saucer', 70),
    ('vial', 80),
    ('tablecloth', 95),
    ('horseshoe', 100),
    ('shield', 110),
    ('purse', 120),
    ('boots', 135)
  ) AS revised(id, price)
 WHERE item.id = revised.id AND item.kind = 'ARTIFACT';

UPDATE financial_goals AS goal
   SET target_amount = item.price,
       status = CASE
         WHEN goal.status = 'ACTIVE' AND savings.balance >= item.price
           THEN 'ACHIEVED'::goal_status
         ELSE goal.status
       END,
       achieved_at = CASE
         WHEN goal.status = 'ACTIVE' AND savings.balance >= item.price
           THEN COALESCE(goal.achieved_at, now())
         ELSE goal.achieved_at
       END
  FROM shop_items AS item, wallets AS savings
 WHERE goal.target_item_id = item.id
   AND goal.child_user_id = savings.child_user_id
   AND savings.kind = 'SAVINGS'
   AND goal.status IN ('ACTIVE', 'PAUSED', 'ACHIEVED')
   AND item.id IN ('saucer', 'vial', 'tablecloth', 'horseshoe', 'shield', 'purse', 'boots');
