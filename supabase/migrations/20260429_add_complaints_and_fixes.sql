-- Migration: Add missing complaints table and fix support_messages schema

-- 1. Create complaints table
CREATE TABLE IF NOT EXISTS public.complaints (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    trip_id UUID REFERENCES public.trips(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'pending' NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    resolved_at TIMESTAMPTZ,
    admin_notes TEXT
);

-- RLS for complaints
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can create complaints" ON public.complaints;
CREATE POLICY "Users can create complaints"
ON public.complaints FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can read own complaints" ON public.complaints;
CREATE POLICY "Users can read own complaints"
ON public.complaints FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can read all complaints" ON public.complaints;
CREATE POLICY "Admins can read all complaints"
ON public.complaints FOR SELECT
TO authenticated
USING (is_admin_user());

DROP POLICY IF EXISTS "Admins can update complaints" ON public.complaints;
CREATE POLICY "Admins can update complaints"
ON public.complaints FOR UPDATE
TO authenticated
USING (is_admin_user())
WITH CHECK (is_admin_user());

-- 2. Add sender_role to support_messages
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'support_messages'
          AND column_name = 'sender_role'
    ) THEN
        ALTER TABLE public.support_messages ADD COLUMN sender_role VARCHAR(20) DEFAULT 'user';
    END IF;
END $$;

-- 3. Drop unused users_profile table as per audit
DROP TABLE IF EXISTS public.users_profile CASCADE;

-- 4. Fix trips table (add is_paid, cancelled_by) and drop legacy address fields
ALTER TABLE public.trips 
  ADD COLUMN IF NOT EXISTS is_paid BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS cancelled_by VARCHAR(50);

-- Safely drop legacy columns if they exist
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'origin_address') THEN
        DROP INDEX IF EXISTS public.idx_trips_origin_address;
        ALTER TABLE public.trips DROP COLUMN origin_address;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'dest_address') THEN
        DROP INDEX IF EXISTS public.idx_trips_dest_address;
        ALTER TABLE public.trips DROP COLUMN dest_address;
    END IF;
END $$;

-- 5. Create coupon_usages table for financial integrity
CREATE TABLE IF NOT EXISTS public.coupon_usages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    user_coupon_id UUID NOT NULL REFERENCES public.user_coupons(id) ON DELETE CASCADE,
    discount_amount NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.coupon_usages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own coupon usages" ON public.coupon_usages;
CREATE POLICY "Users can view own coupon usages"
ON public.coupon_usages FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.trips 
        WHERE trips.id = coupon_usages.trip_id AND trips.user_id = auth.uid()
    )
);

-- 6. Fix Vehicle types by adding missing columns
ALTER TABLE public.vehicle_types
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;
