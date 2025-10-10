# Driver App Payload Formats - October 10, 2025

## 🚗 **Delivery Offer Payload Format**

### **1. Real-time Delivery Offer Subscription**

The driver app should listen for delivery offers using Supabase real-time subscriptions:

```dart
// ✅ CORRECT - Fixed version that prevents "Bad state: No element"
supabase
  .from('deliveries')
  .stream(primaryKey: ['id'])
  .eq('driver_id', currentDriverId)
  .eq('status', 'driver_offered')
  .listen((data) {
    print('📦 Received delivery update, count: ${data.length}');
    
    if (data.isNotEmpty) {
      final offer = data.first as Map<String, dynamic>;
      print('✅ Valid offer received: ${offer['id']}');
      showDeliveryOffer(offer);
    } else {
      print('⚠️ Empty data received');
    }
  }, onError: (error) {
    print('❌ Subscription error: $error');
  });
```

### **Alternative: Using PostgresChangeEvent**

```dart
// Alternative approach using onPostgresChanges
supabase
  .channel('driver-offers-$driverId')
  .onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'deliveries',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'driver_id',
      value: driverId,
    ),
    callback: (payload) {
      print('🚨 *** NEW DELIVERY OFFER PAYLOAD RECEIVED ***');
      print('🚨 Payload event: ${payload.eventType}');
      print('🚨 Payload new record: ${payload.newRecord}');
      
      if (payload.newRecord['status'] == 'driver_offered') {
        showDeliveryOffer(payload.newRecord);
      }
    },
  )
  .subscribe();
```

### **2. Delivery Offer Payload Structure**

Based on actual system data, when a delivery is offered to a driver, the payload contains:

```json
{
  "id": "e689b1f4-250c-46fc-b624-026bd5936a07",
  "customer_id": "8c2c06e0-2bd3-4a6a-b712-cf0d42576f38",
  "driver_id": "3d778cea-7f1e-40cd-b1f3-3f25bfb72bf9",
  "vehicle_type_id": "fd74e9d1-2577-4103-a0e9-acea646cc210",
  "status": "driver_offered",
  
  // Pickup Information
  "pickup_address": "Amaia Steps Sucat, 8333 Doctor Arcadio Santos Avenue, Parañaque",
  "pickup_latitude": 14.4626963,
  "pickup_longitude": 121.0245538,
  "pickup_contact_name": "jerry",
  "pickup_contact_phone": "09619478642",
  "pickup_instructions": null,
  
  // Delivery Information  
  "delivery_address": "RAF International Forwarding Phils. Inc., Units 3 & 4 NAIA Rd, Parañaque",
  "delivery_latitude": 14.4899077,
  "delivery_longitude": 120.9912384,
  "delivery_contact_name": "steve", 
  "delivery_contact_phone": "09619478642",
  "delivery_instructions": null,
  
  // Package Details
  "package_weight": 1.0,
  "package_value": null,
  
  // Pricing & Distance (FIELD NAME DIFFERENCES!)
  "distance_km": 4.7,
  "estimated_duration": null,
  "total_amount": 0.0,  // ⚠️ NOT "total_price"!
  
  // Payment Info (FIELD NAME DIFFERENCES!)
  "payment_by": null,
  "payment_status": "pending",
  "payment_method": null,
  
  // Additional Fields
  "tip_amount": 0.0,
  "completed_at": null,
  "updated_at": "2025-10-10T01:45:59.157+00:00",
  
  // Optional/Null fields
  "customer_rating": null,
  "driver_rating": null
}
```

## 📱 **Driver App Implementation**

### **3. Accept/Decline Delivery API**

When driver accepts or declines an offer, call the `accept_delivery` Edge Function:

**Endpoint:** `POST /functions/v1/accept_delivery`

**Request Headers:**
```
Authorization: Bearer <driver_jwt_token>
Content-Type: application/json
```

**Request Payload:**
```json
{
  "deliveryId": "550e8400-e29b-41d4-a716-446655440000",
  "driverId": "driver-uuid-here",
  "accept": true
}
```

**Accept Response (success):**
```json
{
  "ok": true,
  "message": "Delivery accepted successfully",
  "delivery_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "driver_assigned"
}
```

