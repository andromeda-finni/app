-- Additive catalog update for existing installations as well as fresh ones.
-- Existing null accessories keep rendering as the default red collar.
INSERT INTO cosmetic_options (id, kind, display_name, asset_code) VALUES
  ('ACC_COLLAR_RED', 'ACCESSORY', 'Красный ошейник', 'collar_red'),
  ('ACC_COLLAR_GREEN', 'ACCESSORY', 'Зелёный ошейник', 'collar_green'),
  ('ACC_COLLAR_BLUE', 'ACCESSORY', 'Синий ошейник', 'collar_blue')
ON CONFLICT (id) DO NOTHING;
