-- Migration for Issue 5: Target Route Corridor

ALTER TABLE drivers_profile ADD COLUMN IF NOT EXISTS target_route_radius_km DOUBLE PRECISION DEFAULT 3.0;
ALTER TABLE drivers_profile ADD COLUMN IF NOT EXISTS target_origin_lat DOUBLE PRECISION;
ALTER TABLE drivers_profile ADD COLUMN IF NOT EXISTS target_origin_lng DOUBLE PRECISION;
ALTER TABLE drivers_profile ADD COLUMN IF NOT EXISTS target_origin_radius_km DOUBLE PRECISION DEFAULT 2.0;

DROP FUNCTION IF EXISTS matches_driver_corridor;

CREATE OR REPLACE FUNCTION matches_driver_corridor(
  p_driver_id UUID,
  p_pickup_lat FLOAT, p_pickup_lng FLOAT,
  p_dest_lat FLOAT, p_dest_lng FLOAT
) RETURNS BOOLEAN AS $$
DECLARE
  v_driver RECORD;
  v_pickup_match BOOLEAN;
  v_dest_match BOOLEAN;
BEGIN
  -- Get active target route
  SELECT * INTO v_driver 
  FROM drivers_profile 
  WHERE id = p_driver_id AND target_route_active = true;
  
  IF NOT FOUND THEN
    RETURN TRUE; -- No target route set, meaning driver accepts all requests
  END IF;
  
  -- Check Origin Match using PostGIS
  IF v_driver.target_origin_lat IS NOT NULL AND v_driver.target_origin_lng IS NOT NULL THEN
     v_pickup_match := ST_DistanceSphere(
        ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326),
        ST_SetSRID(ST_MakePoint(v_driver.target_origin_lng, v_driver.target_origin_lat), 4326)
     ) <= (COALESCE(v_driver.target_origin_radius_km, 2.0) * 1000);
  ELSE
     v_pickup_match := TRUE;
  END IF;

  -- Check Destination Match using PostGIS
  IF v_driver.target_route_lat IS NOT NULL AND v_driver.target_route_lng IS NOT NULL THEN
     v_dest_match := ST_DistanceSphere(
        ST_SetSRID(ST_MakePoint(p_dest_lng, p_dest_lat), 4326),
        ST_SetSRID(ST_MakePoint(v_driver.target_route_lng, v_driver.target_route_lat), 4326)
     ) <= (COALESCE(v_driver.target_route_radius_km, 3.0) * 1000);
  ELSE
     v_dest_match := TRUE;
  END IF;

  RETURN v_pickup_match AND v_dest_match;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