**Decline Response (success):**
```json
{
  "ok": true,
  "message": "Delivery declined",
  "delivery_id": "550e8400-e29b-41d4-a716-446655440000", 
  "status": "pending"
}
```

**Error Response:**
```json
{
  "ok": false,
  "message": "Delivery is no longer available or not offered to this driver"
}
```

### **4. Driver App Flutter Implementation Example**

```dart
class DeliveryOfferService {
  static final supabase = Supabase.instance.client;
  
  // Listen for delivery offers (FIXED VERSION)
  static Stream<Map<String, dynamic>?> listenForOffers(String driverId) {
    return supabase
      .from('deliveries')
      .stream(primaryKey: ['id'])
      .eq('driver_id', driverId)
      .eq('status', 'driver_offered')
      .map((data) {
        if (data.isNotEmpty) {
          return data.first as Map<String, dynamic>;
        }
        return null; // Return null instead of empty map
      });
  }
  
  // Accept delivery offer
  static Future<Map<String, dynamic>> acceptDelivery({
    required String deliveryId,
    required String driverId,
    required bool accept,
  }) async {
    final response = await supabase.functions.invoke(
      'accept_delivery',
      body: {
        'deliveryId': deliveryId,
        'driverId': driverId,
        'accept': accept,
      },
    );
    
    if (response.status == 200) {
      return response.data as Map<String, dynamic>;
    } else {
      throw Exception('Failed to respond to delivery offer: ${response.data}');
    }
  }
}
```

### **5. UI Implementation Example**

```dart
class DeliveryOfferDialog extends StatelessWidget {
  final Map<String, dynamic> offer;
  final String driverId;
  
  const DeliveryOfferDialog({
    Key? key,
    required this.offer,
    required this.driverId,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // ⚠️ Use correct field name: total_amount (not total_price)
    final totalAmount = (offer['total_amount'] ?? 0.0) as double;
    final earnings = _calculateEarnings(totalAmount);
    final distance = (offer['distance_km'] ?? 0.0) as double;
    final duration = offer['estimated_duration'] as int?;
    
    return AlertDialog(
      title: Text('New Delivery Offer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Distance: ${distance.toStringAsFixed(1)}km'),
          Text('Estimated time: ${duration != null ? '$duration min' : 'Calculating...'}'),
          Text('Your earnings: ₱${earnings.toStringAsFixed(2)}'),
          SizedBox(height: 16),
          Text('Pickup: ${offer['pickup_address'] ?? 'N/A'}'),
          Text('Delivery: ${offer['delivery_address'] ?? 'N/A'}'),
          SizedBox(height: 16),
          if (offer['package_weight'] != null)
            Text('Package weight: ${offer['package_weight']}kg'),
          if (offer['pickup_instructions'] != null)
            Text('Pickup notes: ${offer['pickup_instructions']}'),
          if (offer['delivery_instructions'] != null)
            Text('Delivery notes: ${offer['delivery_instructions']}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _respondToOffer(context, false),
          child: Text('Decline', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () => _respondToOffer(context, true),
          child: Text('Accept'),
        ),
      ],
    );
  }
  
  double _calculateEarnings(double totalPrice) {
    // Driver gets 70% of total price (example)
    return totalPrice * 0.7;
  }
  
  Future<void> _respondToOffer(BuildContext context, bool accept) async {
    try {
      await DeliveryOfferService.acceptDelivery(
        deliveryId: offer['id'],
        driverId: driverId,
        accept: accept,
      );
      
      Navigator.of(context).pop();
      
      if (accept) {
        // Navigate to active delivery screen
        Navigator.pushNamed(context, '/active-delivery', 
          arguments: offer['id']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
```

## 🔄 **Complete Workflow**

### **Driver App Flow:**
1. **Listen for offers** → Subscribe to deliveries with `status='driver_offered'` and `driver_id=currentDriverId`
2. **Show offer UI** → Display offer details with accept/decline buttons
3. **Send response** → Call `accept_delivery` Edge Function with accept/decline
4. **Handle result** → Navigate to active delivery or continue listening

### **System Flow:**
1. **Customer requests delivery** → Status: `'pending'`
2. **System finds driver** → Status: `'driver_offered'`, `driver_id` set
3. **Driver receives offer** → Real-time subscription triggers
4. **Driver accepts** → Status: `'driver_assigned'`, driver becomes unavailable
5. **Driver declines** → Status: `'pending'`, `driver_id` reset to null

