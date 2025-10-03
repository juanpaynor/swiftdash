import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef LocationCallback = void Function(Map<String, dynamic> payload);
typedef DeliveryCallback = void Function(Map<String, dynamic> payload);

/// Simple RealtimeService wrapper for subscribing to driver-location broadcasts
/// and delivery table updates. Uses the existing Supabase client instance.
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamSubscription> _tableSubs = {};

  /// Subscribe to a driver-location broadcast channel for a delivery.
  ///
  /// channelName: driver-location-{deliveryId}
  /// event: 'location_update' (recommended)
  Future<void> subscribeToLiveGps({
    required String deliveryId,
    required LocationCallback onUpdate,
  }) async {
    // Subscribe to the persisted driver_current_status row that has current_delivery_id = deliveryId
    // This uses the stable table-stream API which works with Supabase logical replication.
    final key = 'live_gps:$deliveryId';
    if (_tableSubs.containsKey(key)) return;

    final sub = _supabase
        .from('driver_current_status:current_delivery_id=eq.$deliveryId')
        .stream(primaryKey: ['driver_id'])
        .listen((rows) {
      try {
        if (rows.isEmpty) return;
        // Expect the driver_current_status row as a map
        final row = Map<String, dynamic>.from(rows.first as Map);
        onUpdate(row);
      } catch (e, st) {
        if (kDebugMode) debugPrint('RealtimeService: invalid live_gps payload: $e\n$st');
      }
    });

    _tableSubs[key] = sub as StreamSubscription;
    if (kDebugMode) debugPrint('RealtimeService: subscribed to live_gps for delivery $deliveryId');
  }

  /// Unsubscribe from a live gps channel
  Future<void> unsubscribeLiveGps(String deliveryId) async {
    final key = 'live_gps:$deliveryId';
    final sub = _tableSubs.remove(key);
    if (sub != null) {
      try {
        await sub.cancel();
      } catch (_) {}
    }
    if (kDebugMode) debugPrint('RealtimeService: unsubscribed from live_gps for delivery $deliveryId');
  }

  /// Subscribe to delivery table updates for a specific delivery id.
  /// Uses .from(...).on(...) style which is persisted events (table-level realtime)
  Future<void> subscribeToDelivery({
    required String deliveryId,
    required DeliveryCallback onUpdate,
  }) async {
    final key = 'deliveries:$deliveryId';
    if (_tableSubs.containsKey(key)) return;

    final sub = _supabase
        .from('deliveries:id=eq.$deliveryId')
        .stream(primaryKey: ['id'])
        .listen((rows) {
      try {
        if (rows.isEmpty) return;
        final row = Map<String, dynamic>.from(rows.first as Map);
        onUpdate(row);
      } catch (e, st) {
        if (kDebugMode) debugPrint('RealtimeService: invalid delivery payload: $e\n$st');
      }
    });

    _tableSubs[key] = sub as StreamSubscription;

    if (kDebugMode) debugPrint('RealtimeService: subscribed to deliveries:$deliveryId');
  }

  /// Unsubscribe from delivery table updates
  Future<void> unsubscribeDelivery(String deliveryId) async {
    final key = 'deliveries:$deliveryId';
    final sub = _tableSubs.remove(key);
    if (sub != null) {
      try {
        await sub.cancel();
      } catch (_) {}
    }
    if (kDebugMode) debugPrint('RealtimeService: unsubscribed from deliveries:$deliveryId');
  }

  /// Dispose all subscriptions (useful on sign-out)
  Future<void> disposeAll() async {
    final channels = List<RealtimeChannel>.from(_channels.values);
    _channels.clear();

    for (final c in channels) {
      try {
        await _supabase.removeChannel(c);
      } catch (_) {}
    }

    final subs = List<StreamSubscription>.from(_tableSubs.values);
    _tableSubs.clear();

    for (final s in subs) {
      try {
        await s.cancel();
      } catch (_) {}
    }

    if (kDebugMode) debugPrint('RealtimeService: disposed all subscriptions');
  }
}
