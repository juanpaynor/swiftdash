# Database Schema Fixes for Driver Integration

## Required Updates to Support Driver App Integration

### 1. Add Missing Fields to driver_profiles

```sql
-- Add is_available field (critical for pair_driver function)
ALTER TABLE public.driver_profiles 
ADD COLUMN is_available boolean DEFAULT false;

-- Add location_updated_at field (needed for location freshness)
ALTER TABLE public.driver_profiles 
ADD COLUMN location_updated_at timestamp with time zone DEFAULT now();

-- Add foreign key constraint for vehicle_type_id
ALTER TABLE public.driver_profiles 
ADD CONSTRAINT driver_profiles_vehicle_type_id_fkey 
FOREIGN KEY (vehicle_type_id) REFERENCES vehicle_types(id);
```

### 2. Update deliveries table driver_id reference

The current schema should work, but let's verify the reference:
```sql
-- Current: driver_id references driver_profiles(id)
-- driver_profiles.id references auth.users(id)
-- This creates a chain: deliveries.driver_id -> driver_profiles.id -> auth.users.id
-- Should work, but we need to ensure driver_profiles.id = auth.users.id for drivers
```

### 3. Create Indexes for Performance

```sql
-- Index for pair_driver function queries
CREATE INDEX idx_driver_profiles_availability 
ON driver_profiles(is_online, is_available) 
WHERE is_online = true AND is_available = true;

-- Index for location-based queries
CREATE INDEX idx_driver_profiles_location 
ON driver_profiles(current_latitude, current_longitude) 
WHERE current_latitude IS NOT NULL AND current_longitude IS NOT NULL;

-- Index for delivery assignments
CREATE INDEX idx_deliveries_driver_status 
ON deliveries(driver_id, status);

-- Index for real-time subscriptions
CREATE INDEX idx_deliveries_realtime 
ON deliveries(driver_id, status, updated_at);
```

### 4. Optional: PostGIS Enhancement

For better distance calculations:
```sql
-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Add geometry column for faster spatial queries
ALTER TABLE driver_profiles 
ADD COLUMN location_point geometry(POINT, 4326);

-- Create spatial index
CREATE INDEX idx_driver_profiles_location_point 
ON driver_profiles USING GIST(location_point);

-- Create the find_nearest_drivers function
CREATE OR REPLACE FUNCTION find_nearest_drivers(
  pickup_lat decimal,
  pickup_lng decimal, 
  max_distance_km decimal DEFAULT 50,
  limit_count integer DEFAULT 5
)
RETURNS TABLE(driver_id uuid, distance decimal)
LANGUAGE SQL
AS $$
  SELECT 
    dp.id as driver_id,
    ST_Distance(
      ST_MakePoint(dp.current_longitude, dp.current_latitude)::geography,
      ST_MakePoint(pickup_lng, pickup_lat)::geography
    ) / 1000 as distance
  FROM driver_profiles dp
  WHERE dp.is_online = true 
    AND dp.is_available = true
    AND dp.current_latitude IS NOT NULL
    AND dp.current_longitude IS NOT NULL
  ORDER BY distance ASC
  LIMIT limit_count;
$$;
```

## Schema Compatibility Summary

### ✅ Compatible Tables:
- `deliveries` - Perfect match for integration
- `vehicle_types` - Exactly what we need
- `user_profiles` - Good for user management
- `addresses` - Useful for address management
- `delivery_tracking` - Great for tracking history

### 🔧 Needs Updates:
- `driver_profiles` - Missing `is_available` and `location_updated_at`
- Missing indexes for performance
- Optional PostGIS enhancement

### 🎯 Driver App Integration Requirements Met:
- ✅ Real-time subscriptions on `deliveries` table
- ✅ Status flow matches exactly
- ✅ Location tracking via `driver_profiles`
- 🔧 Need to add `is_available` field
- 🔧 Need to add `location_updated_at` field

## Next Steps:
1. Apply the missing field additions
2. Create performance indexes  
3. Test driver profile creation
4. Verify real-time subscriptions work
5. Begin integration testing