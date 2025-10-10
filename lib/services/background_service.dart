import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background service to keep SwiftDash running when minimized
/// 
/// Features:
/// - Maintains WebSocket connections
/// - Keeps real-time delivery updates active
/// - Preserves location tracking
/// - Shows persistent notification
class BackgroundService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;
  static Timer? _heartbeatTimer;

  /// Initialize background service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize notifications
      await _initializeNotifications();
      
      // Configure background service
      final service = FlutterBackgroundService();
      
      await service.configure(
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          isForegroundMode: true,
          autoStart: true,
          autoStartOnBoot: true,
          notificationChannelId: 'swiftdash_background',
          initialNotificationTitle: 'SwiftDash',
          initialNotificationContent: 'Keeping your delivery app ready',
          foregroundServiceNotificationId: 888,
        ),
      );
      
      _isInitialized = true;
      debugPrint('✅ Background service initialized');
    } catch (e) {
      debugPrint('❌ Background service initialization failed: $e');
    }
  }

  /// Start background service
  static Future<void> start() async {
    try {
      if (!_isInitialized) await initialize();
      
      final service = FlutterBackgroundService();
      
      // Enable wakelock to prevent CPU sleep
      await WakelockPlus.enable();
      
      // Start the service
      bool isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
        debugPrint('🚀 Background service started');
      }
      
      // Start heartbeat
      _startHeartbeat();
      
      // Show persistent notification
      await _showBackgroundNotification();
      
    } catch (e) {
      debugPrint('❌ Failed to start background service: $e');
    }
  }

  /// Stop background service  
  static Future<void> stop() async {
    try {
      final service = FlutterBackgroundService();
      service.invoke('stop');
      
      // Disable wakelock
      await WakelockPlus.disable();
      
      // Stop heartbeat
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      
      // Hide notification
      await _notifications.cancel(888);
      
      debugPrint('🛑 Background service stopped');
    } catch (e) {
      debugPrint('❌ Failed to stop background service: $e');
    }
  }

  /// Check if service is running
  static Future<bool> isRunning() async {
    try {
      final service = FlutterBackgroundService();
      return await service.isRunning();
    } catch (e) {
      debugPrint('❌ Failed to check service status: $e');
      return false;
    }
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
    
    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'swiftdash_background',
      'SwiftDash Background Service',
      description: 'Keeps SwiftDash running in background',
      importance: Importance.low,
      showBadge: false,
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Show persistent background notification
  static Future<void> _showBackgroundNotification() async {
    const notification = AndroidNotificationDetails(
      'swiftdash_background',
      'SwiftDash Background Service',
      channelDescription: 'Keeps SwiftDash running in background',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
    );
    
    await _notifications.show(
      888,
      'SwiftDash Active',
      'Ready for deliveries and real-time updates',
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

/// Background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  debugPrint('🔥 Background service onStart called');
  
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }
  
  service.on('stop').listen((event) {
    service.stopSelf();
  });
  
  // Keep service alive with periodic ping
  Timer.periodic(const Duration(minutes: 2), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        debugPrint('📡 Background service heartbeat - ${DateTime.now()}');
        
        // Update notification to show app is active
        service.setForegroundNotificationInfo(
          title: "SwiftDash Active",
          content: "Last updated: ${DateTime.now().toString().substring(11, 19)}",
        );
      }
    }
  });
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  debugPrint('🍎 iOS background service running');
  return true;
}