## 🔧 **Troubleshooting**

### **Common Issues:**

1. **"Bad state: No element" Error:**
   - **Problem:** Calling `.first` on empty list or accessing non-existent data
   - **Solution:**
   ```dart
   // ❌ WRONG - can cause "No element" error
   final offer = data.first;
   
   // ✅ CORRECT - safe access
   if (data.isNotEmpty) {
     final offer = data.first;
     showDeliveryOffer(offer);
   }
   
   // ✅ ALTERNATIVE - safe access
   final offer = data.firstOrNull;
   if (offer != null) {
     showDeliveryOffer(offer);
   }
   ```

2. **Field Name Mismatches:**
   - Use `total_amount` NOT `total_price`
   - Some fields may be `null` (handle gracefully)
   - `estimated_duration` is often `null`
   - `package_description` field might not exist

3. **No offers received:**
   - Check driver is online: `is_online = true`
   - Check driver is available: `is_available = true`
   - Check location is updated: `current_latitude/longitude` not null
   - Verify real-time subscription is active

4. **Accept/Decline fails:**
   - Verify JWT token is valid and not expired
   - Check delivery is still in `'driver_offered'` status
   - Ensure `driverId` matches the offered driver

5. **Payload missing fields:**
   - Some fields may be null (like `estimated_duration`, `package_value`)
   - Check for null values before displaying in UI

### **Testing:**
```sql
-- Manually create a test offer
UPDATE deliveries 
SET status = 'driver_offered', 
    driver_id = 'your-driver-uuid-here',
    updated_at = NOW()
WHERE id = 'your-test-delivery-uuid';
```

## 📊 **Key Fields Summary**

### **Required for Driver UI:**
- `id` - Delivery ID for API calls
- `pickup_address`, `delivery_address` - Locations
- `pickup_latitude/longitude`, `delivery_latitude/longitude` - Map display
- `distance_km` - Trip distance
- `total_amount` - Earnings calculation ⚠️ (NOT `total_price`)
- `pickup_contact_name`, `delivery_contact_name` - Contact names

### **Optional but Useful:**
- `pickup_contact_phone/delivery_contact_phone` - Contact numbers
- `pickup_instructions`, `delivery_instructions` - Special notes (often null)
- `package_weight`, `package_value` - Package details (may be null)
- `estimated_duration` - Trip time (often null)
- `payment_by`, `payment_method` - Payment info (may be null)
- `tip_amount` - Additional earnings

## 🔥 **URGENT FIXES FOR YOUR DRIVER APP**

Based on your **ACTUAL DRIVER APP LOGS**, here are the critical issues:

### **🚨 MAJOR PROBLEM: total_amount = 0.0**

Looking at your real payload:
```
total_amount: 0.0
```

**This means the driver will see ₱0.00 earnings!** This is likely why drivers aren't accepting deliveries.

### **Root Cause Analysis:**

1. **Pricing not calculated:** The delivery pricing system isn't setting the `total_amount`
2. **Driver sees no earnings:** UI shows ₱0.00, so drivers decline
3. **Business logic missing:** Need to calculate price based on distance/time

### **ACTUAL PAYLOAD STRUCTURE** (from your logs):

```json
{
  "id": "2956accc-a268-4d6d-bfc2-aed5a5152526",
  "customer_id": "8c2c06e0-2bd3-4a6a-b712-cf0d42576f38",
  "driver_id": "3d778cea-7f1e-40cd-b1f3-3f25bfb72bf9",
  "vehicle_type_id": "fd74e9d1-2577-4103-a0e9-acea646cc210",
  "status": "driver_offered",
  
  // Locations
  "pickup_address": "Amaia Steps Sucat, 8333 Doctor Arcadio Santos Avenue, Parañaque",
  "pickup_latitude": 14.4626963,
  "pickup_longitude": 121.0245538,
  "pickup_contact_name": "john",
  "pickup_contact_phone": "09619478642",
  "pickup_instructions": null,
  
  "delivery_address": "Raffy Tulfo Action Center, 1104 Quezon Avenue, Quezon City",
  "delivery_latitude": 14.6387264,
  "delivery_longitude": 121.0281183,
  "delivery_contact_name": "amanda", 
  "delivery_contact_phone": "09662899459",
  "delivery_instructions": null,
  
  // Package & Pricing
  "package_weight": 1.0,
  "package_value": null,
  "distance_km": 19.6,
  "estimated_duration": null,
  "total_amount": 0.0,  // ❌ THIS IS THE PROBLEM!
  "tip_amount": 0.0,
  
  // Payment
  "payment_by": null,
  "payment_method": null,
  "payment_status": "pending",
  
  // Other fields
  "completed_at": null,
  "updated_at": "2025-10-10T02:00:45.516+00:00",
  "customer_rating": null,
  "driver_rating": null
  // Note: payload was cut off, may have "package_description" field
}
```

