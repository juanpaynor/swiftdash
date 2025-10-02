# Integration Test Setup

## 1. Create Test Driver Profile

```sql
-- First, create a test user in auth.users (if not exists)
-- This should be done through Supabase Auth UI or your driver app signup

-- Then create the driver profile
INSERT INTO public.driver_profiles (
  id,                    -- This should match the auth.users.id
  vehicle_type_id,       -- Get from vehicle_types table
  license_number,
  vehicle_model,
  is_verified,
  is_online,
  is_available,          -- NEW FIELD ✅
  current_latitude,
  current_longitude,
  location_updated_at,   -- NEW FIELD ✅
  rating,
  total_deliveries
) VALUES (
  'auth-user-uuid-here',  -- Replace with actual auth user ID
  (SELECT id FROM vehicle_types WHERE name = 'Motorcycle' LIMIT 1),
  'TEST-LIC-001',
  'Honda Click 125',
  true,
  true,
  true,                   -- Available for assignment
  14.5995,               -- Manila coordinates
  121.0581,
  now(),
  4.8,
  0
);
```

## 2. Create Test Vehicle Type (if needed)

```sql
-- Ensure we have a vehicle type
INSERT INTO public.vehicle_types (
  name,
  description,
  max_weight_kg,
  base_price,
  price_per_km,
  is_active
) VALUES (
  'Motorcycle',
  'Fast delivery for small packages',
  10.00,
  30.00,
  8.50,
  true
) ON CONFLICT DO NOTHING;
```

## 3. Test the Integration Flow

### Step 1: Create Test Delivery
```sql
-- This will be done through your customer app
-- book_delivery function will create with status = 'pending'
```

### Step 2: Test pair_driver Function
```bash
# Call via your customer app or curl
curl -X POST https://[your-project].supabase.co/functions/v1/pair_driver \
  -H "Authorization: Bearer [your-token]" \
  -H "Content-Type: application/json" \
  -d '{"deliveryId": "test-delivery-uuid"}'
```

### Step 3: Verify Driver App Receives Assignment
- Driver app should detect delivery assignment via realtime subscription
- Offer modal should appear with 5-minute timer
- Route preview should load correctly

## 4. Testing Checklist

### Database Verification ✅
- [x] driver_profiles has is_available field
- [x] driver_profiles has location_updated_at field  
- [x] vehicle_type_id foreign key exists
- [ ] Test driver profile created
- [ ] Test vehicle type exists

### Function Testing
- [ ] pair_driver finds available drivers
- [ ] Assignment updates delivery status to 'driver_assigned'
- [ ] Driver app receives realtime notification
- [ ] Offer modal displays correctly

### Integration Flow
- [ ] Driver accept updates status to 'pickup_arrived'
- [ ] Driver decline resets to 'pending' for reassignment  
- [ ] Location updates work every 15 seconds
- [ ] Customer app shows driver location

## 5. Next Steps
1. Create test driver profile
2. Test pair_driver function manually
3. Coordinate with driver app for live test
4. Verify complete delivery flow