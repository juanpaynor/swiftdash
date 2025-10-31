# 🚏 Multi-Stop Delivery Coordination (Driver App ↔ Customer App)

**Date**: October 31, 2025  
**From**: Customer App Team  
**To**: Driver App Team  
**Priority**: 🔴 **HIGH** - Required for multi-stop deliveries

---

## ✅ What We Just Fixed (Customer App)

### 1. **CRITICAL: Edge Function Now Creates Pickup Stop**
- ✅ Fixed `book_multi_stop_delivery` Edge Function
- ✅ Now creates pickup stop as stop #1
- ✅ Dropoffs start at stop #2, #3, #4, etc.
- ✅ `total_stops` now correctly includes pickup

**Before** (BROKEN):
```
delivery_stops table:
- Stop #1: dropoff (WRONG!)
- Stop #2: dropoff
- Stop #3: dropoff
```

**After** (FIXED):
```
delivery_stops table:
- Stop #1: pickup ✅
- Stop #2: dropoff ✅
- Stop #3: dropoff ✅
- Stop #4: dropoff ✅
```

### 2. **NEW: Stop Status Update Handling**
- ✅ Added `stop-update` Ably event subscription
- ✅ Added stop status update UI logic
- ✅ Individual stop statuses now update in real-time
- ✅ Shows notifications when stops are completed

---

## 🔥 CRITICAL: What We Need From You

### **Question 1: Do You Publish Stop-Specific Updates?**

When a driver completes stop #2 in a 4-stop delivery, do you:

**Option A**: Publish stop-specific event to Ably?
```typescript
// Via Ably: tracking:{deliveryId} channel
ably.publish('stop-update', {
  delivery_id: 'xxx',
  stop_id: 'yyy',
  stop_number: 2,
  status: 'completed',
  timestamp: '2025-10-31T10:30:00Z'
})
```

**Option B**: Only update overall delivery status?
```typescript
// Via Ably: tracking:{deliveryId} channel
ably.publish('status-update', {
  delivery_id: 'xxx',
  status: 'in_transit', // Generic status
  timestamp: '2025-10-31T10:30:00Z'
})
```

**Option C**: Not implemented yet?

---

### **Question 2: How Do You Track Current Stop?**

When driver is at stop #2 of 4 stops, do you:

**Option A**: Update `delivery_stops` table for each stop?
```sql
-- When arriving at stop #2
UPDATE delivery_stops 
SET status = 'in_progress', arrived_at = NOW()
WHERE id = 'stop_2_id';

-- When completing stop #2
UPDATE delivery_stops 
SET status = 'completed', completed_at = NOW()
WHERE id = 'stop_2_id';
```

**Option B**: Update `deliveries.current_stop_index`?
```sql
UPDATE deliveries 
SET current_stop_index = 2
WHERE id = 'delivery_id';
```

**Option C**: Both A and B?

**Option D**: Not implemented yet?

---

### **Question 3: Multi-Stop Status Flow**

What is your status flow for a 3-stop delivery (1 pickup + 2 dropoffs)?

**Our Expected Flow**:
```
1. Driver accepts delivery
   → Overall status: 'driver_assigned'
   → Stop #1 (pickup): 'pending'
   → Stop #2 (dropoff): 'pending'
   → Stop #3 (dropoff): 'pending'

2. Driver heads to pickup
   → Overall status: 'going_to_pickup'
   → Stop #1: 'in_progress'?
   → Stops #2-3: 'pending'

3. Driver arrives at pickup
   → Overall status: 'at_pickup'
   → Stop #1: 'arrived'?
   → Stops #2-3: 'pending'

4. Driver collects package
   → Overall status: 'package_collected'
   → Stop #1: 'completed' ✅
   → Stop #2: 'in_progress'?
   → Stop #3: 'pending'

5. Driver heads to dropoff #1
   → Overall status: 'in_transit'
   → Stop #1: 'completed' ✅
   → Stop #2: 'in_progress'
   → Stop #3: 'pending'

6. Driver arrives at dropoff #1
   → Overall status: 'at_destination'
   → Stop #1: 'completed' ✅
   → Stop #2: 'arrived'?
   → Stop #3: 'pending'

7. Driver completes dropoff #1
   → Overall status: 'in_transit' (still more stops)
   → Stop #1: 'completed' ✅
   → Stop #2: 'completed' ✅
   → Stop #3: 'in_progress'

8. Driver arrives at dropoff #2
   → Overall status: 'at_destination'
   → Stops #1-2: 'completed' ✅
   → Stop #3: 'arrived'?

9. Driver completes dropoff #2
   → Overall status: 'delivered' (all done)
   → Stops #1-3: 'completed' ✅✅✅
```

**Is this correct? Please clarify!**

---

## 📡 Ably Event Specifications

### **Event: `stop-update`** (NEW - Please Implement)

