-- Idempotent SQL to ensure realtime publication and recommended indexes.
-- Safe to run multiple times in Supabase SQL Editor.

-- Create tables if they don't exist (minimal definitions to avoid accidental data loss).
-- If your actual schema differs, skip these CREATE TABLEs and run index/publication only.

CREATE TABLE IF NOT EXISTS public.driver_current_status (
  driver_id UUID PRIMARY KEY,
  current_latitude DOUBLE PRECISION,
  current_longitude DOUBLE PRECISION,
  status TEXT,
  last_updated TIMESTAMPTZ,
  battery_level INT,
  app_version TEXT,
  device_info TEXT,
  current_delivery_id UUID
);

CREATE TABLE IF NOT EXISTS public.driver_location_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL,
  delivery_id UUID,
  event_type TEXT NOT NULL,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  event_ts TIMESTAMPTZ DEFAULT NOW(),
  meta JSONB
);

CREATE TABLE IF NOT EXISTS public.analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed BOOLEAN DEFAULT FALSE
);

-- Create useful indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_driver_current_status_last_updated ON public.driver_current_status(last_updated);
CREATE INDEX IF NOT EXISTS idx_driver_location_history_driver_ts ON public.driver_location_history(driver_id, event_ts);
CREATE INDEX IF NOT EXISTS idx_analytics_events_created_at ON public.analytics_events(created_at);

-- Ensure publication exists for logical replication / realtime
-- Supabase Realtime uses publications; add tables to a publication used by Realtime.
-- Replace "supabase_realtime" with your publication name if different.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END$$;

-- Add tables to publication if not already included
-- This operation is idempotent because IF NOT EXISTS checks the membership.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'driver_current_status') THEN
    CALL pg_catalog.pg_add_to_publication('driver_current_status', 'supabase_realtime');
  END IF;
EXCEPTION WHEN undefined_function THEN
  -- Older Postgres versions may not have pg_add_to_publication callable directly.
  -- Fall back to using ALTER PUBLICATION ... ADD TABLE if available.
  BEGIN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_current_status';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Failed to add driver_current_status to publication; please add it manually if needed.';
  END;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'driver_location_history') THEN
    CALL pg_catalog.pg_add_to_publication('driver_location_history', 'supabase_realtime');
  END IF;
EXCEPTION WHEN undefined_function THEN
  BEGIN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_location_history';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Failed to add driver_location_history to publication; please add it manually if needed.';
  END;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'analytics_events') THEN
    CALL pg_catalog.pg_add_to_publication('analytics_events', 'supabase_realtime');
  END IF;
EXCEPTION WHEN undefined_function THEN
  BEGIN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.analytics_events';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Failed to add analytics_events to publication; please add it manually if needed.';
  END;
END$$;

-- End of script
