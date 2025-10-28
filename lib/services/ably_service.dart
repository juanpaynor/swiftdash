import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:flutter/foundation.dart';

/// Core Ably service for managing real-time connections and channels
/// 
/// This service handles:
/// - Ably connection initialization and management
/// - Channel creation and retrieval
/// - Location message publishing
/// - Presence management (online/offline status)
/// - Connection state monitoring
class AblyService {
  static final AblyService _instance = AblyService._internal();
  factory AblyService() => _instance;
  AblyService._internal();

  ably.Realtime? _realtime;
  final Map<String, ably.RealtimeChannel> _channels = {};

  bool _isInitialized = false;

  /// Initialize Ably connection with client key
  Future<void> initialize(String clientKey) async {
    if (_isInitialized) {
      debugPrint('⚠️ Ably already initialized');
      return;
    }

    try {
      final clientOptions = ably.ClientOptions(
        key: clientKey,
        clientId: 'customer-${DateTime.now().millisecondsSinceEpoch}',
        autoConnect: true,
        logLevel: kDebugMode ? ably.LogLevel.verbose : ably.LogLevel.error,
        // Disable heartbeats to prevent 25-second timeout disconnections
        // Ably's WebSocket transport has heartbeats=false in URL params
        // This matches the transport behavior and prevents unnecessary reconnections
      );

      _realtime = ably.Realtime(options: clientOptions);

      // Listen to connection state changes
      _realtime!.connection
          .on(ably.ConnectionEvent.connected)
          .listen((_) {
        debugPrint('✅ Ably connected');
      });

      _realtime!.connection
          .on(ably.ConnectionEvent.disconnected)
          .listen((_) {
        debugPrint('! Ably disconnected');
        // Auto-reconnect on disconnection
        if (_isInitialized && _realtime != null) {
          debugPrint('🔄 Attempting to reconnect Ably...');
          try {
            _realtime!.connection.connect();
          } catch (e) {
            debugPrint('❌ Ably reconnection error: $e');
          }
        }
      });

      _realtime!.connection
          .on(ably.ConnectionEvent.suspended)
          .listen((_) {
        debugPrint('⚠️ Ably connection suspended');
      });

      _realtime!.connection
          .on(ably.ConnectionEvent.failed)
          .listen((_) {
        debugPrint('❌ Ably connection failed');
      });

      _realtime!.connection
          .on(ably.ConnectionEvent.closed)
          .listen((_) {
        debugPrint('🔌 Ably connection closed');
      });

      _isInitialized = true;
      debugPrint('🚀 Ably service initialized');
    } catch (e) {
      debugPrint('❌ Ably initialization error: $e');
      rethrow;
    }
  }

  /// Get or create a channel by name
  /// 
  /// Channels are cached to avoid creating duplicates
  ably.RealtimeChannel getChannel(String channelName) {
    if (!_isInitialized) {
      throw Exception('Ably service not initialized. Call initialize() first.');
    }

    if (_channels.containsKey(channelName)) {
      debugPrint('♻️ Reusing existing channel: $channelName');
      return _channels[channelName]!;
    }

    final channel = _realtime!.channels.get(channelName);
    _channels[channelName] = channel;
    debugPrint('📡 Created new channel: $channelName');
    return channel;
  }

  /// Publish location update to a delivery channel
  /// 
  /// Channel format: tracking:{deliveryId}
  /// Message name: location-update
  Future<void> publishLocation({
    required String deliveryId,
    required Map<String, dynamic> locationData,
  }) async {
    try {
      final channelName = 'tracking:$deliveryId';
      final channel = getChannel(channelName);

      await channel.publish(
        name: 'location-update',
        data: locationData,
      );

      if (kDebugMode) {
        debugPrint('📍 Published location to $channelName: '
            '${locationData['latitude']}, ${locationData['longitude']}');
      }
    } catch (e) {
      debugPrint('❌ Failed to publish location: $e');
      // Don't rethrow - failed location updates shouldn't crash the app
    }
  }

  /// Enter presence on a delivery channel (mark as online)
  /// 
  /// Used by customer app to indicate they're actively tracking
  Future<void> enterPresence(
    String deliveryId,
    Map<String, dynamic> presenceData,
  ) async {
    try {
      final channelName = 'tracking:$deliveryId';
      final channel = getChannel(channelName);

      await channel.presence.enter(presenceData);
      debugPrint('👋 Entered presence on $channelName');
    } catch (e) {
      debugPrint('❌ Failed to enter presence: $e');
    }
  }

  /// Update presence data
  Future<void> updatePresence(
    String deliveryId,
    Map<String, dynamic> presenceData,
  ) async {
    try {
      final channelName = 'tracking:$deliveryId';
      if (_channels.containsKey(channelName)) {
        await _channels[channelName]!.presence.update(presenceData);
        debugPrint('🔄 Updated presence on $channelName');
      }
    } catch (e) {
      debugPrint('❌ Failed to update presence: $e');
    }
  }

  /// Leave presence on a delivery channel (mark as offline)
  Future<void> leavePresence(String deliveryId) async {
    try {
      final channelName = 'tracking:$deliveryId';
      if (_channels.containsKey(channelName)) {
        await _channels[channelName]!.presence.leave();
        debugPrint('👋 Left presence on $channelName');
      }
    } catch (e) {
      debugPrint('❌ Failed to leave presence: $e');
    }
  }

  /// Detach from a channel and remove from cache
  Future<void> detachChannel(String deliveryId) async {
    try {
      final channelName = 'tracking:$deliveryId';
      if (_channels.containsKey(channelName)) {
        await _channels[channelName]!.detach();
        _channels.remove(channelName);
        debugPrint('🔌 Detached from $channelName');
      }
    } catch (e) {
      debugPrint('❌ Failed to detach channel: $e');
    }
  }

  /// Close all channels and the Ably connection
  Future<void> close() async {
    try {
      // Detach from all channels
      for (var entry in _channels.entries) {
        try {
          await entry.value.detach();
          debugPrint('🔌 Detached from ${entry.key}');
        } catch (e) {
          debugPrint('⚠️ Error detaching from ${entry.key}: $e');
        }
      }
      _channels.clear();

      // Close the connection
      await _realtime?.close();
      _isInitialized = false;
      debugPrint('🔌 Ably connection closed');
    } catch (e) {
      debugPrint('❌ Error closing Ably: $e');
    }
  }

  /// Check if Ably is connected
  bool get isConnected =>
      _isInitialized &&
      _realtime?.connection.state == ably.ConnectionState.connected;

  /// Get current connection state
  ably.ConnectionState? get connectionState => _realtime?.connection.state;

  /// Get connection state as a readable string
  String get connectionStateString {
    if (!_isInitialized) return 'not_initialized';
    switch (_realtime?.connection.state) {
      case ably.ConnectionState.initialized:
        return 'initialized';
      case ably.ConnectionState.connecting:
        return 'connecting';
      case ably.ConnectionState.connected:
        return 'connected';
      case ably.ConnectionState.disconnected:
        return 'disconnected';
      case ably.ConnectionState.suspended:
        return 'suspended';
      case ably.ConnectionState.closing:
        return 'closing';
      case ably.ConnectionState.closed:
        return 'closed';
      case ably.ConnectionState.failed:
        return 'failed';
      default:
        return 'unknown';
    }
  }

  /// Get the Ably Realtime client instance (for ChatService)
  ably.Realtime? get realtimeClient => _realtime;
}
