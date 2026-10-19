-- The character tracks are independent; keep prerequisites inside a track.
DELETE FROM quest_prerequisites
WHERE (quest_id, prerequisite_quest_id) IN (
  ('Q_MOLE_FINE_PRINT', 'Q_TURNIP_HARVEST'),
  ('Q_TUGRIKI_CURRENCY', 'Q_MOLE_FINE_PRINT'),
  ('Q_TUGRIKI_CURRENCY', 'Q_BAKERY_PROFIT'),
  ('Q_BAKERY_PROFIT', 'Q_MOLE_FINE_PRINT'),
  ('Q_SQUIRREL_QUALITY_SIMPLE', 'Q_MOLE_FINE_PRINT'),
  ('Q_IVAN_ROAD_EASY_1', 'Q_MOLE_FINE_PRINT'),
  ('Q_IVAN_ROAD_HARD_1', 'Q_MOLE_FINE_PRINT'),
  ('Q_GOLDFISH_HOME_SIMPLE_1', 'Q_IVAN_ROAD_EASY_2'),
  ('Q_GOLDFISH_HOME_ADVANCED_1', 'Q_IVAN_ROAD_HARD_2')
);

CREATE TABLE quest_day_selections (
  period_id uuid PRIMARY KEY REFERENCES game_periods(id) ON DELETE RESTRICT,
  child_user_id uuid NOT NULL REFERENCES child_profiles(user_id) ON DELETE RESTRICT,
  slot_limit smallint NOT NULL CHECK (slot_limit IN (3, 4)),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (period_id, child_user_id)
);

CREATE TABLE quest_day_offers (
  period_id uuid NOT NULL,
  child_user_id uuid NOT NULL,
  slot smallint NOT NULL CHECK (slot BETWEEN 1 AND 4),
  track_id varchar(30) NOT NULL,
  quest_id varchar(50) NOT NULL REFERENCES quest_definitions(id) ON DELETE RESTRICT,
  assignment_id uuid REFERENCES assignments(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (period_id, slot),
  UNIQUE (period_id, track_id),
  UNIQUE (period_id, quest_id),
  FOREIGN KEY (period_id, child_user_id)
    REFERENCES quest_day_selections(period_id, child_user_id) ON DELETE RESTRICT
);
CREATE INDEX idx_daily_quest_child ON quest_day_offers(child_user_id, period_id);
GRANT SELECT, INSERT, UPDATE ON quest_day_selections, quest_day_offers TO groshik_app;