**Channel**: `tracking:{deliveryId}`

**When to Publish**:
- Driver arrives at a stop
- Driver marks stop as completed
- Driver skips a stop (if supported)
- Stop status changes for any reason

**Payload Format** (Requested):
```typescript
{
  delivery_id: string,        // UUID of delivery
  stop_id: string,            // UUID of stop from delivery_stops table
  stop_number: number,        // 1, 2, 3, 4, etc.
  status: string,             // 'pending' | 'in_progress' | 'arrived' | 'completed' | 'failed' | 'skipped'
  timestamp: string,          // ISO 8601 format
  location?: {                // Optional: driver location at stop
    latitude: number,
    longitude: number
  },
  notes?: string              // Optional: completion notes
}
```

**Example Payloads**:
```typescript
// Driver arrives at pickup (stop #1)
{
  delivery_id: '550e8400-e29b-41d4-a716-446655440000',
  stop_id: 'aaaa-bbbb-cccc-dddd',
  stop_number: 1,
  status: 'in_progress',
  timestamp: '2025-10-31T10:00:00Z'
}

// Driver completes pickup
{
  delivery_id: '550e8400-e29b-41d4-a716-446655440000',
  stop_id: 'aaaa-bbbb-cccc-dddd',
  stop_number: 1,
  status: 'completed',
  timestamp: '2025-10-31T10:05:00Z',
  notes: 'Package collected successfully'
}

// Driver completes dropoff #1 (stop #2)
{
  delivery_id: '550e8400-e29b-41d4-a716-446655440000',
  stop_id: 'eeee-ffff-gggg-hhhh',
  stop_number: 2,
  status: 'completed',
  timestamp: '2025-10-31T10:30:00Z',
  location: {
    latitude: 14.5995,
    longitude: 120.9842
  }
}
```

---

## 🗄️ Database Updates

### **Stop Status Updates**

Based on your `DRIVER_APP_STATUS_UPDATE_COORDINATION.md`:
- ✅ Intermediate statuses → **Ably ONLY** (no database)
- ✅ Final statuses → **Ably + Database**

**Question**: Are stop statuses "intermediate" or "final"?

**Our Recommendation**:
- Stop `in_progress`, `arrived` → **Ably ONLY** (intermediate)
- Stop `completed`, `failed`, `skipped` → **Ably + Database** (final)

**Example**:
```typescript
// When driver completes stop #2
// 1. Publish to Ably (for real-time UI)
await ably.publish('stop-update', {
  stop_id: 'xxx',
  stop_number: 2,
  status: 'completed',
  timestamp: new Date().toISOString()
});

// 2. Write to database (for persistence)
await supabase
  .from('delivery_stops')
  .update({
    status: 'completed',
    completed_at: new Date().toISOString()
  })
  .eq('id', 'xxx');

// 3. Update current_stop_index
await supabase
  .from('deliveries')
  .update({ current_stop_index: 2 })
  .eq('id', deliveryId);
```

---

## 🔄 Expected Ably Event Sequence

For a 2-stop delivery (1 pickup + 1 dropoff):

```
📡 Ably Events Timeline:

1. location-update (driver moving to pickup)
2. status-update { status: 'going_to_pickup' }
3. stop-update { stop_number: 1, status: 'in_progress' } ← NEW
4. location-update (driver at pickup)
5. status-update { status: 'at_pickup' }
6. stop-update { stop_number: 1, status: 'completed' } ← NEW
7. status-update { status: 'package_collected' }
8. location-update (driver moving to dropoff)
9. stop-update { stop_number: 2, status: 'in_progress' } ← NEW
10. status-update { status: 'in_transit' }
11. location-update (driver at dropoff)
12. status-update { status: 'at_destination' }
13. stop-update { stop_number: 2, status: 'completed' } ← NEW
14. status-update { status: 'delivered' }
```

---

## 🎯 Customer App Implementation Status

### ✅ Already Implemented

1. **Ably Subscription**:
   - ✅ Listening to `tracking:{deliveryId}` channel
   - ✅ Subscribed to `location-update` events
   - ✅ Subscribed to `status-update` events
   - ✅ **NEW**: Subscribed to `stop-update` events

2. **Stop Status Handling**:
   - ✅ `_updateStopStatus()` method implemented
   - ✅ Updates local `_stops` list
   - ✅ Shows notifications when stops complete
   - ✅ Checks if all stops completed

3. **UI Updates**:
   - ✅ Multi-stop progress indicator
   - ✅ Stop list with status badges
   - ✅ Map shows all stop markers
   - ✅ Current stop highlighting

### ⏳ Waiting For

1. **Driver App Implementation**:
   - ⏳ Publish `stop-update` events to Ably
   - ⏳ Update `delivery_stops` table (completed stops)
   - ⏳ Update `deliveries.current_stop_index`
   - ⏳ Confirm status flow for multi-stop

