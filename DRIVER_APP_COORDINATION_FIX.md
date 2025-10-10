# Driver App Coordination & Offer/Acceptance System - October 9, 2025

## 🎯 **Issue Resolution Summary**

**Original Problem:** Customer app showed "driver found" and immediately went to tracking screen, but drivers never received any offers to accept/decline.

**Root Cause:** System was auto-assigning drivers instead of implementing proper offer/acceptance workflow.

## 🔧 **Technical Fixes Implemented**

### **1. Database Schema Update**
- **Fixed constraint violation:** Added `'driver_offered'` to deliveries table status constraint
- **Allowed statuses now:** pending, driver_offered, driver_assigned, pickup_arrived, package_collected, in_transit, delivered, cancelled, failed

### **2. Edge Function Updates**

#### **pair_driver Function (Enhanced)**
- **Purpose:** Find closest available driver and send offer
- **New behavior:** Sets status to `'driver_offered'` (not auto-assigned)
- **Response:** Returns offered_driver_id and status: 'driver_offered'

#### **accept_delivery Function (New)**
- **Purpose:** Handle driver acceptance/decline of delivery offers
- **Endpoint:** `/functions/v1/accept_delivery`
- **Parameters:**
  ```json
  {
    "deliveryId": "string",
    "driverId": "string", 
    "accept": boolean
  }
  ```
- **Accept flow:** Updates status to 'driver_assigned', sets driver unavailable
- **Decline flow:** Resets to 'pending', removes driver assignment

### **3. Customer App Updates (matching_screen.dart)**

#### **Before Fix:**
```dart
// Any status != 'pending' triggered success
if (delivery.status != 'pending' && delivery.status != 'cancelled') {
  _onDriverMatched(delivery); // Immediate navigation
}
```

#### **After Fix:**
```dart
// Proper status handling
if (delivery.status == 'driver_offered') {
  _onDriverOffered(delivery); // Show waiting message
} else if (delivery.status == 'driver_assigned') {
  _onDriverMatched(delivery); // Navigate to tracking
}
```

#### **New User Experience:**
1. **"Searching for drivers..."** (status: pending)
2. **"Driver found! Waiting for acceptance..."** (status: driver_offered) 
3. **Navigation to tracking** (status: driver_assigned)

## 🚗 **Driver App Integration Requirements**

### **Real-time Offer Listening**
```dart
// Driver app should listen for offers
Supabase.instance.client
  .from('deliveries')
  .stream(primaryKey: ['id'])
  .eq('driver_id', currentDriverId)
  .eq('status', 'driver_offered')
  .listen((data) {
    // Show offer UI with accept/decline buttons
    showDeliveryOffer(data.first);
  });
```

### **Accept/Decline Implementation**
```dart
Future<void> acceptDelivery(String deliveryId, bool accept) async {
  final response = await Supabase.instance.client.functions.invoke(
    'accept_delivery',
    body: {
      'deliveryId': deliveryId,
      'driverId': currentDriverId,
      'accept': accept,
    },
  );
  
  if (response.data['ok'] == true) {
    // Handle successful acceptance/decline
    if (accept) {
      // Navigate to delivery details
      navigateToActiveDelivery(deliveryId);
    } else {
      // Remove offer from UI
      dismissOffer();
    }
  }
}
```

### **Driver Status Management**
```dart
// When driver goes online
await Supabase.instance.client
  .from('driver_profiles')
  .update({
    'is_online': true,
    'is_available': true,
    'location_updated_at': DateTime.now().toIso8601String(),
  })
  .eq('id', currentDriverId);

// When driver accepts delivery (handled by accept_delivery function)
// is_available automatically set to false

// When delivery is completed
await Supabase.instance.client
  .from('driver_profiles')
  .update({'is_available': true})
  .eq('id', currentDriverId);
```

## 📱 **Driver App UI Flow Requirements**

### **1. Offer Notification**
```dart
// Show modal or notification with:
- Pickup location
- Dropoff location  
- Estimated distance
- Earnings estimate
- Accept/Decline buttons
- Auto-decline timer (e.g., 30 seconds)
```

### **2. Offer Response Handling**
```dart
// On Accept:
- Call accept_delivery API
- Navigate to active delivery screen
- Show customer details
- Start navigation to pickup

// On Decline:
- Call accept_delivery API with accept: false
- Dismiss offer UI
- Continue listening for new offers

// On Timeout:
- Auto-decline
- Show "Offer expired" message
```

### **3. Active Delivery Management**
```dart
// When driver has active delivery:
- Show delivery progress screen
- Disable new offer listening
- Handle status updates: pickup_arrived, package_collected, in_transit, delivered
- Re-enable availability when completed
```

## 🔄 **Complete Workflow**

### **Customer Side:**
1. Request delivery → `'pending'`
2. See "Searching for drivers..."
3. See "Driver found! Waiting for acceptance..."
4. Navigate to tracking when accepted

### **System Side:**
1. Find closest available driver
2. Set status to `'driver_offered'`
3. Send real-time notification to driver
4. Wait for driver response

### **Driver Side:**
1. Receive offer notification
2. View delivery details
3. Accept or decline within time limit
4. If accepted: Navigate to active delivery
5. If declined: Continue listening for offers

## 🧪 **Testing the System**

### **Manual Testing (Before Driver App Ready)**
```sql
-- Check current offers
SELECT id, status, driver_id 
FROM deliveries 
WHERE status = 'driver_offered';

-- Simulate driver acceptance
UPDATE deliveries 
SET status = 'driver_assigned', updated_at = NOW()
WHERE status = 'driver_offered';

-- Simulate driver decline  
UPDATE deliveries 
SET status = 'pending', driver_id = NULL, updated_at = NOW()
WHERE status = 'driver_offered';
```

### **API Testing**
```bash
# Test accept endpoint
curl -X POST 'https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/accept_delivery' \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"deliveryId": "uuid", "driverId": "uuid", "accept": true}'
```

## 📊 **Current System Status**

### **✅ Completed**
- Database constraint updated
- Edge Functions deployed (pair_driver, accept_delivery)
- Customer app updated with proper offer/acceptance flow
- Real-time status listening implemented
- Comprehensive testing documentation

### **📱 Pending (Driver App)**
- Offer notification UI
- Accept/decline functionality
- Real-time offer listening
- Active delivery management
- Status update handling

### **🔄 Optional Enhancements**
- Auto-offer to next driver on decline
- Offer timeout handling
- Driver earnings display in offers
- Push notifications for offers
- Offer history tracking

## 🎯 **Integration Priority**

**High Priority:**
1. Real-time offer listening in driver app
2. Accept/decline UI and API calls
3. Basic active delivery screen

**Medium Priority:**
1. Offer timeout handling
2. Enhanced delivery details in offers
3. Earnings estimates

**Low Priority:**
1. Offer history
2. Advanced analytics
3. Push notifications

## 🚀 **Next Steps for Driver App Team**

1. **Implement offer listening** using the Supabase real-time subscriptions
2. **Create offer modal UI** with accept/decline buttons  
3. **Integrate accept_delivery API calls**
4. **Test end-to-end flow** with customer app
5. **Handle edge cases** (network issues, timeouts, etc.)

**The infrastructure is now complete and ready for driver app integration!** 🎉

---

**Key Files Modified:**
- `supabase/functions/pair_driver/index.ts`
- `supabase/functions/accept_delivery/index.ts` (new)
- `lib/screens/matching_screen.dart`
- Database constraint: `deliveries_status_check`

**New Endpoints Available:**
- `POST /functions/v1/pair_driver` (enhanced)
- `POST /functions/v1/accept_delivery` (new)