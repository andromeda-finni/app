-- reference_id is polymorphic: most referenced rows (assignments, financial_goals,
-- frost_chests, pet_event_occurrences, scam_offer_occurrences) use uuid ids, but
-- purchases reference shop_items.id, which is a varchar content-catalog key.
-- uuid can't hold that, so widen the column to text.
ALTER TABLE transactions ALTER COLUMN reference_id TYPE varchar(80) USING reference_id::text;
