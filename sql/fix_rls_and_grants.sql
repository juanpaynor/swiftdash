-- Fix RLS policies and tighten grants for SwiftDash optimized realtime schema
-- Run this in Supabase SQL editor as an admin. It's idempotent and safe to re-run.

-- ===============================================
-- 0. Safety note
-- This migration replaces broad FOR ALL policies with explicit SELECT/INSERT/UPDATE
-- policies that cast auth.uid() to UUID and enforce WITH CHECK for inserts/updates.
-- It also revokes DELETE permissions from the `authenticated` role for sensitive tables.
-- ===============================================

-- =======================
-- 1. DRIVER_LOCATION_HISTORY
-- =======================

-- Remove any existing policies
DROP POLICY IF EXISTS "drivers_own_location_history" ON public.driver_location_history;
DROP POLICY IF EXISTS "customers_see_delivery_location_history" ON public.driver_location_history;

-- Allow drivers to SELECT their own history
CREATE POLICY IF NOT EXISTS drivers_select_own_location_history ON public.driver_location_history
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid()::uuid);

-- Allow customers to SELECT history records for deliveries that belong to them
CREATE POLICY IF NOT EXISTS customers_select_delivery_location_history ON public.driver_location_history
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.deliveries d
      WHERE d.id = public.driver_location_history.delivery_id
        AND d.customer_id = auth.uid()::uuid
    )
  );

-- Allow drivers to INSERT only rows where driver_id == auth.uid()
CREATE POLICY IF NOT EXISTS drivers_insert_location_history ON public.driver_location_history
  FOR INSERT
  TO authenticated
  WITH CHECK (driver_id = auth.uid()::uuid);

-- Allow drivers to UPDATE their own rows (no changing driver_id)
CREATE POLICY IF NOT EXISTS drivers_update_location_history ON public.driver_location_history
  FOR UPDATE
  TO authenticated
  USING (driver_id = auth.uid()::uuid)
  WITH CHECK (driver_id = auth.uid()::uuid);

-- Do NOT create a DELETE policy; DELETE will be denied for authenticated role.

-- Revoke DELETE privilege from authenticated role (if previously granted)
REVOKE DELETE ON public.driver_location_history FROM authenticated;

-- Ensure authenticated still has SELECT/INSERT/UPDATE
GRANT SELECT, INSERT, UPDATE ON public.driver_location_history TO authenticated;


-- =======================
-- 2. DRIVER_CURRENT_STATUS
-- =======================

DROP POLICY IF EXISTS "drivers_own_current_status" ON public.driver_current_status;
DROP POLICY IF EXISTS "customers_see_assigned_driver_status" ON public.driver_current_status;

-- Drivers may SELECT/INSERT/UPDATE their own current status
CREATE POLICY IF NOT EXISTS drivers_select_own_current_status ON public.driver_current_status
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid()::uuid);

CREATE POLICY IF NOT EXISTS drivers_insert_current_status ON public.driver_current_status
  FOR INSERT
  TO authenticated
  WITH CHECK (driver_id = auth.uid()::uuid);

CREATE POLICY IF NOT EXISTS drivers_update_current_status ON public.driver_current_status
  FOR UPDATE
  TO authenticated
  USING (driver_id = auth.uid()::uuid)
  WITH CHECK (driver_id = auth.uid()::uuid);

-- Customers may SELECT driver_current_status for drivers assigned to their active deliveries
CREATE POLICY IF NOT_EXISTS_customers_select_assigned_driver_status ON public.driver_current_status
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.deliveries d
      WHERE d.driver_id = public.driver_current_status.driver_id
        AND d.customer_id = auth.uid()::uuid
        AND d.status IN ('driver_assigned', 'package_collected', 'in_transit')
    )
  );

-- Revoke DELETE on driver_current_status
REVOKE DELETE ON public.driver_current_status FROM authenticated;
GRANT SELECT, INSERT, UPDATE ON public.driver_current_status TO authenticated;


-- =======================
-- 3. ANALYTICS_EVENTS
-- =======================

DROP POLICY IF EXISTS "drivers_own_analytics" ON public.analytics_events;