### **🔧 IMMEDIATE FIXES NEEDED:**

#### **1. Fix Driver App UI (Temporary):**
```dart
// ✅ Calculate earnings in driver app as fallback
double _calculateEarnings(Map<String, dynamic> offer) {
  final distance = (offer['distance_km'] ?? 0.0) as double;
  
  // Emergency pricing formula (replace with your actual rates)
  double basePrice = 50.0; // ₱50 base fee
  double perKmRate = 15.0; // ₱15 per km
  
  double total = basePrice + (distance * perKmRate);
  double driverEarnings = total * 0.75; // Driver gets 75%
  
  return driverEarnings;
}

// Show calculated earnings instead of total_amount
Widget buildOfferDialog(Map<String, dynamic> offer) {
  final distance = (offer['distance_km'] ?? 0.0) as double;
  final totalAmount = (offer['total_amount'] ?? 0.0) as double;
  
  // Use calculated earnings if total_amount is 0
  final earnings = totalAmount > 0 
    ? totalAmount * 0.75 
    : _calculateEarnings(offer);
  
  return AlertDialog(
    title: Text('New Delivery Offer'),
    content: Column(
      children: [
        Text('Distance: ${distance.toStringAsFixed(1)}km'),
        Text('Your earnings: ₱${earnings.toStringAsFixed(2)}'), // Show calculated
        if (totalAmount == 0.0) 
          Text('(Estimated pricing)', style: TextStyle(color: Colors.orange)),
        // ... rest of UI
      ],
    ),
  );
}
```

#### **2. Fix Backend Pricing (CRITICAL):**

**The real fix is in your backend pricing system:**

```sql
-- Check if you have a pricing calculation function
SELECT * FROM deliveries WHERE total_amount = 0.0 LIMIT 5;

-- You need to update the pair_driver function to calculate pricing
-- Example pricing logic:
UPDATE deliveries 
SET total_amount = (
  50.0 + -- Base fee ₱50
  (distance_km * 15.0) + -- ₱15 per km
  CASE 
    WHEN estimated_duration > 60 THEN 20.0 -- Extra ₱20 for long trips
    ELSE 0.0 
  END
)
WHERE total_amount = 0.0 OR total_amount IS NULL;
```

#### **3. Updated Subscription Code (with null safety):**
```dart
void startListeningForOffers(String driverId) {
  _offerSubscription = supabase
    .from('deliveries')
    .stream(primaryKey: ['id'])
    .eq('driver_id', driverId)
    .eq('status', 'driver_offered')
    .listen((data) {
      if (data.isNotEmpty) {
        final offer = data.first as Map<String, dynamic>;
        
        // Log the actual payload for debugging
        print('📦 Offer received: ${offer['id']}');
        print('💰 Total amount: ${offer['total_amount']}');
        print('📏 Distance: ${offer['distance_km']}km');
        
        _handleNewOffer(offer);
      }
    }, onError: (error) {
      print('❌ Offer subscription error: $error');
    });
}
```

### **🚨 WHY DRIVERS AREN'T ACCEPTING:**

1. **₱0.00 earnings shown** → Drivers think it's unpaid
2. **19.6km distance** with no compensation → Not worth it
3. **No estimated duration** → Driver can't plan time

### **URGENT ACTION REQUIRED:**

1. **Fix pricing calculation** in your backend (pair_driver function)
2. **Update driver app UI** to show calculated earnings as fallback
3. **Test with real pricing** to ensure drivers see proper earnings

**The driver app code is working fine - the issue is that `total_amount = 0.0` makes offers unattractive!** �