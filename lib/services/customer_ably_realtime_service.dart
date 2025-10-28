import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ably_service.dart';

/// Customer-side Ably real-time service for tracking deliveries
/// 
/// This service handles:
/// - Subscribing to driver location updates
/// - Monitoring driver presence (online/offline status)
/// - Message history recovery after reconnection
/// - Stream-based location updates for UI consumption
class CustomerAblyRealtimeService {
  static final CustomerAblyRealtimeService _instance =
      CustomerAblyRealtimeService._internal();
  factory CustomerAblyRealtimeService() => _instance;
  CustomerAblyRealtimeService._internal();

  final AblyService _ablyService = AblyService();
  ably.RealtimeChannel? _currentChannel;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _presenceEnterSubscription;
  StreamSubscription? _presenceLeaveSubscription;

  String? _currentDeliveryId;

  // Stream controllers for broadcasting updates to UI
  final _locationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _driverStatusController = StreamController<String>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  /// Stream of location updates
  /// 
  /// Emits location data whenever driver publishes an update:
  /// {
  ///   'delivery_id': '...',
  ///   'latitude': 14.5995,
  ///   'longitude': 120.9842,
  ///   'timestamp': '2025-10-17T10:30:45Z',
  ///   'bearing': 180.5,
  ///   'speed': 25.3,
  ///   'accuracy': 10.5,
  ///   'battery_level': 85
  /// }
  Stream<Map<String, dynamic>> get locationStream => _locationController.stream;

  /// Stream of driver status updates
  /// 
  /// Emits: 'online' | 'offline' | 'unknown'
  Stream<String> get driverStatusStream => _driverStatusController.stream;

  /// Stream of connection status
  /// 
  /// Emits: true when connected, false when disconnected
  Stream<bool> get connectionStatusStream =>
      _connectionStatusController.stream;

  /// Initialize Ably connection
  Future<void> initialize(String clientKey) async {
    try {
      await _ablyService.initialize(clientKey);
      _connectionStatusController.add(_ablyService.isConnected);
      debugPrint('✅ Customer Ably service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize Customer Ably service: $e');
      _connectionStatusController.add(false);
      rethrow;
    }
  }

