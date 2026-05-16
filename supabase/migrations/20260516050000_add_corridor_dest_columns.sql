-- Migration: add target_dest_lat / target_dest_lng to drivers_profile
-- Needed by the new _CorridorPickerScreen (two-tap free selection)
-- The origin columns already exist; this adds the missing destination pair.

ALTER TABLE drivers_profile
  ADD COLUMN IF NOT EXISTS target_dest_lat  DOUBLE PRECISION DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS target_dest_lng  DOUBLE PRECISION DEFAULT NULL;

-- Optional: spatial index for future PostGIS corridor matching on destination
CREATE INDEX IF NOT EXISTS idx_drivers_target_dest
  ON drivers_profile (target_dest_lat, target_dest_lng)
  WHERE target_dest_lat IS NOT NULL AND target_dest_lng IS NOT NULL;

COMMENT ON COLUMN drivers_profile.target_dest_lat
  IS 'Latitude of the driver''s preferred corridor destination point';
COMMENT ON COLUMN drivers_profile.target_dest_lng
  IS 'Longitude of the driver''s preferred corridor destination point';
