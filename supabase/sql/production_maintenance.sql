-- Run manually in Supabase SQL Editor after reviewing live traffic windows.
-- These statements are intentionally outside migrations because VACUUM and
-- DROP INDEX CONCURRENTLY should not run inside a migration transaction.

-- 1) Confirm stats age before trusting unused-index counters.
SELECT stats_reset
FROM pg_stat_database
WHERE datname = current_database();

-- 2) Inspect duplicate/overloaded functions before changing any remaining ones.
SELECT
  p.proname,
  oidvectortypes(p.proargtypes) AS arguments,
  pg_get_functiondef(p.oid) AS definition
FROM pg_proc AS p
WHERE p.pronamespace = 'public'::regnamespace
  AND p.proname IN ('cancel_trip', 'get_nearby_drivers_secure')
ORDER BY p.proname, arguments;

-- 3) Confirm the only public table without RLS is the PostGIS system table.
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND rowsecurity = false
ORDER BY tablename;

-- 4) Immediate bloat cleanup from the audit.
VACUUM ANALYZE public.vehicle_types;
VACUUM ANALYZE public.users;
VACUUM ANALYZE public.trip_route_waypoints;
VACUUM ANALYZE public.driver_locations;
VACUUM ANALYZE public.pricing_config;
VACUUM ANALYZE public.trip_offers;
VACUUM ANALYZE public.trips;
VACUUM ANALYZE public.driver_wallets;

-- 5) Candidate unused indexes. Drop only after stats_reset proves counters are
-- old enough and workload is representative.
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_drivers_profile_vehicle_type;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_drivers_target_dest;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_trips_completed_driver;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_trips_completed_at;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_trip_offers_trip_driver_status;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_wt_wallet_created;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_wt_ref;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_wt_type;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_complaints_user;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_coupon_audit_log_coupon_id;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_coupon_audit_log_created_at;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_coupon_audit_log_event_type;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_coupon_usages_trip_id;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_dbl_rule;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_driver_locations_geohash;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_dsa_area;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_dsa_driver;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_notif_user_unread;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_trip_route_plans_status;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_trips_active_status;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_trips_area;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_trips_cancel_category;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_trips_coupon_discount;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_user_coupons_coupon_id;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_wr_pending;
