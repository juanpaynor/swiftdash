# 📊 Driver App Data Requirements by Delivery Stage

**Date:** October 13, 2025  
**Purpose:** Define exact data requirements from driver app for real-time tracking  
**Integration:** Customer app tracking screen with DoorDash/Uber-style experience  

---

## 🚚 **Complete Data Flow by Delivery Stage**

### **Stage 1: `driver_assigned` - "Driver accepted and preparing"**

**Status Update Required:**
```json
{
  "delivery_status": "driver_assigned",
  "updated_at": "2025-10-13T10:30:00.000Z",
  "driver_profile": {
    "name": "Juan Dela Cruz",
    "vehicle_type": "Motorcycle", 
    "vehicle_model": "Honda Click 150i",
    "plate_number": "ABC123",
    "rating": 4.8,
    "total_deliveries": 127,
    "phone": "+639171234567",
    "profile_picture_url": "https://..."
  },
  "initial_location": {
    "latitude": 14.5995,
    "longitude": 120.9842,
    "timestamp": "2025-10-13T10:30:00.000Z"
  },
  "estimated_arrival": {
    "eta_to_pickup_minutes": 8,
    "eta_range": "8-12 minutes"
  }
}
```

**Customer App Display:**
- ✅ "Driver assigned and preparing for pickup"
- ✅ Driver profile card with photo and vehicle details
- ✅ Initial ETA calculation
- ✅ Blue status indicator

---

### **Stage 2: `going_to_pickup` - "Driver heading to pickup"**

**Real-time WebSocket Broadcasting (Every 15 seconds):**
```json
{
  "driver_id": "3d778cea-7f1e-40cd-b1f3-3f25bfb72bf9",
  "delivery_id": "d43a25b7-4724-407b-b096-30409a03d517",
  "latitude": 14.5995,
  "longitude": 120.9842,
  "speed_kmh": 45,
  "heading": 90,
  "battery_level": 85,
  "timestamp": "2025-10-13T10:30:15.000Z",
  "status": "going_to_pickup",
  "route_progress": {
    "distance_to_pickup_km": 2.3,
    "eta_minutes": 6,
    "traffic_status": "moderate"
  }
}
```

**WebSocket Channel:** `driver-location-{deliveryId}`  
**Event Type:** `location_update`  
**Broadcast Method:** `channel.sendBroadcastMessage('location_update', payload)`

**Customer App Display:**
- ✅ "Driver is heading to pickup location"
- ✅ Real-time driver marker moving on map
- ✅ Blue polyline from driver → pickup location
- ✅ Live ETA updates: "ETA to pickup: 6 min"
- ✅ Driver speed and battery monitoring

---

### **Stage 3: `pickup_arrived` - "Driver at pickup location"**

**Status Update + Location Confirmation:**
```json
{
  "delivery_status": "pickup_arrived",
  "arrival_time": "2025-10-13T10:42:00.000Z",
  "driver_location": {
    "latitude": 14.4478595,
    "longitude": 121.0224296,
    "accuracy_meters": 5
  },
  "pickup_confirmation": {
    "arrived_at_coordinates": true,
    "distance_from_pickup_meters": 3,
    "geofence_verified": true,
    "arrival_method": "gps_proximity"
  },
  "driver_status": {
    "is_waiting": true,
    "contact_attempted": false,
    "waiting_since": "2025-10-13T10:42:00.000Z"
  }
}
```

**Customer App Display:**
- ✅ "Driver has arrived at pickup location"
- ✅ Static driver marker at pickup location
- ✅ Pulsing pickup location pin
- ✅ Orange status indicator
- ✅ "Driver is waiting at pickup" message
- ✅ No polyline (arrival state)

---

### **Stage 4: `package_collected` - "Package picked up"**

**Package Collection Confirmation:**
```json
{
  "delivery_status": "package_collected",
  "collection_time": "2025-10-13T10:47:00.000Z",
  "package_details": {
    "actual_weight_kg": 2.5,
    "condition_notes": "Package in good condition",
    "photo_proof": "base64_image_string_or_url",
    "barcode_scanned": true,
    "special_handling": "fragile_item"
  },
  "collection_proof": {
    "sender_signature": "base64_signature",
    "sender_name": "Store Manager",
    "collection_photo": "base64_image_string",
    "timestamp": "2025-10-13T10:47:00.000Z"
  },
  "driver_location": {
    "latitude": 14.4478595,
    "longitude": 121.0224296
  },
  "next_phase": {
    "destination_eta_minutes": 15,
    "route_distance_km": 3.2
  }
}
```