2. **Testing**:
   - ⏳ End-to-end multi-stop delivery test
   - ⏳ Verify stop updates arrive correctly
   - ⏳ Verify UI updates in real-time

---

## 🧪 Testing Plan

Once you implement `stop-update` events:

### **Test 1: Basic Multi-Stop Flow**
1. Create delivery with 1 pickup + 2 dropoffs
2. Driver accepts and starts delivery
3. Customer app should show:
   - ✅ 3 stops in list (1 pickup + 2 dropoffs)
   - ✅ Stop #1 highlighted as current
   - ✅ All stops marked "pending"

4. Driver arrives at pickup
5. Customer app should receive `stop-update` event
6. UI should show stop #1 as "in progress"

7. Driver completes pickup
8. Customer app should receive `stop-update` event
9. UI should show:
   - ✅ Stop #1 marked "completed" with checkmark
   - ✅ Stop #2 highlighted as current
   - ✅ Notification: "Package collected from pickup location"

10. Driver completes dropoff #1
11. UI should show stop #2 completed, stop #3 current

12. Driver completes dropoff #2
13. UI should show all stops completed
14. Navigate to completion screen

### **Test 2: Stop Status Persistence**
1. Customer closes app during delivery
2. Driver completes stop #2
3. Customer reopens app
4. Should see stop #2 marked as completed (from database)

### **Test 3: Multiple Dropoffs**
1. Create delivery with 1 pickup + 5 dropoffs
2. Verify all 6 stops created correctly
3. Verify stop numbering: 1, 2, 3, 4, 5, 6
4. Complete all stops and verify UI updates

---

## 📞 Questions for Driver App Team

Please answer these questions:

1. **Stop Updates via Ably**:
   - [ ] Do you currently publish `stop-update` events?
   - [ ] If yes, what's the event name and payload format?
   - [ ] If no, can you implement it?

2. **Stop Status in Database**:
   - [ ] Do you update `delivery_stops` table?
   - [ ] Which statuses do you write to database?
   - [ ] Do you use Ably-first (intermediate) vs Database (final)?

3. **Current Stop Tracking**:
   - [ ] Do you update `deliveries.current_stop_index`?
   - [ ] When do you update it (on arrival? completion?)?

4. **Status Flow**:
   - [ ] What's your status flow for multi-stop deliveries?
   - [ ] When does overall status vs stop status change?
   - [ ] How do you handle the last dropoff?

5. **Pickup Stop**:
   - [ ] Are you aware pickup is now stop #1?
   - [ ] Does your app expect pickup as first stop?
   - [ ] Any changes needed on your side?

---

## 🚀 Next Steps

### For Customer App (Us):
1. ✅ Fixed Edge Function (pickup stop creation)
2. ✅ Added stop-update Ably subscription
3. ✅ Implemented stop status update handling
4. ⏳ Waiting for driver app implementation
5. ⏳ End-to-end testing with driver app

### For Driver App (You):
1. ⏳ Review this document
2. ⏳ Answer coordination questions
3. ⏳ Implement `stop-update` Ably events
4. ⏳ Update `delivery_stops` table on completion
5. ⏳ Update `current_stop_index` field
6. ⏳ Verify pickup stop is #1, not #0
7. ⏳ Test with customer app team

---

## 📋 Coordination Meeting Agenda

**When**: ASAP  
**Duration**: 30-45 minutes

**Topics**:
1. Review multi-stop status flow (10 min)
2. Define `stop-update` event format (10 min)
3. Clarify database update strategy (10 min)
4. Plan testing approach (10 min)
5. Timeline and deployment (5 min)

**Outcome**:
- ✅ Agreed event format
- ✅ Confirmed status flow
- ✅ Testing plan
- ✅ Implementation timeline

---

## 📊 Summary

| Feature | Customer App | Driver App | Status |
|---------|-------------|------------|--------|
| Pickup stop creation | ✅ Fixed | ❓ Unknown | ⚠️ **VERIFY** |
| Stop-update Ably events | ✅ Listening | ❓ Unknown | ⚠️ **NEEDS IMPLEMENTATION** |
| Stop status in database | ✅ Ready | ❓ Unknown | ⚠️ **NEEDS CLARIFICATION** |
| Current stop tracking | ✅ UI ready | ❓ Unknown | ⚠️ **NEEDS CLARIFICATION** |
| Multi-stop testing | ⏳ Ready | ❓ Unknown | ⚠️ **BLOCKED** |

**Blocker**: Cannot test multi-stop until driver app implements stop-update events.

**Priority**: 🔴 HIGH - Required for production multi-stop deliveries.

---

**Contact**: Customer App Team  
**Date**: October 31, 2025  
**Status**: ✅ Customer app ready, ⏳ waiting for driver app coordination
