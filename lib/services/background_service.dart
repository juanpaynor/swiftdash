import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background service to keep SwiftDash responsive when minimized
/// 
/// Features:
/// - Maintains WebSocket connections using wakelock
/// - Keeps real-time delivery updates active
/// - Shows delivery status notifications
/// - Simple approach without complex background service
class BackgroundService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;
  static bool _isKeepAliveActive = false;
  static Timer? _heartbeatTimer;

  /// Initialize background service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize notifications
      await _initializeNotifications();
      
      _isInitialized = true;
      debugPrint('✅ Background service initialized');
    } catch (e) {
      debugPrint('❌ Background service initialization failed: $e');
    }
  }

  /// Start keep-alive functionality
  static Future<void> start() async {
    try {
      if (!_isInitialized) await initialize();
      
      // Enable wakelock to prevent CPU sleep during active deliveries
      await WakelockPlus.enable();
      _isKeepAliveActive = true;
      
      // Start heartbeat to maintain connections
      _startHeartbeat();
      
      debugPrint('🚀 Background keep-alive started');
      
    } catch (e) {
      debugPrint('❌ Failed to start background keep-alive: $e');
    }
  }

  /// Stop keep-alive functionality  
  static Future<void> stop() async {
    try {
      // Disable wakelock
      await WakelockPlus.disable();
      _isKeepAliveActive = false;
      
      // Stop heartbeat
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      
      debugPrint('🛑 Background keep-alive stopped');
    } catch (e) {
      debugPrint('❌ Failed to stop background keep-alive: $e');
    }
  }

  /// Check if keep-alive is active
  static bool isRunning() {
    return _isKeepAliveActive;
  }

  /// Initialize notification system
  static Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(initSettings);
    
    // Create notification channels for Android
    const deliveryChannel = AndroidNotificationChannel(
      'swiftdash_delivery',
      'SwiftDash Deliveries',
      description: 'Delivery status updates and notifications',
      importance: Importance.high,
      showBadge: true,
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(deliveryChannel);
  }

  /// Show delivery notification
  static Future<void> showDeliveryNotification(String title, String body) async {
    if (!_isInitialized) await initialize();
    
    const notification = AndroidNotificationDetails(
      'swiftdash_delivery',
      'SwiftDash Deliveries',
      channelDescription: 'Delivery status updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: notification),
    );
  }

  /// Start heartbeat to keep connections alive
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      // Ping Supabase to keep connection alive
      _pingSupabase();
    });
  }

  /// Ping Supabase to maintain connection
  static Future<void> _pingSupabase() async {
    try {
      if (Supabase.instance.client.auth.currentUser != null) {
        // Simple ping to keep connection alive
        await Supabase.instance.client
            .from('user_profiles')
            .select('id')
            .limit(1);
      }
    } catch (e) {
      debugPrint('Background ping failed: $e');
    }
  }
}

