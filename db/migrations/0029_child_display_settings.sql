-- Large text is a real per-child accessibility preference. Sound, music, and
-- difficulty already live on child_profiles; this adds the missing persisted
-- display setting and grants the app only the columns exposed by settings.
ALTER TABLE child_profiles
  ADD COLUMN large_text_enabled boolean NOT NULL DEFAULT false;

GRANT UPDATE (
  difficulty,
  sound_enabled,
  music_enabled,
  large_text_enabled,
  updated_at
) ON child_profiles TO groshik_app;
