-- Migration: Add cancel_trip RPC function for atomic, race-safe trip cancellation
-- Date: 2026-04-29
-- Fix: P0-02 and P0-05

CREATE OR REPLACE FUNCTION cancel_trip(
    p_trip_id UUID,
    p_user_id UUID,
    p_cancelled_by TEXT,
    p_cancel_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_status TEXT;
    v_trip_user_id UUID;
    v_success BOOLEAN := FALSE;
BEGIN
    -- Get current trip status and owner with row lock
    SELECT status, user_id
    INTO v_current_status, v_trip_user_id
    FROM trips
    WHERE id = p_trip_id
    FOR UPDATE;

    -- Check if trip exists
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trip not found';
    END IF;

    -- Verify ownership
    IF v_trip_user_id != p_user_id THEN
        RAISE EXCEPTION 'Unauthorized: not trip owner';
    END IF;

    -- Validate status can be cancelled (searching or accepted only)
    IF v_current_status NOT IN ('searching', 'accepted') THEN
        RAISE EXCEPTION 'Cannot cancel trip with status: %', v_current_status;
    END IF;

    -- Perform atomic update
    UPDATE trips
    SET 
        status = 'cancelled',
        cancelled_at = NOW(),
        cancelled_by = p_cancelled_by,
        cancel_reason = p_cancel_reason,
        updated_at = NOW()
    WHERE id = p_trip_id
      AND status IN ('searching', 'accepted');  -- Guard against race conditions

    -- Check if update succeeded
    IF FOUND THEN
        v_success := TRUE;
    ELSE
        RAISE EXCEPTION 'Trip status changed concurrently, cancellation failed';
    END IF;

    RETURN v_success;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION cancel_trip(UUID, UUID, TEXT, TEXT) TO authenticated;

COMMENT ON FUNCTION cancel_trip IS 
'Atomically cancels a trip with ownership verification and race condition protection.
Returns true on success, raises exception on failure (not found, unauthorized, invalid status, or race condition).';

-- ────────────────────────────────────────────────────────────────────────────
-- Migration: Add set_driver_online RPC function (FIX P1-09)
-- Replaces direct .update() with atomic RPC for consistency with pushLocation
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION set_driver_online(
    p_driver_id UUID,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_geohash TEXT,
    p_geohash5 TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE drivers_profile
    SET 
        is_available = true,
        current_lat = p_lat,
        current_lng = p_lng,
        geohash = p_geohash,
        geohash5 = p_geohash5,
        updated_at = NOW()
    WHERE id = p_driver_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Driver profile not found for %', p_driver_id;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION set_driver_online(UUID, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT) TO authenticated;

COMMENT ON FUNCTION set_driver_online IS 
'Atomically sets driver online with location and geohash update. Enforces existence check.';

-- ────────────────────────────────────────────────────────────────────────────
-- Migration: Add set_driver_offline RPC function (FIX P1-09 companion)
-- Replaces direct .update() with atomic RPC for driver offline action.
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION set_driver_offline(
    p_driver_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE drivers_profile
    SET 
        is_available = false,
        current_lat = null,
        current_lng = null,
        geohash = null,
        geohash5 = null,
        updated_at = NOW()
    WHERE id = p_driver_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Driver profile not found for %', p_driver_id;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION set_driver_offline(UUID) TO authenticated;

COMMENT ON FUNCTION set_driver_offline IS 
'Atomically sets driver offline and clears location/geohash fields. Enforces existence check.';
