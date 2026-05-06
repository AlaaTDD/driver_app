-- Migration: Fix Messaging System Issues
-- Created: 2026-05-06
-- Scope: complaints, messages, notifications, support_messages, user_presence

-- ============================================
-- BUG #1: complaints.trip_id NOT NULL vs nullable code
-- ============================================
ALTER TABLE public.complaints ALTER COLUMN trip_id DROP NOT NULL;

-- ============================================
-- DB-1: Missing Index on notifications(user_id, created_at DESC)
-- ============================================
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC);

-- ============================================
-- DB-2: Missing Indexes on messages for direct chat
-- ============================================
CREATE INDEX IF NOT EXISTS idx_messages_direct_chat
  ON public.messages (sender_id, receiver_id, created_at ASC)
  WHERE trip_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_messages_sender
  ON public.messages (sender_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_receiver
  ON public.messages (receiver_id, created_at DESC);

-- ============================================
-- DB-3: Drop unused index idx_messages_trip_created (0 scans)
-- ============================================
DROP INDEX IF EXISTS public.idx_messages_trip_created;

-- ============================================
-- DB-5: Enable Realtime on support_messages
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;

-- ============================================
-- SEC-2: Revoke anon privileges from sensitive tables
-- ============================================
REVOKE ALL ON public.messages FROM anon;
REVOKE ALL ON public.notifications FROM anon;
REVOKE ALL ON public.support_messages FROM anon;
REVOKE ALL ON public.user_presence FROM anon;

-- Grant minimal needed access if any (currently none expected for anon)
-- GRANT SELECT, INSERT, UPDATE ON public.messages TO authenticated;
-- GRANT SELECT, INSERT, UPDATE ON public.notifications TO authenticated;
-- GRANT SELECT, INSERT, UPDATE ON public.support_messages TO authenticated;

-- ============================================
-- SEC-3: Fix user_presence — only authenticated can read
-- ============================================
DROP POLICY IF EXISTS "Anyone can read presence" ON public.user_presence;
CREATE POLICY IF NOT EXISTS "Authenticated can read presence"
  ON public.user_presence FOR SELECT
  TO authenticated
  USING (true);

-- ============================================
-- BUG #4 / Schema improvement: support_messages needs sender_id
-- To distinguish AI/admin replies from user messages properly
-- ============================================
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS sender_id uuid;

-- Update existing AI replies to have a known system sender
-- (Run this only if you want to fix existing data; otherwise skip)
-- UPDATE public.support_messages SET sender_id = '00000000-0000-0000-0000-000000000000' WHERE sender_role = 'support';

-- ============================================
-- Add RPC function for unread notifications count (BUG #6 fix)
-- ============================================
CREATE OR REPLACE FUNCTION public.get_unread_count(p_user_id uuid)
RETURNS integer AS $$
  SELECT COUNT(*)::integer FROM public.notifications 
  WHERE user_id = p_user_id AND is_read = false;
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================
-- Add RPC function for unread messages count per conversation
-- Used by Drawer badge and conversation list
-- ============================================
CREATE OR REPLACE FUNCTION public.get_unread_message_count(p_user_id uuid)
RETURNS TABLE(other_user_id uuid, unread_count bigint) AS $$
  SELECT sender_id, COUNT(*)::bigint
  FROM public.messages
  WHERE receiver_id = p_user_id AND is_read = false AND trip_id IS NULL
  GROUP BY sender_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================
-- CRITICAL DB-4: Drop unused index idx_notifications_user_unread (0 scans)
-- ============================================
DROP INDEX IF EXISTS public.idx_notifications_user_unread;

-- ============================================
-- CRITICAL 4.8: Fix CASCADE DELETE on messages FKs to preserve other party's history
-- Changing sender_id/receiver_id CASCADE → SET NULL so messages survive user deletion
-- ============================================
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_sender_id_fkey;
ALTER TABLE public.messages ADD CONSTRAINT messages_sender_id_fkey
  FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE SET NULL;

ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_receiver_id_fkey;
ALTER TABLE public.messages ADD CONSTRAINT messages_receiver_id_fkey
  FOREIGN KEY (receiver_id) REFERENCES public.users(id) ON DELETE SET NULL;

-- ============================================
-- 4.9 / Schema: Add read_at for real read receipts and soft-delete flags
-- ============================================
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS read_at timestamptz;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS deleted_by_sender boolean DEFAULT false;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS deleted_by_receiver boolean DEFAULT false;

-- ============================================
-- Prevent orphaned trip messages from appearing in direct chats
-- When trip_id becomes NULL (trip deleted), mark messages as deleted for both
-- (Alternatively, keep trip_id with a deleted_trips table — simpler is soft delete)
-- ============================================
-- NOTE: If you want to preserve trip messages even after trip deletion,
-- change messages_trip_id_fkey from SET NULL to: do nothing, or use a deleted flag.
-- The current SET NULL behavior makes messages appear in direct chat — BAD.
--
-- Option A: Keep trip_id even if trip deleted (use a shadow/archive table for trips)
-- Option B: When trip deleted, set deleted_by_sender=true AND deleted_by_receiver=true
--
-- For now, we add a trigger to auto-delete (soft) orphaned messages:
CREATE OR REPLACE FUNCTION public.soft_delete_orphan_messages()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.messages
  SET deleted_by_sender = true, deleted_by_receiver = true
  WHERE trip_id = OLD.id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_soft_delete_orphan_messages ON public.trips;
CREATE TRIGGER trigger_soft_delete_orphan_messages
  AFTER DELETE ON public.trips
  FOR EACH ROW
  EXECUTE FUNCTION public.soft_delete_orphan_messages();

-- ============================================
-- HIDDEN-6: Scheduled cleanup of stale user_presence
-- Requires pg_cron extension (available on Supabase)
-- ============================================
-- Note: Run this manually in Supabase SQL Editor or enable pg_cron:
-- SELECT cron.schedule('cleanup-stale-presence', '*/5 * * * *',
--   $$DELETE FROM public.user_presence WHERE last_seen < NOW() - INTERVAL '5 minutes';$$);
