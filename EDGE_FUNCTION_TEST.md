# Edge Function Direct Test

## Issue
Customer app finds driver but Edge Function returns 404

## Test Steps

### 1. Test Edge Function via Supabase Dashboard
Go to Edge Functions → pair_driver → Invoke

**Test Payload:**
```json
{
  "deliveryId": "e6c3f96a-84e9-41ed-96d3-a61185d0dd85"
}
```

### 2. Check Edge Function Logs
Look for any error messages in the logs

### 3. Verify Driver Status in Database
Run this SQL in Supabase SQL Editor:

```sql
-- Check exact driver status when pair_driver is called
SELECT 
  id,
  is_verified,
  is_online, 
  is_available,
  current_latitude,
  current_longitude,
  location_updated_at,
  CASE 
    WHEN current_latitude IS NULL OR current_longitude IS NULL THEN 'NO_LOCATION'
    WHEN NOT is_verified THEN 'NOT_VERIFIED'
    WHEN NOT is_online THEN 'OFFLINE'
    WHEN NOT is_available THEN 'BUSY'
    ELSE 'READY'
  END as status_check
FROM driver_profiles 
WHERE id = '3d778cea-7f1e-40cd-b1f3-3f25bfb72bf9';
```

### 4. Test Edge Function Query Directly
```sql
-- This is the exact query the Edge Function uses
SELECT 
  id, profile_picture_url, vehicle_model, ltfrb_number, rating, total_deliveries, is_verified,
  current_latitude, current_longitude, is_online, is_available, location_updated_at
FROM driver_profiles
WHERE is_available = true 
  AND is_online = true 
  AND is_verified = true 
  AND current_latitude IS NOT NULL
  AND current_longitude IS NOT NULL
ORDER BY location_updated_at DESC
LIMIT 10;
```

## Expected Results
- If driver shows in SQL but not in Edge Function → Edge Function deployment issue
- If driver missing from SQL → Driver app not updating status properly
- If both show driver → Race condition or transaction timing issue

## Next Actions Based on Results
1. **Driver in SQL + Edge Function works** → App-side issue
2. **Driver in SQL + Edge Function fails** → Function deployment issue  
3. **No driver in SQL** → Driver app database update issue