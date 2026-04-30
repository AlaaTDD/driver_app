-- Migration: Fix remaining schema-code consistency issues
-- 1. Grant authenticated users EXECUTE on cleanup_stuck_trips (called from Flutter app startup)
-- 2. Add trigger to sync user_coupons.is_used with used_at for consistency
-- 3. Backfill existing rows where is_used is out of sync

-- ============================================================
-- 1. cleanup_stuck_trips privileges
-- ============================================================

-- Grant authenticated role permission to execute the RPC called on app startup
GRANT EXECUTE ON FUNCTION cleanup_stuck_trips() TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_stuck_trips() TO anon;
GRANT EXECUTE ON FUNCTION cleanup_stuck_trips() TO PUBLIC;

-- ============================================================
-- 2. user_coupons is_used / used_at sync trigger
-- ============================================================

-- Create function that keeps is_used boolean in sync with used_at timestamp
CREATE OR REPLACE FUNCTION sync_user_coupon_is_used()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  NEW.is_used := (NEW.used_at IS NOT NULL);
  RETURN NEW;
END;
$$;

-- Drop existing trigger if any (idempotent)
DROP TRIGGER IF EXISTS trg_sync_user_coupon_is_used ON user_coupons;

-- Create trigger to sync on every insert / update
CREATE TRIGGER trg_sync_user_coupon_is_used
  BEFORE INSERT OR UPDATE ON user_coupons
  FOR EACH ROW
  EXECUTE FUNCTION sync_user_coupon_is_used();

-- ============================================================
-- 3. Backfill existing rows
-- ============================================================

UPDATE user_coupons
SET is_used = (used_at IS NOT NULL)
WHERE is_used IS DISTINCT FROM (used_at IS NOT NULL);
