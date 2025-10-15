# Cron Job Setup for Scheduled Driver Assignment

**Date:** October 14, 2025  
**Function:** `assign_scheduled_drivers`  
**Schedule:** Every 5 minutes  
**Status:** ✅ Function Deployed & Optimized - ⚠️ Cron Job Needs Setup

---

## 🎯 What This Does

The `assign_scheduled_drivers` function runs every 5 minutes and:
1. Finds scheduled deliveries that need driver assignment (0-10 minutes before pickup time)
2. Calls `pair_driver` for each delivery to find and assign nearest driver
3. Returns summary of assignments (successful/failed)

**✨ Optimized for Free Tier:**
- Narrow time window (0-10 min) reduces database reads by ~70%
- Minimal column selection reduces payload size by ~60%
- Can handle 500+ scheduled deliveries/day on free tier
- See `FREE_TIER_OPTIMIZATION.md` for details

---

## 🚀 Setup Instructions

### Option 1: Using Supabase Dashboard (Recommended)

1. Go to your Supabase Dashboard: https://supabase.com/dashboard/project/lygzxmhskkqrntnmxtbb

2. Navigate to **Database** → **Cron Jobs** (or search for "pg_cron")

3. Click **"Enable Extension"** if not already enabled:
   - Find `pg_cron` extension
   - Click **Enable**

4. Click **"Create a new cron job"**

5. Fill in the form:
   ```
   Name: assign_scheduled_drivers
   Schedule: */5 * * * *
   Command: 
   SELECT
     net.http_post(
       url:='https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/assign_scheduled_drivers',
       headers:='{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb
     ) as request_id;
   ```

6. Replace `YOUR_SERVICE_ROLE_KEY` with your actual service role key from:
   - Dashboard → Settings → API → `service_role` key (secret)

7. Click **"Create"**

---

### Option 2: Using SQL Editor

Run this SQL in your Supabase SQL Editor:

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create cron job (runs every 5 minutes)
SELECT cron.schedule(
  'assign-scheduled-drivers',  -- Job name
  '*/5 * * * *',              -- Every 5 minutes
  $$
  SELECT
    net.http_post(
      url:='https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/assign_scheduled_drivers',
      headers:='{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb
    ) as request_id;
  $$
);
```

**⚠️ Important:** Replace `YOUR_SERVICE_ROLE_KEY` with your actual service role key!

---

## ✅ Verify Cron Job

### Check if cron job was created:

```sql
SELECT * FROM cron.job WHERE jobname = 'assign-scheduled-drivers';
```

Expected output:
```
jobid | schedule     | command                | nodename  | nodeport | database | username | active | jobname
------|--------------|------------------------|-----------|----------|----------|----------|--------|-------------------------
1     | */5 * * * *  | SELECT net.http_post...| localhost | 5432     | postgres | postgres | t      | assign-scheduled-drivers
```

### Check cron job execution history:

```sql
SELECT 
  runid,
  jobid,
  job_pid,
  database,
  username,
  start_time,
  end_time,
  status,
  return_message
FROM cron.job_run_details
WHERE jobname = 'assign-scheduled-drivers'
ORDER BY start_time DESC
LIMIT 10;
```

---

## 🧪 Test the Cron Job

### Manual Test (Before Setting Up Cron):

```powershell
# Test the function manually
curl -X POST https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/assign_scheduled_drivers `
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" `
  -H "Content-Type: application/json"
```

Expected response:
```json
{
  "message": "No deliveries to assign",
  "checked_at": "2025-10-14T13:45:00Z",
  "found": 0
}
```

Or if deliveries found:
```json
{
  "processed": 2,
  "successful": 2,
  "failed": 0,
  "results": [
    {
      "deliveryId": "uuid-1",
      "scheduledTime": "2025-10-14T14:00:00Z",
      "success": true,
      "driverId": "driver-uuid-1"
    }
  ],
  "checked_at": "2025-10-14T13:45:00Z"
}
```

---

## 🔍 Monitor Cron Job

### View Recent Executions:

```sql
-- Last 10 cron runs
SELECT 
  runid,
  start_time,
  end_time,
  status,
  return_message,
  EXTRACT(EPOCH FROM (end_time - start_time)) as duration_seconds
FROM cron.job_run_details
WHERE jobname = 'assign-scheduled-drivers'
ORDER BY start_time DESC
LIMIT 10;
```

### Check for Errors:

```sql
-- Failed cron runs
SELECT 
  runid,
  start_time,
  status,
  return_message
