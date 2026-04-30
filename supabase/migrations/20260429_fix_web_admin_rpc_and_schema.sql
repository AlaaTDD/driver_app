-- Migration: Fix web admin dashboard schema gaps and create missing RPCs
-- 1. Add missing columns to complaints table for admin dashboard features
-- 2. Create driver_revision_requests table
-- 3. Create missing admin RPCs: block_user, unblock_user, set_user_role, resolve_complaint, request_driver_revision

-- ============================================================
-- 1. Add missing columns to complaints table
-- ============================================================

ALTER TABLE complaints
ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'general',
ADD COLUMN IF NOT EXISTS priority VARCHAR(20) DEFAULT 'normal',
ADD COLUMN IF NOT EXISTS admin_reply TEXT,
ADD COLUMN IF NOT EXISTS replied_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS admin_id UUID REFERENCES users(id) ON DELETE SET NULL;

-- Index for common admin filters
CREATE INDEX IF NOT EXISTS idx_complaints_category ON complaints(category);
CREATE INDEX IF NOT EXISTS idx_complaints_priority ON complaints(priority);
CREATE INDEX IF NOT EXISTS idx_complaints_admin_id ON complaints(admin_id);

-- ============================================================
-- 2. Create driver_revision_requests table
-- ============================================================

CREATE TABLE IF NOT EXISTS driver_revision_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fields_requested TEXT[] NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_driver_revision_requests_driver_id ON driver_revision_requests(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_revision_requests_status ON driver_revision_requests(status);

-- Enable RLS
ALTER TABLE driver_revision_requests ENABLE ROW LEVEL SECURITY;

-- Only authenticated users can read their own requests; admins can read all
CREATE POLICY "Users read own revision requests"
    ON driver_revision_requests FOR SELECT
    USING (auth.uid() = driver_id OR is_admin_user());

CREATE POLICY "Admins insert revision requests"
    ON driver_revision_requests FOR INSERT
    WITH CHECK (is_admin_user());

CREATE POLICY "Admins update revision requests"
    ON driver_revision_requests FOR UPDATE
    USING (is_admin_user());

-- Grant table privileges
GRANT ALL ON driver_revision_requests TO authenticated;
GRANT ALL ON driver_revision_requests TO service_role;

-- ============================================================
-- 3. Create missing admin RPCs
-- ============================================================

-- block_user: blocks a user with optional reason, logs to admin_logs
CREATE OR REPLACE FUNCTION block_user(p_user_id UUID, p_reason TEXT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE users
    SET is_blocked = true,
        blocked_reason = p_reason,
        blocked_at = now()
    WHERE id = p_user_id;

    -- Log action
    INSERT INTO admin_logs (admin_id, action, table_name, record_id, new_data)
    VALUES (auth.uid(), 'block', 'users', p_user_id, jsonb_build_object('is_blocked', true, 'reason', p_reason));
END;
$$;

GRANT EXECUTE ON FUNCTION block_user(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION block_user(UUID, TEXT) TO service_role;

-- unblock_user: unblocks a user
CREATE OR REPLACE FUNCTION unblock_user(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE users
    SET is_blocked = false,
        blocked_reason = NULL,
        blocked_at = NULL
    WHERE id = p_user_id;

    INSERT INTO admin_logs (admin_id, action, table_name, record_id, new_data)
    VALUES (auth.uid(), 'unblock', 'users', p_user_id, jsonb_build_object('is_blocked', false));
END;
$$;

GRANT EXECUTE ON FUNCTION unblock_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION unblock_user(UUID) TO service_role;

-- set_user_role: changes user role (e.g., user -> driver or vice versa)
CREATE OR REPLACE FUNCTION set_user_role(p_user_id UUID, p_role VARCHAR)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE users
    SET role = p_role
    WHERE id = p_user_id;

    INSERT INTO admin_logs (admin_id, action, table_name, record_id, new_data)
    VALUES (auth.uid(), 'update', 'users', p_user_id, jsonb_build_object('role', p_role));
END;
$$;

GRANT EXECUTE ON FUNCTION set_user_role(UUID, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION set_user_role(UUID, VARCHAR) TO service_role;

-- resolve_complaint: admin resolves a complaint with reply
CREATE OR REPLACE FUNCTION resolve_complaint(
    p_complaint_id UUID,
    p_reply TEXT,
    p_status VARCHAR DEFAULT 'resolved'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE complaints
    SET admin_reply = p_reply,
        replied_at = now(),
        admin_id = auth.uid(),
        status = p_status,
        resolved_at = CASE WHEN p_status IN ('resolved', 'closed') THEN now() ELSE resolved_at END
    WHERE id = p_complaint_id;

    INSERT INTO admin_logs (admin_id, action, table_name, record_id, new_data)
    VALUES (auth.uid(), 'update', 'complaints', p_complaint_id, jsonb_build_object('status', p_status, 'admin_reply', p_reply));
END;
$$;

GRANT EXECUTE ON FUNCTION resolve_complaint(UUID, TEXT, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION resolve_complaint(UUID, TEXT, VARCHAR) TO service_role;

-- request_driver_revision: creates a driver revision request
CREATE OR REPLACE FUNCTION request_driver_revision(
    p_driver_id UUID,
    p_fields TEXT[],
    p_message TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request_id UUID;
BEGIN
    INSERT INTO driver_revision_requests (driver_id, fields_requested, message, status)
    VALUES (p_driver_id, p_fields, p_message, 'pending')
    RETURNING id INTO v_request_id;

    INSERT INTO admin_logs (admin_id, action, table_name, record_id, new_data)
    VALUES (auth.uid(), 'create', 'driver_revision_requests', v_request_id,
            jsonb_build_object('driver_id', p_driver_id, 'fields', p_fields, 'message', p_message));

    RETURN v_request_id;
END;
$$;

GRANT EXECUTE ON FUNCTION request_driver_revision(UUID, TEXT[], TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION request_driver_revision(UUID, TEXT[], TEXT) TO service_role;
