# 🔍 WebSocket Location Tracking Debug Guide - October 10, 2025

## **Issue**: Driver location not showing despite broadcasting

The customer app is not receiving driver location updates even though the driver is broadcasting.

## 🧐 **Root Cause Analysis**

### **WebSocket Architecture Overview:**

1. **Driver App** broadcasts via:
   ```dart
   supabase.channel('driver-location-${deliveryId}')
     .sendBroadcastMessage('location_update', {
       'driver_id': driverId,
       'delivery_id': deliveryId,
       'latitude': position.latitude,
       'longitude': position.longitude,
       'timestamp': DateTime.now().toIso8601String(),
     });
   ```

2. **Customer App** listens via:
   ```dart
   channel.onBroadcast(
     event: 'location_update',
     callback: (payload) {
       final locationData = Map<String, dynamic>.from(payload);
       locationData['deliveryId'] = deliveryId;
       _locationController.add(locationData);
     },
   );
   ```

### **Potential Issues:**

#### **1. Channel Name Mismatch** 🎯
- **Driver broadcasts to:** `driver-location-${deliveryId}`
- **Customer listens to:** `driver-location-${deliveryId}`
- **Check:** Are both using the same `deliveryId`?

#### **2. Event Name Mismatch** 🎯  
- **Driver broadcasts:** `location_update`
- **Customer listens for:** `location_update`
- **Check:** Are both using exact same event name?

#### **3. Data Format Issues** 🎯
- **Driver sends:** `{driver_id, delivery_id, latitude, longitude, timestamp}`
- **Customer expects:** `{latitude, longitude}` (minimum)
- **Check:** Is payload structure correct?

#### **4. Channel Subscription Timing** 🎯
- **Issue:** Customer subscribes before driver starts broadcasting
- **Check:** Is driver actually broadcasting when customer is listening?

#### **5. WebSocket Connection State** 🎯
- **Issue:** Supabase WebSocket connection dropped
- **Check:** Are both apps properly connected to Supabase?

## 🔧 **Debug Steps**

### **Step 1: Add Debug Logging**

Update `realtime_service.dart` with enhanced logging:

```dart
Future<void> subscribeToDriverLocation(String deliveryId) async {
  final channelName = 'driver-location-$deliveryId';
  
  debugPrint('🔊 CustomerRealtimeService: Attempting to subscribe to $channelName');
  
  if (_locationChannels.containsKey(channelName)) {
    debugPrint('⚠️ CustomerRealtimeService: Already subscribed to $channelName');
    return;
  }

  final channel = _supabase.channel(channelName);
  
  // Enhanced logging for broadcast events
  channel.onBroadcast(
    event: 'location_update',
    callback: (payload) {
      try {
        debugPrint('📡 CustomerRealtimeService: RAW BROADCAST RECEIVED');
        debugPrint('📡 Channel: $channelName');
        debugPrint('📡 Event: location_update');
        debugPrint('📡 Payload: $payload');
        debugPrint('📡 Payload type: ${payload.runtimeType}');
        
        final locationData = Map<String, dynamic>.from(payload);
        locationData['deliveryId'] = deliveryId;
        
        debugPrint('📡 Processed location data: $locationData');
        
        _locationController.add(locationData);
        
        debugPrint('✅ CustomerRealtimeService: Location update processed for delivery $deliveryId');
      } catch (e, stackTrace) {
        debugPrint('❌ CustomerRealtimeService: Error processing location broadcast: $e');
        debugPrint('❌ Stack trace: $stackTrace');
        debugPrint('❌ Raw payload: $payload');
      }
    },
  );

  // Log subscription status
  debugPrint('🔌 CustomerRealtimeService: Subscribing to channel...');
  await channel.subscribe();
  
  debugPrint('✅ CustomerRealtimeService: Successfully subscribed to $channelName');
  debugPrint('🎯 CustomerRealtimeService: Now listening for "location_update" events');
  
  _locationChannels[channelName] = channel;
}
```

### **Step 2: Add Tracking Screen Debug**

Update tracking screen with more logging:

```dart
void _updateDriverLocation(Map<String, dynamic> location) {
  debugPrint('🚗 TrackingScreen: _updateDriverLocation called');
  debugPrint('🚗 Raw location data: $location');
  
  setState(() {
    _driverLocation = location;
  });

  final lat = location['latitude']?.toDouble();
  final lng = location['longitude']?.toDouble();
  
  debugPrint('🚗 Parsed coordinates: lat=$lat, lng=$lng');
  
  if (lat != null && lng != null) {
    debugPrint('✅ Driver location updated and will be passed to map: $lat, $lng');
    // Map will update automatically via setState
  } else {
    debugPrint('❌ Invalid coordinates received: lat=$lat, lng=$lng');
  }
}
```

### **Step 3: Manual Broadcast Test**

Create a test to manually broadcast location data:

```dart
// Add this method to CustomerRealtimeService for testing
Future<void> testBroadcastLocation(String deliveryId) async {
  final channel = _supabase.channel('driver-location-$deliveryId');
  
  await channel.subscribe();
  
  // Wait a moment for subscription to be established
  await Future.delayed(Duration(seconds: 2));
  
  debugPrint('🧪 TEST: Broadcasting test location data...');
  
  final testPayload = {
    'driver_id': 'test-driver-123',
    'delivery_id': deliveryId,
    'latitude': 14.5995, // Manila coordinates
    'longitude': 120.9842,
    'speed_kmh': 25.0,
    'heading': 180,
    'battery_level': 87,
    'timestamp': DateTime.now().toIso8601String(),
  };
  
  await channel.sendBroadcastMessage('location_update', testPayload);
  
  debugPrint('🧪 TEST: Test broadcast sent with payload: $testPayload');
}
```

