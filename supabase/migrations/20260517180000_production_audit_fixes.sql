-- Production audit fixes from docs/Snapix_*_v11/v12.
-- Safe schema/data changes only. Run maintenance commands from
-- supabase/sql/production_maintenance.sql after reviewing live stats.

-- users.is_admin must be boolean NOT NULL with a deterministic default.
UPDATE public.users
SET is_admin = false
WHERE is_admin IS NULL;

ALTER TABLE public.users
  ALTER COLUMN is_admin SET DEFAULT false,
  ALTER COLUMN is_admin SET NOT NULL;

-- Seed the default operating area around the current fallback map center
-- (Riyadh). Admins can add smaller areas later without breaking dispatch.
INSERT INTO public.service_areas (
  name,
  name_ar,
  code,
  geohash_prefixes,
  boundary,
  is_active
)
SELECT
  'Riyadh Core',
  'منطقة الرياض الرئيسية',
  'RIYADH_CORE',
  ARRAY['th3', 'th5']::text[],
  ST_SetSRID(
    ST_GeomFromText(
      'POLYGON((46.15 24.35, 47.20 24.35, 47.20 25.05, 46.15 25.05, 46.15 24.35))'
    ),
    4326
  ),
  true
WHERE NOT EXISTS (
  SELECT 1 FROM public.service_areas WHERE code = 'RIYADH_CORE'
);

-- Backfill trips.service_area_id using the seeded/defined active boundaries.
UPDATE public.trips AS t
SET service_area_id = matched.id
FROM LATERAL (
  SELECT sa.id
  FROM public.service_areas AS sa
  WHERE sa.is_active = true
    AND sa.boundary IS NOT NULL
    AND ST_Contains(
      sa.boundary,
      ST_SetSRID(ST_MakePoint(t.destination_lng, t.destination_lat), 4326)
    )
  LIMIT 1
) AS matched
WHERE t.service_area_id IS NULL
  AND t.destination_lng IS NOT NULL
  AND t.destination_lat IS NOT NULL;

-- Remove orphan withdrawal transaction references before enforcing the FK.
UPDATE public.withdrawal_requests AS wr
SET transaction_id = NULL
WHERE wr.transaction_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.wallet_transactions AS wt
    WHERE wt.id = wr.transaction_id
  );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_withdrawal_requests_transaction'
  ) THEN
    ALTER TABLE public.withdrawal_requests
      ADD CONSTRAINT fk_withdrawal_requests_transaction
      FOREIGN KEY (transaction_id)
      REFERENCES public.wallet_transactions(id)
      ON DELETE SET NULL;
  END IF;
END $$;

-- Keep one canonical cancel_trip implementation. The varchar overload only
-- delegates to the text overload and can confuse PostgREST function resolution.
DROP FUNCTION IF EXISTS public.cancel_trip(
  uuid,
  uuid,
  character varying,
  character varying
);

-- Schedule weekly vacuum/analyze if pg_cron is available.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron')
     AND NOT EXISTS (
       SELECT 1 FROM cron.job WHERE jobname = 'weekly-core-vacuum'
     ) THEN
    PERFORM cron.schedule(
      'weekly-core-vacuum',
      '0 3 * * 0',
      'VACUUM ANALYZE public.trips, public.users, public.trip_offers, public.vehicle_types, public.driver_locations, public.pricing_config, public.trip_route_waypoints, public.driver_wallets'
    );
  END IF;
END $$;