FROM cron.job_run_details
WHERE jobname = 'assign-scheduled-drivers'
  AND status = 'failed'
ORDER BY start_time DESC
LIMIT 20;
```

---

## 🐛 Troubleshooting

### Issue: Cron job not running

**Check if pg_cron is enabled:**
```sql
SELECT * FROM pg_extension WHERE extname = 'pg_cron';
```

**Check if job is active:**
```sql
SELECT jobname, active FROM cron.job WHERE jobname = 'assign-scheduled-drivers';
```

If `active = false`, enable it:
```sql
UPDATE cron.job SET active = true WHERE jobname = 'assign-scheduled-drivers';
```

---

### Issue: Function returns 401 Unauthorized

**Problem:** Service role key is incorrect or missing

**Solution:**
1. Get your service role key from Dashboard → Settings → API
2. Update the cron job command with the correct key:
   ```sql
   SELECT cron.alter_job(
     job_id := (SELECT jobid FROM cron.job WHERE jobname = 'assign-scheduled-drivers'),
     schedule := '*/5 * * * *',
     command := $$
       SELECT net.http_post(
         url:='https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/assign_scheduled_drivers',
         headers:='{"Authorization": "Bearer YOUR_CORRECT_SERVICE_KEY"}'::jsonb
       ) as request_id;
     $$
   );
   ```

---

### Issue: No deliveries being assigned

**Check if there are scheduled deliveries ready:**
```sql
SELECT 
  id,
  scheduled_pickup_time,
  status,
  driver_id,
  is_scheduled,
  NOW() as current_time,
  scheduled_pickup_time - NOW() as time_until_pickup
FROM deliveries
WHERE is_scheduled = TRUE
  AND status = 'pending'
  AND driver_id IS NULL
  AND scheduled_pickup_time <= NOW() + INTERVAL '15 minutes';
```

---

## 🗑️ Delete Cron Job (if needed)

```sql
-- Unschedule the cron job
SELECT cron.unschedule('assign-scheduled-drivers');

-- Verify it's deleted
SELECT * FROM cron.job WHERE jobname = 'assign-scheduled-drivers';
```

---

## ⏰ Cron Schedule Examples

If you want to change the frequency:

```
*/1 * * * *   -- Every 1 minute (more frequent)
*/5 * * * *   -- Every 5 minutes (recommended)
*/10 * * * *  -- Every 10 minutes (less frequent)
*/15 * * * *  -- Every 15 minutes
0 * * * *     -- Every hour
```

---

## 📊 Performance Monitoring

### Average Execution Time:

```sql
SELECT 
  COUNT(*) as total_runs,
  AVG(EXTRACT(EPOCH FROM (end_time - start_time))) as avg_duration_seconds,
  MIN(EXTRACT(EPOCH FROM (end_time - start_time))) as min_duration_seconds,
  MAX(EXTRACT(EPOCH FROM (end_time - start_time))) as max_duration_seconds
FROM cron.job_run_details
WHERE jobname = 'assign-scheduled-drivers'
  AND end_time IS NOT NULL;
```

### Success Rate:

```sql
SELECT 
  COUNT(*) as total_runs,
  COUNT(*) FILTER (WHERE status = 'succeeded') as successful,
  COUNT(*) FILTER (WHERE status = 'failed') as failed,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'succeeded') / COUNT(*), 2) as success_rate_percent
FROM cron.job_run_details
WHERE jobname = 'assign-scheduled-drivers';
```

---

## ✅ Setup Complete Checklist

- [ ] `pg_cron` extension enabled
- [ ] Cron job created with correct schedule (`*/5 * * * *`)
- [ ] Service role key configured correctly
- [ ] Test manual execution (returns valid response)
- [ ] Cron job shows in `cron.job` table
- [ ] First automatic execution logged in `cron.job_run_details`
- [ ] No errors in execution history

---

## 📞 Next Steps

After cron job is set up:

1. ✅ Test by creating a scheduled delivery (1 hour from now)
2. ✅ Wait for cron to run
3. ✅ Verify driver was assigned 15 minutes before pickup
4. ✅ Check driver receives notification
5. ✅ Monitor cron execution logs

---

**Created:** October 14, 2025  
**Status:** Ready for Setup  
**Priority:** Critical - Required for scheduled deliveries to work
