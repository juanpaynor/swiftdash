-- ============================================================================
-- Schedule-in-Advance Feature - Database Migration
-- Date: October 14, 2025
-- Description: Add scheduling support to deliveries table
-- ============================================================================

-- Add scheduling columns to deliveries table
ALTER TABLE deliveries 
  ADD COLUMN IF NOT EXISTS is_scheduled BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS scheduled_pickup_time TIMESTAMPTZ;

-- Add comment to columns
COMMENT ON COLUMN deliveries.is_scheduled IS 'Whether this delivery is scheduled for a future time';
COMMENT ON COLUMN deliveries.scheduled_pickup_time IS 'Scheduled pickup time (driver will be assigned 15 minutes before)';

-- Create index for scheduled deliveries query (used by cron job)
CREATE INDEX IF NOT EXISTS idx_deliveries_scheduled 
  ON deliveries(scheduled_pickup_time) 
  WHERE is_scheduled = TRUE AND status = 'pending';

-- Create index for upcoming scheduled deliveries (used by customer app)
CREATE INDEX IF NOT EXISTS idx_deliveries_scheduled_upcoming 
  ON deliveries(scheduled_pickup_time, status) 
  WHERE is_scheduled = TRUE;

-- Create index for customer's scheduled deliveries list
CREATE INDEX IF NOT EXISTS idx_deliveries_customer_scheduled
  ON deliveries(customer_id, scheduled_pickup_time)
  WHERE is_scheduled = TRUE;

-- ============================================================================
-- Row Level Security (RLS) - No changes needed
-- Existing RLS policies will automatically apply to new columns
-- ============================================================================

-- Verify RLS is enabled
SELECT 
  schemaname, 
  tablename, 
  rowsecurity 
FROM pg_tables 
WHERE tablename = 'deliveries';

-- ============================================================================
-- Grant permissions (if needed)
-- ============================================================================

-- Ensure service role can update scheduling fields
GRANT UPDATE (is_scheduled, scheduled_pickup_time) ON deliveries TO service_role;

-- ============================================================================
-- Verification Query
-- ============================================================================

-- Check if columns were added successfully
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'deliveries' 
  AND column_name IN ('is_scheduled', 'scheduled_pickup_time');

-- Check if indexes were created
SELECT 
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'deliveries'
  AND indexname LIKE 'idx_deliveries_scheduled%';

-- ============================================================================
-- Test Data (Optional - for testing)
-- ============================================================================

-- Example: Create a scheduled delivery (for testing)
/*
INSERT INTO deliveries (
  customer_id,
  pickup_address,
  pickup_latitude,
  pickup_longitude,
  dropoff_address,
  dropoff_latitude,
  dropoff_longitude,
  is_scheduled,
  scheduled_pickup_time,
  status,
  total_price
) VALUES (
  '00000000-0000-0000-0000-000000000000', -- Replace with actual customer_id
  '123 Test St, Manila',
  14.5995,
  120.9842,
  '456 Test Ave, Manila',
  14.6091,
  120.9823,
  TRUE,
  NOW() + INTERVAL '2 hours', -- Scheduled for 2 hours from now
  'pending',
  150.00
);
*/

-- ============================================================================
-- Rollback Script (if needed)
-- ============================================================================

/*
-- Drop indexes
DROP INDEX IF EXISTS idx_deliveries_scheduled;
DROP INDEX IF EXISTS idx_deliveries_scheduled_upcoming;
DROP INDEX IF EXISTS idx_deliveries_customer_scheduled;

-- Drop columns
ALTER TABLE deliveries 
  DROP COLUMN IF EXISTS is_scheduled,
  DROP COLUMN IF EXISTS scheduled_pickup_time;
*/