**Customer App Display:**
- ✅ "Package collected - heading your way!"
- ✅ Purple status indicator
- ✅ Package collection timestamp
- ✅ "Driver has your package and is on the way"
- ✅ Updated ETA to delivery location

---

### **Stage 5: `going_to_destination` - "Driver heading to delivery"**

**Real-time WebSocket Broadcasting (Every 15 seconds):**
```json
{
  "driver_id": "3d778cea-7f1e-40cd-b1f3-3f25bfb72bf9",
  "delivery_id": "d43a25b7-4724-407b-b096-30409a03d517",
  "latitude": 14.5123,
  "longitude": 120.9956,
  "speed_kmh": 38,
  "heading": 180,
  "battery_level": 78,
  "timestamp": "2025-10-13T10:50:00.000Z",
  "status": "going_to_destination",
  "delivery_progress": {
    "distance_to_destination_km": 1.8,
    "eta_minutes": 12,
    "completion_percentage": 65,
    "traffic_conditions": "light"
  },
  "package_status": {
    "secure": true,
    "temperature_ok": true,
    "handling_notes": "keeping fragile items stable"
  }
}
```

**Customer App Display:**
- ✅ "Driver is on the way to you"
- ✅ Real-time driver marker moving toward delivery
- ✅ Purple polyline from pickup → delivery location
- ✅ Live ETA: "ETA: 12 min (1.8km)"
- ✅ Progress indicator: "65% complete"
- ✅ Purple status indicator

---

### **Stage 6: `at_destination` - "Driver arrived at delivery location"**

**Arrival Confirmation:**
```json
{
  "delivery_status": "at_destination",
  "arrival_time": "2025-10-13T11:05:00.000Z",
  "driver_location": {
    "latitude": 14.5352345,
    "longitude": 120.9819385,
    "accuracy_meters": 4
  },
  "destination_confirmation": {
    "arrived_at_coordinates": true,
    "distance_from_destination_meters": 2,
    "geofence_verified": true,
    "arrival_method": "gps_proximity"
  },
  "delivery_attempt": {
    "attempting_contact": true,
    "contact_method": "phone_call",
    "customer_responsive": true,
    "delivery_location_accessible": true
  },
  "package_status": {
    "ready_for_handover": true,
    "condition": "excellent",
    "requires_signature": true
  }
}
```

**Customer App Display:**
- ✅ "Driver has arrived at your location"
- ✅ Static driver marker at delivery location
- ✅ Pulsing delivery location pin
- ✅ Green status indicator
- ✅ "Driver is at your door" message
- ✅ No polyline (arrival state)

---

### **Stage 7: `delivered` - "Delivery completed"**

**Final Delivery Confirmation:**
```json
{
  "delivery_status": "delivered",
  "completion_time": "2025-10-13T11:08:00.000Z",
  "proof_of_delivery": {
    "recipient_name": "Maria Santos",
    "recipient_id_verified": true,
    "recipient_signature": "base64_signature",
    "delivery_photo": "base64_image_string",
    "handover_location": "front_door",
    "delivery_notes": "Handed directly to recipient at front door"
  },
  "final_confirmation": {
    "package_condition": "delivered_intact",
    "customer_satisfaction": "confirmed",
    "delivery_time_actual": "2025-10-13T11:08:00.000Z",
    "delivery_time_promised": "2025-10-13T11:15:00.000Z",
    "early_delivery_minutes": 7
  },
  "final_location": {
    "latitude": 14.5352345,
    "longitude": 120.9819385
  },
  "completion_metrics": {
    "total_distance_km": 5.1,
    "total_duration_minutes": 38,
    "driver_rating_eligible": true
  }
}
```

**Customer App Display:**
- ✅ "Delivery completed successfully!"
- ✅ Green status indicator
- ✅ Completion timestamp
- ✅ "Rate your delivery experience" prompt
- ✅ Delivery summary with photos
- ✅ GPS tracking stops

---

## 📡 **Critical WebSocket Broadcasting Requirements**

### **Active Movement Stages**
During `going_to_pickup` and `going_to_destination`, the driver app **MUST** broadcast location every **15 seconds**:

