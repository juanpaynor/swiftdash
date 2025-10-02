-- Fix Missing Foreign Key Constraints
-- This script adds the missing foreign key constraint between deliveries and vehicle_types

-- 1. Add the missing foreign key constraint for deliveries.vehicle_type_id
ALTER TABLE public.deliveries 
ADD CONSTRAINT deliveries_vehicle_type_id_fkey 
FOREIGN KEY (vehicle_type_id) REFERENCES public.vehicle_types(id);

-- 2. Verify the constraint was added
-- Query to check if constraint exists:
SELECT 
conname as constraint_name,
conrelid::regclass as table_name,
confrelid::regclass as foreign_table_name
FROM pg_constraint 
WHERE conname = 'deliveries_vehicle_type_id_fkey';

-- 3. Also add missing driver_profiles constraints if needed
-- (The driver_profiles foreign key might also be missing)
ALTER TABLE public.driver_profiles 
ADD CONSTRAINT driver_profiles_vehicle_type_id_fkey 
FOREIGN KEY (vehicle_type_id) REFERENCES public.vehicle_types(id)
ON UPDATE CASCADE ON DELETE SET NULL;

-- 4. Add missing fields to driver_profiles if they don't exist
-- Check if columns exist first to avoid errors:
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'driver_profiles' 
                   AND column_name = 'is_available') THEN
        ALTER TABLE public.driver_profiles 
        ADD COLUMN is_available boolean DEFAULT false;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'driver_profiles' 
                   AND column_name = 'location_updated_at') THEN
        ALTER TABLE public.driver_profiles 
        ADD COLUMN location_updated_at timestamp with time zone DEFAULT now();
    END IF;
END
$$;

-- 5. Create performance indexes
CREATE INDEX IF NOT EXISTS idx_driver_profiles_availability 
ON public.driver_profiles(is_online, is_available) 
WHERE is_online = true AND is_available = true;

CREATE INDEX IF NOT EXISTS idx_driver_profiles_location 
ON public.driver_profiles(current_latitude, current_longitude) 
WHERE current_latitude IS NOT NULL AND current_longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_deliveries_driver_status 
ON public.deliveries(driver_id, status);

CREATE INDEX IF NOT EXISTS idx_deliveries_vehicle_type 
ON public.deliveries(vehicle_type_id);

-- 6. Insert some default vehicle types if the table is empty
INSERT INTO public.vehicle_types (id, name, description, max_weight_kg, base_price, price_per_km, is_active)
VALUES 
  (gen_random_uuid(), 'Motorcycle', 'Fast delivery for small packages', 20.0, 50.00, 8.00, true),
  (gen_random_uuid(), 'Car', 'Standard delivery for medium packages', 50.0, 80.00, 12.00, true),
  (gen_random_uuid(), 'Van', 'Large delivery for big packages', 200.0, 120.00, 15.00, true),
  (gen_random_uuid(), 'Truck', 'Heavy delivery for very large packages', 1000.0, 200.00, 20.00, true)
ON CONFLICT (name) DO NOTHING;