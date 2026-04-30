-- Migration: Add notifications table to supabase_realtime publication
-- Date: 2026-04-29
-- Fix: final_gap_report.md #4 — notifications table was not in realtime publication

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
        RAISE NOTICE 'Added notifications to supabase_realtime publication';
    ELSE
        RAISE NOTICE 'notifications already in supabase_realtime publication';
    END IF;
END $$;