```javascript
// Driver App Implementation (REQUIRED)
setInterval(async () => {
  const location = await getCurrentLocation();
  const payload = {
    driver_id: driverId,
    delivery_id: deliveryId,
    latitude: location.latitude,
    longitude: location.longitude,
    speed_kmh: location.speed || 0,
    heading: location.bearing || 0,
    battery_level: await getBatteryLevel(),
    timestamp: new Date().toISOString(),
    status: currentDeliveryStatus
  };
  
  // CRITICAL: Use sendBroadcastMessage, NOT channel.on()
  await channel.sendBroadcastMessage('location_update', payload);
  
}, 15000); // Every 15 seconds
```

### **WebSocket Channel Configuration**
```javascript
// Channel naming convention (EXACT MATCH REQUIRED)
const channelName = `driver-location-${deliveryId}`;
const channel = supabase.channel(channelName);
await channel.subscribe();
```

---

## 🎯 **Customer App Integration Points**

### **Map Visualization**
```dart
// Real-time map updates based on delivery status
SharedDeliveryMap(
  driverLatitude: driverLocation['latitude'],
  driverLongitude: driverLocation['longitude'],
  deliveryStatus: delivery.status,
  driverVehicleType: driverProfile['vehicle_type'],
)
```

### **Polyline Management**
- **Blue Polyline**: `going_to_pickup` (Driver → Pickup)
- **Purple Polyline**: `going_to_destination` (Pickup → Delivery)
- **No Polyline**: `pickup_arrived`, `at_destination` (Static states)

### **ETA Calculations**
```dart
// Dynamic ETA updates based on real-time data
String calculateETA(double speed, double distance) {
  final estimatedMinutes = (distance / speed) * 60;
  return "${estimatedMinutes.round()} minutes";
}
```

### **Status Notifications**
```dart
// Real-time status change notifications
void showStatusNotification(String newStatus) {
  final messages = {
    'going_to_pickup': 'Driver is heading to pickup location',
    'pickup_arrived': 'Driver has arrived at pickup',
    'package_collected': 'Package collected - heading your way!',
    'going_to_destination': 'Driver is on the way to you',
    'at_destination': 'Driver has arrived at your location',
    'delivered': 'Delivery completed successfully!'
  };
}
```

---

## 🔧 **Data Validation Requirements**

### **GPS Accuracy Standards**
- **Minimum Accuracy**: 10 meters
- **Preferred Accuracy**: 5 meters or better
- **Update Frequency**: Every 15 seconds during movement
- **Timeout**: 30 seconds maximum between updates

### **Status Transition Rules**
```
pending → driver_assigned → going_to_pickup → pickup_arrived → 
package_collected → going_to_destination → at_destination → delivered
```

### **Required Fields by Stage**
| Stage | GPS | Status | Timestamps | Photos | Signatures |
|-------|-----|--------|------------|--------|------------|
| `going_to_pickup` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `pickup_arrived` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `package_collected` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `going_to_destination` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `at_destination` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `delivered` | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 🚀 **Implementation Priority**

### **Phase 1: Core Tracking (HIGH PRIORITY)**
1. ✅ Real-time GPS broadcasting during movement
2. ✅ Status update API calls
3. ✅ WebSocket channel management

### **Phase 2: Enhanced Experience (MEDIUM PRIORITY)**  
1. ✅ Photo proof of delivery
2. ✅ Digital signatures
3. ✅ Package condition reporting

### **Phase 3: Advanced Features (LOW PRIORITY)**
1. ✅ Battery level monitoring
2. ✅ Traffic condition reporting
3. ✅ Route optimization feedback

---

## 📞 **Testing & Validation**

### **Test Delivery IDs**
- **Delivery ID**: `d43a25b7-4724-407b-b096-30409a03d517`
- **Driver ID**: `3d778cea-7f1e-40cd-b1f3-3f25bfb72bf9`
- **Channel**: `driver-location-d43a25b7-4724-407b-b096-30409a03d517`

### **Expected Customer App Logs**
```
📡 CustomerRealtimeService: RAW BROADCAST RECEIVED
📡 Channel: driver-location-d43a25b7-4724-407b-b096-30409a03d517
📡 Event: location_update
📡 Payload: {driver_id: "...", latitude: 14.5995, longitude: 120.9842}
✅ Driver location updated successfully
🗺️ Map will receive driverLatitude: 14.5995, driverLongitude: 120.9842
```

---

**Result:** Professional DoorDash/Uber-style real-time tracking experience! 🚀

**Priority:** Implement GPS broadcasting first - this unlocks the entire tracking experience.**

**Next Steps:** Once driver app starts broadcasting, customer app will immediately show live driver markers and polylines.**