-- SECURITY DEFINER function to atomically accept a pending delivery.
-- Create this as a DB owner / admin. This function verifies auth.uid() = p_driver_id
-- and performs an atomic update only if the delivery is still pending.

CREATE OR REPLACE FUNCTION public.accept_delivery_offer(
  p_delivery_id UUID,
  p_driver_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
  -- Prevent impersonation: caller's auth.uid() must match provided driver id
  IF auth.uid() IS NULL OR auth.uid()::uuid <> p_driver_id::uuid THEN
    RAISE EXCEPTION 'unauthorized: caller does not match driver id';
  END IF;

  -- Try to update only if still pending and unassigned
  UPDATE public.deliveries
  SET
    status = 'driverAssigned',
    driver_id = p_driver_id,
    assigned_at = NOW(),
    updated_at = NOW()
  WHERE id = p_delivery_id
    AND status = 'pending'
    AND driver_id IS NULL;

  IF FOUND THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Notes:
-- 1. Run this using a DB owner / admin connection (pgAdmin / psql / Supabase SQL editor with an admin role).
-- 2. Add a row-level policy (RLS) that allows callers to execute the RPC when appropriate.
-- 3. Consider logging or events for accepted offers if you need auditing.