  /// Subscribe to a delivery's location tracking channel
  /// 
  /// This will:
  /// 1. Unsubscribe from any previous delivery
  /// 2. Subscribe to tracking:{deliveryId} channel
  /// 3. Set up location update listener
  /// 4. Set up presence listeners (driver online/offline)
  /// 5. Recover message history (last location)
  Future<void> subscribeToDelivery(String deliveryId) async {
    try {
      // Unsubscribe from previous delivery if any
      await unsubscribe();

      _currentDeliveryId = deliveryId;
      final channelName = 'tracking:$deliveryId';
      _currentChannel = _ablyService.getChannel(channelName);

      // Subscribe to location updates
      _locationSubscription = _currentChannel!
          .subscribe(name: 'location-update')
          .listen((message) {
        try {
          debugPrint('📨 RAW MESSAGE RECEIVED:');
          debugPrint('   - Name: ${message.name}');
          debugPrint('   - Data type: ${message.data.runtimeType}');
          debugPrint('   - Data: ${message.data}');
          
          // Convert Map<Object?, Object?> to Map<String, dynamic>
          final rawData = message.data as Map<Object?, Object?>;
          final locationData = Map<String, dynamic>.from(
            rawData.map((key, value) => MapEntry(key.toString(), value))
          );
          
          _locationController.add(locationData);
          
          if (kDebugMode) {
            debugPrint('📍 Received location update: '
                '${locationData['latitude']}, ${locationData['longitude']} '
                '(accuracy: ${locationData['accuracy']}m, '
                'battery: ${locationData['battery_level']}%)');
          }
        } catch (e) {
          debugPrint('❌ Error processing location update: $e');
          debugPrint('❌ Message data was: ${message.data}');
          debugPrint('❌ Stack trace: $e');
        }
      });

      // Subscribe to presence - driver entered (online)
      _presenceEnterSubscription = _currentChannel!.presence
          .subscribe(action: ably.PresenceAction.enter)
          .listen((_) {
        _driverStatusController.add('online');
        debugPrint('👋 Driver is online');
      });

      // Subscribe to presence - driver left (offline)
      _presenceLeaveSubscription = _currentChannel!.presence
          .subscribe(action: ably.PresenceAction.leave)
          .listen((_) {
        _driverStatusController.add('offline');
        debugPrint('👋 Driver is offline');
      });

      // Get message history to recover last known location
      await _recoverLastLocation();

      // Enter presence as customer (optional - indicates customer is watching)
      await _ablyService.enterPresence(deliveryId, {
        'customer_watching': true,
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Subscribed to delivery tracking: $channelName');
      _connectionStatusController.add(true);
    } catch (e) {
      debugPrint('❌ Failed to subscribe to delivery: $e');
      _connectionStatusController.add(false);
      _driverStatusController.add('unknown');
    }
  }

  /// Recover last location from message history
  /// 
  /// This helps when customer opens tracking screen and driver
  /// hasn't sent a new update yet
  Future<void> _recoverLastLocation() async {
    try {
      if (_currentChannel == null) return;

      final history = await _currentChannel!.history(
        ably.RealtimeHistoryParams(limit: 1),
      );

      if (history.items.isNotEmpty) {
        final latestMessage = history.items.first;
        if (latestMessage.data != null &&
            latestMessage.name == 'location-update') {
          // Convert Map<Object?, Object?> to Map<String, dynamic>
          final rawData = latestMessage.data as Map<Object?, Object?>;
          final locationData = Map<String, dynamic>.from(
            rawData.map((key, value) => MapEntry(key.toString(), value))
          );
          _locationController.add(locationData);
          debugPrint('📜 Recovered latest location from history');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Could not recover message history: $e');
      // Not critical - continue without history
    }
  }

  /// Get current driver presence status
  /// 
  /// Returns list of present members (drivers)
  Future<List<ably.PresenceMessage>> getPresence() async {
    try {
      if (_currentChannel == null) return [];

      final presenceMessages = await _currentChannel!.presence.get();
      return presenceMessages;
    } catch (e) {
      debugPrint('❌ Failed to get presence: $e');
      return [];
    }
  }

  /// Check if driver is currently online
  Future<bool> isDriverOnline() async {
    final presence = await getPresence();
    return presence.any((member) {
      if (member.data == null) return false;
      
      try {
        // Convert Map<Object?, Object?> to Map<String, dynamic>
        final rawData = member.data as Map<Object?, Object?>;
        final data = Map<String, dynamic>.from(
          rawData.map((key, value) => MapEntry(key.toString(), value))
        );
        return data['driver_status'] == 'online';
      } catch (e) {
        debugPrint('⚠️ Error checking driver status: $e');
        return false;
      }
    });
  }

  /// Unsubscribe from current delivery
  Future<void> unsubscribe() async {
    try {
      // Cancel subscriptions
      await _locationSubscription?.cancel();
      await _presenceEnterSubscription?.cancel();
      await _presenceLeaveSubscription?.cancel();

      _locationSubscription = null;
      _presenceEnterSubscription = null;
      _presenceLeaveSubscription = null;

      // Leave presence
      if (_currentDeliveryId != null) {
        await _ablyService.leavePresence(_currentDeliveryId!);
      }

      // Detach from channel
      if (_currentDeliveryId != null) {
        await _ablyService.detachChannel(_currentDeliveryId!);
      }

      _currentChannel = null;
      _currentDeliveryId = null;

      debugPrint('🔌 Unsubscribed from delivery tracking');
    } catch (e) {
      debugPrint('⚠️ Error during unsubscribe: $e');
    }
  }

  /// Get connection state
  bool get isConnected => _ablyService.isConnected;

  /// Get connection state string
  String get connectionStateString => _ablyService.connectionStateString;

  /// Dispose service and close all connections
  Future<void> dispose() async {
    await unsubscribe();
    await _locationController.close();
    await _driverStatusController.close();
    await _connectionStatusController.close();
    debugPrint('🔌 Customer Ably service disposed');
  }
}
