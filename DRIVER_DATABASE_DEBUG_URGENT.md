# 🚨 DRIVER DATABASE DEBUG - URGENT

**Issue:** Customer app still shows "no drivers found" despite driver app being online  
**Date:** October 9, 2025  

## Live Database Debug Query

Run this EXACT query in your Supabase SQL editor to see what drivers exist:

```sql
-- Check what drivers are actually in the database
SELECT 
  id,
  is_verified,
  is_online, 
  is_available,
  current_latitude,
  current_longitude,
  location_updated_at,
  vehicle_type_id,
  created_at
FROM driver_profiles 
ORDER BY created_at DESC;
```

## Expected vs Reality Check

**Customer App Needs:**
```sql
SELECT * FROM driver_profiles 
WHERE is_verified = true 
  AND is_online = true 
  AND is_available = true 
  AND current_latitude IS NOT NULL 
  AND current_longitude IS NOT NULL;
```

**❌ Common Issues We'll Find:**

1. **No driver records exist**
   - Driver app isn't creating records in `driver_profiles`
   - Using wrong table or wrong user ID

2. **Wrong boolean values**
   - `is_verified = false` (should be `true`)
   - `is_online = false` (should be `true`)  
   - `is_available = false` (should be `true`)

3. **Missing GPS coordinates**
   - `current_latitude = NULL`
   - `current_longitude = NULL`

4. **Wrong user ID**
   - Driver app creating records with wrong `id`
   - Not matching `auth.users.id`

## Quick Fix SQL (Run if needed)

If you find driver records but with wrong values:

```sql
-- Fix existing driver (replace YOUR_DRIVER_ID)
UPDATE driver_profiles SET 
  is_verified = true,
  is_online = true,
  is_available = true,
  current_latitude = 14.5995,  -- Manila coordinates for testing
  current_longitude = 120.9842,
  location_updated_at = NOW()
WHERE id = 'YOUR_DRIVER_ID';
```

## Test the Customer App Query

After fixing, test this exact query (what customer app runs):

```sql
-- This is EXACTLY what the customer app searches for
SELECT 
  id, is_verified, is_online, is_available,
  current_latitude, current_longitude, location_updated_at
FROM driver_profiles 
WHERE is_available = true
  AND is_online = true  
  AND is_verified = true
  AND current_latitude IS NOT NULL
  AND current_longitude IS NOT NULL
ORDER BY location_updated_at DESC
LIMIT 10;
```

**Expected Result:** Should return at least 1 driver record

## Driver App Instructions

**The driver app MUST do this when going online:**

```sql
-- 1. Create/Update driver profile
INSERT INTO driver_profiles (
  id,                    -- MUST be auth.users.id
  is_verified,           -- MUST be true
  is_online,             -- MUST be true  
  is_available,          -- MUST be true
  current_latitude,      -- MUST have real GPS
  current_longitude,     -- MUST have real GPS
  location_updated_at,   -- MUST be recent
  vehicle_type_id        -- MUST reference valid vehicle_type
) VALUES (
  auth.user.id,          -- From Supabase auth
  true,                  -- Verified driver
  true,                  -- Online
  true,                  -- Available
  14.5995,              -- Real latitude
  120.9842,             -- Real longitude  
  NOW(),                -- Current timestamp
  'vehicle-type-uuid'   -- Valid vehicle type ID
)
ON CONFLICT (id) DO UPDATE SET
  is_online = true,
  is_available = true,
  current_latitude = EXCLUDED.current_latitude,
  current_longitude = EXCLUDED.current_longitude,
  location_updated_at = NOW();
```

## Immediate Action Required

**Please run the debug query above and report back:**

1. ✅ How many driver records exist?
2. ✅ What are the exact values for the boolean fields?
3. ✅ Are GPS coordinates populated?
4. ✅ Is `location_updated_at` recent?

**This will immediately show us why the customer app can't find drivers!**

---
**Customer App Team - October 9, 2025**