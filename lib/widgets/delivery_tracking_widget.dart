import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/realtime_service.dart';

/// A lightweight widget that subscribes to live GPS broadcasts for a delivery
/// and to delivery lifecycle updates. It shows a simple readout and exposes
/// callbacks for the parent to render a map marker.
class DeliveryTrackingWidget extends StatefulWidget {
  final String deliveryId;
  final void Function(Map<String, dynamic> location)? onLocation;
  final void Function(Map<String, dynamic> delivery)? onDeliveryUpdate;

  const DeliveryTrackingWidget({
    Key? key,
    required this.deliveryId,
    this.onLocation,
    this.onDeliveryUpdate,
  }) : super(key: key);

  @override
  State<DeliveryTrackingWidget> createState() => _DeliveryTrackingWidgetState();
}

class _DeliveryTrackingWidgetState extends State<DeliveryTrackingWidget> {
  Map<String, dynamic>? _lastLocation;
  Map<String, dynamic>? _lastDelivery;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  Future<void> _subscribe() async {
    // Ensure authenticated session for RLS
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to view live tracking')),
        );
      }
      return;
    }

    // Live GPS broadcasts
    await RealtimeService.instance.subscribeToLiveGps(
      deliveryId: widget.deliveryId,
      onUpdate: (payload) {
        setState(() => _lastLocation = payload);
        if (widget.onLocation != null) widget.onLocation!(payload);
      },
    );

    // Delivery lifecycle updates
    await RealtimeService.instance.subscribeToDelivery(
      deliveryId: widget.deliveryId,
      onUpdate: (payload) {
        setState(() => _lastDelivery = payload);
        if (widget.onDeliveryUpdate != null) widget.onDeliveryUpdate!(payload);
      },
    );

    setState(() => _subscribed = true);
  }

  @override
  void dispose() {
    RealtimeService.instance.unsubscribeLiveGps(widget.deliveryId);
    RealtimeService.instance.unsubscribeDelivery(widget.deliveryId);
    super.dispose();
  }

  Widget _buildLocationCard() {
    if (_lastLocation == null) {
      return const Text('Waiting for driver location...');
    }

    final lat = _lastLocation!['latitude'] ?? _lastLocation!['lat'] ?? _lastLocation!['latitude_deg'];
    final lon = _lastLocation!['longitude'] ?? _lastLocation!['lon'] ?? _lastLocation!['longitude_deg'];
    final battery = _lastLocation!['battery_level'];
    final ts = _lastLocation!['timestamp'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Driver: ${_lastLocation!['driver_id'] ?? 'unknown'}'),
        Text('Lat: $lat, Lon: $lon'),
        if (battery != null) Text('Battery: $battery%'),
        if (ts != null) Text('Updated: $ts'),
      ],
    );
  }

  Widget _buildDeliveryCard() {
    if (_lastDelivery == null) return const SizedBox.shrink();

    final status = _lastDelivery!['new'] != null ? _lastDelivery!['new']['status'] : _lastDelivery!['status'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Delivery status: $status'),
        if (_lastDelivery!['new'] != null && _lastDelivery!['new']['driver_id'] != null)
          Text('Driver: ${_lastDelivery!['new']['driver_id']}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Tracking', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildLocationCard(),
            const SizedBox(height: 12),
            _buildDeliveryCard(),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _subscribed
                      ? null
                      : () async {
                          await _subscribe();
                        },
                  child: Text(_subscribed ? 'Subscribed' : 'Subscribe'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    await RealtimeService.instance.unsubscribeLiveGps(widget.deliveryId);
                    await RealtimeService.instance.unsubscribeDelivery(widget.deliveryId);
                    setState(() {
                      _subscribed = false;
                      _lastLocation = null;
                    });
                  },
                  child: const Text('Unsubscribe'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
