-- Driver App Integration: Database Schema Updates
-- Run these in Supabase SQL Editor

-- 1. Enhance driver_profiles table with new fields
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS profile_picture_url TEXT;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS vehicle_picture_url TEXT; 
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS ltfrb_number TEXT;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false;

-- 2. Create driver_earnings table for tip integration
CREATE TABLE IF NOT EXISTS driver_earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID REFERENCES driver_profiles(id) ON DELETE CASCADE,
  delivery_id UUID REFERENCES deliveries(id) ON DELETE CASCADE,
  base_earnings NUMERIC(10,2) NOT NULL,
  distance_earnings NUMERIC(10,2) NOT NULL,
  surge_earnings NUMERIC(10,2) DEFAULT 0,
  tips NUMERIC(10,2) DEFAULT 0,
  total_earnings NUMERIC(10,2) NOT NULL,
  earnings_date DATE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create performance indexes
CREATE INDEX IF NOT EXISTS idx_driver_earnings_driver_date ON driver_earnings(driver_id, earnings_date);
CREATE INDEX IF NOT EXISTS idx_driver_earnings_delivery ON driver_earnings(delivery_id);
CREATE INDEX IF NOT EXISTS idx_driver_earnings_created_at ON driver_earnings(created_at);

-- 4. Create delivery_events table for tip prompts and notifications
CREATE TABLE IF NOT EXISTS delivery_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_id UUID REFERENCES deliveries(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES driver_profiles(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- 'tip_prompt', 'rating_request', etc.
  event_data JSONB,
  processed BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Create notifications table for driver notifications
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID REFERENCES driver_profiles(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  type TEXT NOT NULL, -- 'tip_received', 'delivery_assigned', 'rating_received'
  read BOOLEAN DEFAULT false,
  data JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Create indexes for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_driver_unread ON notifications(driver_id, read, created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_customer ON notifications(customer_id, created_at);

-- 7. Create storage bucket for driver documents (if not exists)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('driver-documents', 'driver-documents', true)
ON CONFLICT (id) DO NOTHING;

-- 8. Set up Row Level Security (RLS) policies
ALTER TABLE driver_earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for driver_earnings
CREATE POLICY "Drivers can view their own earnings" ON driver_earnings
  FOR SELECT USING (driver_id = auth.uid());

CREATE POLICY "Service role can manage earnings" ON driver_earnings
  FOR ALL USING (auth.role() = 'service_role');

-- RLS Policies for delivery_events  
CREATE POLICY "Users can view their delivery events" ON delivery_events
  FOR SELECT USING (
    customer_id = auth.uid() OR 
    driver_id = auth.uid() OR
    auth.role() = 'service_role'
  );

CREATE POLICY "Service role can manage delivery events" ON delivery_events
  FOR ALL USING (auth.role() = 'service_role');

-- RLS Policies for notifications
CREATE POLICY "Users can view their notifications" ON notifications
  FOR SELECT USING (
    driver_id = auth.uid() OR 
    customer_id = auth.uid() OR
    auth.role() = 'service_role'
  );

CREATE POLICY "Users can update their notifications" ON notifications
  FOR UPDATE USING (
    driver_id = auth.uid() OR 
    customer_id = auth.uid()
  );

CREATE POLICY "Service role can manage notifications" ON notifications
  FOR ALL USING (auth.role() = 'service_role');

-- 9. Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 10. Create trigger for driver_earnings updated_at
CREATE TRIGGER update_driver_earnings_updated_at 
  BEFORE UPDATE ON driver_earnings 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 11. Add comments for documentation
COMMENT ON TABLE driver_earnings IS 'Tracks driver earnings per delivery including tips';
COMMENT ON TABLE delivery_events IS 'Stores delivery-related events like tip prompts';
COMMENT ON TABLE notifications IS 'Push notifications for drivers and customers';

-- 12. Insert default vehicle types if not exists (for testing)
INSERT INTO vehicle_types (name, description, base_price, price_per_km, estimated_time_minutes)
VALUES 
  ('Motorcycle', 'Fast delivery for small packages', 50.00, 8.00, 30),
  ('Car', 'Standard delivery for medium packages', 80.00, 12.00, 45),
  ('Van', 'Large delivery for big packages', 120.00, 15.00, 60)
ON CONFLICT (name) DO NOTHING;