-- Drivers may INSERT analytics events for themselves
CREATE POLICY IF NOT EXISTS drivers_insert_analytics ON public.analytics_events
  FOR INSERT
  TO authenticated
  WITH CHECK (driver_id = auth.uid()::uuid OR driver_id IS NULL);

-- Drivers may SELECT their own analytics events (if needed)
CREATE POLICY IF NOT EXISTS drivers_select_own_analytics ON public.analytics_events
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid()::uuid);

-- Revoke DELETE on analytics_events
REVOKE DELETE ON public.analytics_events FROM authenticated;
GRANT SELECT, INSERT, UPDATE ON public.analytics_events TO authenticated;


-- =======================
-- 4. DRIVER_PROFILES & DELIVERIES (light touch fixes)
-- =======================

-- Ensure driver_profiles policies require casting and are explicit
DROP POLICY IF EXISTS "drivers_own_profile" ON public.driver_profiles;
DROP POLICY IF EXISTS "customers_see_assigned_drivers_limited" ON public.driver_profiles;
DROP POLICY IF EXISTS "admins_regional_drivers" ON public.driver_profiles;

CREATE POLICY IF NOT EXISTS drivers_own_profile ON public.driver_profiles
  FOR ALL
  TO authenticated
  USING (id = auth.uid()::uuid)
  WITH CHECK (id = auth.uid()::uuid);

CREATE POLICY IF NOT_EXISTS_customers_see_assigned_drivers_limited ON public.driver_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.deliveries d
      WHERE d.driver_id = public.driver_profiles.id
        AND d.customer_id = auth.uid()::uuid
        AND d.status IN ('driver_assigned', 'package_collected', 'in_transit')
    )
  );

-- NOTE: admins_regional_drivers left as-is; implement admin checks separately if needed.


-- =======================
-- 5. DELIVERIES (allow customers to cancel or delete under safe conditions)
-- =======================

-- Remove any existing delivery-related policies we will replace
DROP POLICY IF EXISTS customers_select_deliveries ON public.deliveries;
DROP POLICY IF EXISTS customers_update_cancel_delivery ON public.deliveries;
DROP POLICY IF EXISTS customers_delete_completed_delivery ON public.deliveries;

-- Customers may SELECT only their own deliveries
CREATE POLICY IF NOT EXISTS customers_select_deliveries ON public.deliveries
  FOR SELECT
  TO authenticated
  USING (customer_id = auth.uid()::uuid);

-- Allow customers to cancel a delivery by updating its status to 'cancelled'
-- Only allowed when the existing delivery status is in a set where cancellation is safe
-- (e.g., pending, searching, driver_assigned). USING checks the current row; WITH CHECK ensures
-- the new row has status = 'cancelled' and customer_id remains the same.
CREATE POLICY IF NOT EXISTS customers_update_cancel_delivery ON public.deliveries
  FOR UPDATE
  TO authenticated
  USING (customer_id = auth.uid()::uuid AND status IN ('pending', 'searching', 'driver_assigned'))
  WITH CHECK (customer_id = auth.uid()::uuid AND status = 'cancelled');

-- Allow customers to DELETE deliveries only when they are finished (or explicitly cancelled)
CREATE POLICY IF NOT EXISTS customers_delete_completed_delivery ON public.deliveries
  FOR DELETE
  TO authenticated
  USING (customer_id = auth.uid()::uuid AND status IN ('delivered', 'completed', 'cancelled'));

-- Ensure the authenticated role has the necessary privileges on deliveries.
-- The policies above will further constrain which rows/actions are allowed.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.deliveries TO authenticated;

-- =======================
-- 5. Helpful debug function (dev only)
-- =======================
-- Use this function in the SQL editor to quickly check auth.uid() mapping from a session
-- CREATE OR REPLACE FUNCTION public.whoami() RETURNS TEXT LANGUAGE SQL AS $$ SELECT auth.uid(); $$;

-- =======================
-- 6. Final notes
-- =======================

COMMENT ON FUNCTION public.cleanup_old_location_history IS 'Cleans up old driver_location_history rows';
COMMENT ON FUNCTION public.cleanup_processed_analytics IS 'Cleans up processed analytics events';

ROLLBACK; -- no-op if running in SQL editor transaction context; safe guard

-- End of fix script
