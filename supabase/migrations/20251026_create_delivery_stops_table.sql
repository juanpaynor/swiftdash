-- ============================================================================
-- MULTI-STOP DELIVERY SYSTEM
-- Migration: Create delivery_stops table for unlimited multi-stop deliveries
-- Date: 2025-10-26
-- ============================================================================

-- Create delivery_stops table
CREATE TABLE IF NOT EXISTS public.delivery_stops (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  delivery_id UUID NOT NULL,
  stop_number INTEGER NOT NULL,
  stop_type TEXT NOT NULL DEFAULT 'dropoff', -- 'pickup' or 'dropoff'
  
  -- Address details
  address TEXT NOT NULL,
  latitude NUMERIC(10, 8) NOT NULL,
  longitude NUMERIC(11, 8) NOT NULL,
  
  -- Optional detailed address components
  house_number TEXT NULL,
  street TEXT NULL,
  barangay TEXT NULL,
  city TEXT NULL,
  province TEXT NULL,
  
  -- Contact information
  recipient_name TEXT NOT NULL,
  recipient_phone TEXT NOT NULL,
  delivery_notes TEXT NULL,
  
  -- Status tracking
  status TEXT NOT NULL DEFAULT 'pending',
  arrived_at TIMESTAMP WITH TIME ZONE NULL,
  completed_at TIMESTAMP WITH TIME ZONE NULL,
  
  -- Proof of delivery
  proof_photo_url TEXT NULL,
  signature_url TEXT NULL,
  completion_notes TEXT NULL,
  
  -- Package details (optional per stop)
  package_description TEXT NULL,
  package_weight NUMERIC(8, 2) NULL,
  
  -- Estimated info
  estimated_arrival TIMESTAMP WITH TIME ZONE NULL,
  distance_from_previous_km NUMERIC(8, 2) NULL,
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT delivery_stops_pkey PRIMARY KEY (id),
  CONSTRAINT delivery_stops_delivery_id_fkey FOREIGN KEY (delivery_id) 
    REFERENCES deliveries(id) ON DELETE CASCADE,
  CONSTRAINT delivery_stops_stop_type_check CHECK (
    stop_type IN ('pickup', 'dropoff')
  ),
  CONSTRAINT delivery_stops_status_check CHECK (
    status IN ('pending', 'in_progress', 'arrived', 'completed', 'failed', 'skipped')
  ),
  CONSTRAINT delivery_stops_stop_number_positive CHECK (stop_number > 0)
) TABLESPACE pg_default;

-- ============================================================================
-- INDEXES for Performance
-- ============================================================================

-- Index for fetching stops by delivery
CREATE INDEX IF NOT EXISTS idx_delivery_stops_by_delivery 
  ON public.delivery_stops USING btree (delivery_id, stop_number ASC)
  TABLESPACE pg_default;

-- Index for active stops (pending/in_progress)
CREATE INDEX IF NOT EXISTS idx_delivery_stops_active 
  ON public.delivery_stops USING btree (delivery_id, status, stop_number)
  TABLESPACE pg_default
  WHERE status IN ('pending', 'in_progress');

-- Index for stop type filtering
CREATE INDEX IF NOT EXISTS idx_delivery_stops_by_type 
  ON public.delivery_stops USING btree (delivery_id, stop_type, stop_number)
  TABLESPACE pg_default;

-- Index for geolocation queries
CREATE INDEX IF NOT EXISTS idx_delivery_stops_location 
  ON public.delivery_stops USING btree (latitude, longitude)
  TABLESPACE pg_default;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_delivery_stops_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_delivery_stops_updated_at
  BEFORE UPDATE ON delivery_stops
  FOR EACH ROW
  EXECUTE FUNCTION update_delivery_stops_updated_at();

-- Trigger to update delivery's current_stop_index when a stop is completed
CREATE OR REPLACE FUNCTION update_delivery_current_stop()
RETURNS TRIGGER AS $$
BEGIN
  -- When a stop is marked as completed, update the delivery's current_stop_index
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    UPDATE deliveries
    SET current_stop_index = NEW.stop_number
    WHERE id = NEW.delivery_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_delivery_current_stop
  AFTER UPDATE ON delivery_stops
  FOR EACH ROW
  EXECUTE FUNCTION update_delivery_current_stop();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS
ALTER TABLE public.delivery_stops ENABLE ROW LEVEL SECURITY;

-- Policy: Customers can view stops for their own deliveries
CREATE POLICY "Customers can view their delivery stops"
  ON public.delivery_stops
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM deliveries
      WHERE deliveries.id = delivery_stops.delivery_id
      AND deliveries.customer_id = auth.uid()
    )
  );

-- Policy: Drivers can view stops for their assigned deliveries
CREATE POLICY "Drivers can view assigned delivery stops"
  ON public.delivery_stops
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM deliveries
      WHERE deliveries.id = delivery_stops.delivery_id
      AND deliveries.driver_id = auth.uid()
    )
  );

-- Policy: Drivers can update stops for their assigned deliveries
CREATE POLICY "Drivers can update assigned delivery stops"
  ON public.delivery_stops
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM deliveries
      WHERE deliveries.id = delivery_stops.delivery_id
      AND deliveries.driver_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM deliveries
      WHERE deliveries.id = delivery_stops.delivery_id
      AND deliveries.driver_id = auth.uid()
    )
  );

-- Policy: System can insert stops (via Edge Functions with service role)
-- No explicit INSERT policy needed - will be done via service role

-- Policy: System can delete stops (cascades from delivery deletion)
-- No explicit DELETE policy needed - will cascade from deliveries

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to get all stops for a delivery in order
CREATE OR REPLACE FUNCTION get_delivery_stops(p_delivery_id UUID)
RETURNS TABLE (
  id UUID,
  stop_number INTEGER,
  stop_type TEXT,
  address TEXT,
  latitude NUMERIC,
  longitude NUMERIC,
  recipient_name TEXT,
  recipient_phone TEXT,
  status TEXT,
  completed_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ds.id,
    ds.stop_number,
    ds.stop_type,
    ds.address,
    ds.latitude,
    ds.longitude,
    ds.recipient_name,
    ds.recipient_phone,
    ds.status,
    ds.completed_at
  FROM delivery_stops ds
  WHERE ds.delivery_id = p_delivery_id
  ORDER BY ds.stop_number ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get next pending stop for a delivery
CREATE OR REPLACE FUNCTION get_next_delivery_stop(p_delivery_id UUID)
RETURNS TABLE (
  id UUID,
  stop_number INTEGER,
  stop_type TEXT,
  address TEXT,
  latitude NUMERIC,
  longitude NUMERIC,
  recipient_name TEXT,
  recipient_phone TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ds.id,
    ds.stop_number,
    ds.stop_type,
    ds.address,
    ds.latitude,
    ds.longitude,
    ds.recipient_name,
    ds.recipient_phone
  FROM delivery_stops ds
  WHERE ds.delivery_id = p_delivery_id
    AND ds.status IN ('pending', 'in_progress')
  ORDER BY ds.stop_number ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to count remaining stops
CREATE OR REPLACE FUNCTION count_remaining_stops(p_delivery_id UUID)
RETURNS INTEGER AS $$
DECLARE
  remaining_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO remaining_count
  FROM delivery_stops
  WHERE delivery_id = p_delivery_id
    AND status IN ('pending', 'in_progress');
  
  RETURN remaining_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE public.delivery_stops IS 'Individual stops for multi-stop deliveries';
COMMENT ON COLUMN public.delivery_stops.stop_number IS 'Sequential order of stops (1, 2, 3, ...)';
COMMENT ON COLUMN public.delivery_stops.stop_type IS 'Type of stop: pickup or dropoff';
COMMENT ON COLUMN public.delivery_stops.status IS 'Current status: pending, in_progress, arrived, completed, failed, skipped';
COMMENT ON COLUMN public.delivery_stops.distance_from_previous_km IS 'Distance from previous stop in kilometers';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant access to authenticated users (via RLS policies)
GRANT SELECT ON public.delivery_stops TO authenticated;
GRANT UPDATE ON public.delivery_stops TO authenticated;

-- Grant full access to service role (for Edge Functions)
GRANT ALL ON public.delivery_stops TO service_role;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