### **Step 4: Check Supabase Connection**

Add connection status check:

```dart
Future<void> debugWebSocketConnection() async {
  debugPrint('🔍 DEBUG: Checking Supabase WebSocket connection...');
  debugPrint('🔍 Supabase URL: ${_supabase.supabaseUrl}');
  debugPrint('🔍 Supabase Key: ${_supabase.supabaseKey.substring(0, 10)}...');
  
  // Check if we can create a test channel
  final testChannel = _supabase.channel('connection-test');
  
  try {
    await testChannel.subscribe();
    debugPrint('✅ WebSocket connection working - test channel subscribed');
    await _supabase.removeChannel(testChannel);
  } catch (e) {
    debugPrint('❌ WebSocket connection failed: $e');
  }
}
```

### **Step 5: Verify Driver App Broadcast**

The driver app should be doing this:

```dart
// Driver app location broadcasting (what we expect)
Timer.periodic(Duration(seconds: 15), (timer) async {
  final position = await getCurrentPosition();
  
  final payload = {
    'driver_id': currentDriverId,
    'delivery_id': activeDeliveryId,
    'latitude': position.latitude,
    'longitude': position.longitude,
    'speed_kmh': position.speed * 3.6,
    'heading': position.heading,
    'battery_level': await getBatteryLevel(),
    'timestamp': DateTime.now().toIso8601String(),
  };
  
  debugPrint('📤 DRIVER: Broadcasting location to channel: driver-location-$activeDeliveryId');
  debugPrint('📤 DRIVER: Payload: $payload');
  
  await supabase
    .channel('driver-location-$activeDeliveryId')
    .sendBroadcastMessage('location_update', payload);
    
  debugPrint('✅ DRIVER: Location broadcast sent');
});
```

## 🚨 **Common Issues & Solutions**

### **Issue 1: No broadcasts received at all**
**Causes:**
- Channel name mismatch between driver and customer
- Driver not actually broadcasting
- WebSocket connection failed

**Debug:**
```dart
// Check if ANY broadcasts are received
channel.onBroadcast(
  event: '*', // Listen to ALL events
  callback: (payload) {
    debugPrint('🎯 ANY BROADCAST RECEIVED: $payload');
  },
);
```

### **Issue 2: Broadcasts received but location not updating**
**Causes:**
- Data format issues (wrong field names)
- Coordinates are null/invalid
- Map not updating properly

**Debug:**
```dart
// Check exact payload structure
void _updateDriverLocation(Map<String, dynamic> location) {
  debugPrint('FULL LOCATION PAYLOAD:');
  location.forEach((key, value) {
    debugPrint('  $key: $value (${value.runtimeType})');
  });
  
  // ... rest of method
}
```

### **Issue 3: Intermittent updates**
**Causes:**
- Driver app going to background
- Network connectivity issues
- Timer being cancelled

**Solution:**
- Add heartbeat/keepalive mechanism
- Background processing permissions
- Network status monitoring

### **Issue 4: Channel not found**
**Causes:**
- Delivery ID mismatch
- Channel created before subscription
- Supabase connection issues

**Debug:**
```dart
// Verify exact delivery ID being used
debugPrint('Using delivery ID: "${widget.deliveryId}"');
debugPrint('Channel name will be: "driver-location-${widget.deliveryId}"');
```

## 🧪 **Testing Commands**

### **1. Test WebSocket Connection**
```dart
// Add to tracking screen initState()
await _realtimeService.debugWebSocketConnection();
```

### **2. Test Manual Broadcast**
```dart
// Add button to tracking screen for testing
ElevatedButton(
  onPressed: () => _realtimeService.testBroadcastLocation(widget.deliveryId),
  child: Text('Test Broadcast'),
)
```

### **3. Monitor All Channel Activity**
```dart
// Subscribe to all events on the location channel
channel.onBroadcast(
  event: '*',
  callback: (payload) {
    debugPrint('📻 ALL CHANNEL ACTIVITY: $payload');
  },
);
```

## 🎯 **Next Steps**

1. **Add enhanced logging** to both customer and driver apps
2. **Verify delivery ID consistency** between apps
3. **Test manual broadcast** to confirm WebSocket is working
4. **Check driver app broadcast implementation**
5. **Monitor Flutter debug console** for WebSocket messages
6. **Verify network connectivity** on both devices

## 📱 **Expected Debug Output**

When working correctly, you should see:

```
🔊 CustomerRealtimeService: Attempting to subscribe to driver-location-abc123
🔌 CustomerRealtimeService: Subscribing to channel...
✅ CustomerRealtimeService: Successfully subscribed to driver-location-abc123
🎯 CustomerRealtimeService: Now listening for "location_update" events

📡 CustomerRealtimeService: RAW BROADCAST RECEIVED
📡 Channel: driver-location-abc123
📡 Event: location_update
📡 Payload: {driver_id: xyz789, delivery_id: abc123, latitude: 14.5995, longitude: 120.9842, ...}
📡 Processed location data: {driver_id: xyz789, delivery_id: abc123, latitude: 14.5995, longitude: 120.9842, deliveryId: abc123}
✅ CustomerRealtimeService: Location update processed for delivery abc123

🚗 TrackingScreen: _updateDriverLocation called
🚗 Raw location data: {driver_id: xyz789, delivery_id: abc123, latitude: 14.5995, longitude: 120.9842, deliveryId: abc123}
🚗 Parsed coordinates: lat=14.5995, lng=120.9842
✅ Driver location updated and will be passed to map: 14.5995, 120.9842
```

**If you're not seeing these logs, that tells us exactly where the issue is!** 🎯