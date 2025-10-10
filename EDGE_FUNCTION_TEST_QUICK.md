# Test Edge Function Directly

## Quick Test via Supabase Dashboard

Go to Supabase Dashboard > Edge Functions > pair_driver > Invoke

**Test Payload:**
```json
{
  "deliveryId": "e6c3f96a-84e9-41ed-96d3-a61185d0dd85"
}
```

Then check the function logs to see the exact 500 error details.

## Alternative: Rollback to Working Version

If we need to fix immediately, we can rollback to the previous working version temporarily:

```typescript
// Quick rollback - change status back to 'driver_assigned'
status: 'driver_assigned'  // Instead of 'driver_offered'
```

This will restore functionality while we debug the exact 500 error.