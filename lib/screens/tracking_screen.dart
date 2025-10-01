import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../models/delivery.dart';
import '../services/delivery_service.dart';
import '../services/auth_service.dart';
import '../widgets/modern_widgets.dart';

class TrackingScreen extends StatefulWidget {
  final String? deliveryId;
  
  const TrackingScreen({super.key, this.deliveryId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  List<Delivery> _deliveries = [];
  bool _isLoading = true;
  Delivery? _activeDelivery;
  Map<String, dynamic>? _driverLocation;
  StreamSubscription? _deliverySubscription;
  StreamSubscription? _driverLocationSubscription;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
    
    // If specific delivery ID provided, focus on it
    if (widget.deliveryId != null) {
      _loadSpecificDelivery(widget.deliveryId!);
    }
  }

  @override
  void dispose() {
    _deliverySubscription?.cancel();
    _driverLocationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSpecificDelivery(String deliveryId) async {
    try {
      final delivery = await DeliveryService.getDeliveryById(deliveryId);
      if (delivery != null && delivery.isActive) {
        setState(() => _activeDelivery = delivery);
        _startRealTimeTracking(delivery);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading delivery: $e')),
        );
      }
    }
  }

  void _startRealTimeTracking(Delivery delivery) {
    // Listen to delivery status updates
    _deliverySubscription = DeliveryService.streamDeliveryUpdates(delivery.id)
        .listen((updatedDelivery) {
      setState(() => _activeDelivery = updatedDelivery);
      
      // If driver assigned, start tracking driver location
      if (updatedDelivery.driverId != null && _driverLocationSubscription == null) {
        _startDriverLocationTracking(updatedDelivery.driverId!);
      }
      
      // Stop tracking if delivery completed
      if (!updatedDelivery.isActive) {
        _stopRealTimeTracking();
      }
    });

    // If driver already assigned, start location tracking
    if (delivery.driverId != null) {
      _startDriverLocationTracking(delivery.driverId!);
    }
  }

  void _startDriverLocationTracking(String driverId) {
    _driverLocationSubscription = DeliveryService.streamDriverLocation(driverId)
        .listen((location) {
      setState(() => _driverLocation = location);
    });
  }

  void _stopRealTimeTracking() {
    _deliverySubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _deliverySubscription = null;
    _driverLocationSubscription = null;
  }

  Future<void> _loadDeliveries() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return;

      final deliveries = await DeliveryService.getUserDeliveries(userId);
      
      setState(() {
        _deliveries = deliveries;
        _isLoading = false;
      });

      // Auto-select first active delivery for tracking
      if (_activeDelivery == null) {
        final activeDelivery = deliveries.firstWhere(
          (d) => d.isActive,
          orElse: () => deliveries.isNotEmpty ? deliveries.first : Delivery(
            id: '', customerId: '', vehicleTypeId: '', 
            pickupAddress: '', pickupLatitude: 0, pickupLongitude: 0,
            pickupContactName: '', pickupContactPhone: '',
            deliveryAddress: '', deliveryLatitude: 0, deliveryLongitude: 0,
            deliveryContactName: '', deliveryContactPhone: '',
            packageDescription: '', totalPrice: 0, status: '',
            createdAt: DateTime.now(), updatedAt: DateTime.now()
          ),
        );
        
        if (activeDelivery.id.isNotEmpty && activeDelivery.isActive) {
          setState(() => _activeDelivery = activeDelivery);
          _startRealTimeTracking(activeDelivery);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading deliveries: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: ModernAppBar(
        title: _activeDelivery != null ? 'Live Tracking' : 'My Deliveries',
        showBackButton: true,
        onBackPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeDelivery != null && _activeDelivery!.isActive
              ? _buildActiveDeliveryTracking()
              : _buildDeliveryHistory(),
    );
  }

  Widget _buildActiveDeliveryTracking() {
    final delivery = _activeDelivery!;
    
    return Column(
      children: [
        // Live Status Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [delivery.getStatusColor().withOpacity(0.1), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: delivery.getStatusColor().withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: delivery.getStatusColor(),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      delivery.statusDisplay,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (delivery.driverId != null && _driverLocation != null)
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Live',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                delivery.packageDescription,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildAddressRow(Icons.circle, Colors.green, delivery.pickupAddress),
              const SizedBox(height: 8),
              _buildAddressRow(Icons.circle, Colors.red, delivery.deliveryAddress),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (delivery.distanceKm != null)
                    Text(
                      '${delivery.distanceKm!.toStringAsFixed(1)} km',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  Text(
                    '₱${delivery.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Driver Info (if assigned)
        if (delivery.driverId != null) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver Assigned',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      if (_driverLocation != null)
                        Text(
                          'Location updated ${_formatLocationTime(_driverLocation!['location_updated_at'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.phone, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Map placeholder (could integrate SharedDeliveryMap here later)
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Live Map View',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your delivery in real-time',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressRow(IconData icon, Color color, String address) {
    return Row(
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryHistory() {
    if (_deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No deliveries yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your delivery history will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDeliveries,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _deliveries.length,
        itemBuilder: (context, index) {
          final delivery = _deliveries[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: delivery.isActive ? () {
                setState(() => _activeDelivery = delivery);
                _startRealTimeTracking(delivery);
              } : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status and Date Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: delivery.getStatusColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: delivery.getStatusColor(),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            delivery.statusDisplay,
                            style: TextStyle(
                              color: delivery.getStatusColor(),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            if (delivery.isActive)
                              Icon(Icons.visibility, size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(delivery.createdAt),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Package Description
                    Text(
                      delivery.packageDescription,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Pickup and Delivery Addresses
                    _buildAddressRow(Icons.circle, Colors.green, delivery.pickupAddress),
                    const SizedBox(height: 4),
                    _buildAddressRow(Icons.circle, Colors.red, delivery.deliveryAddress),
                    const SizedBox(height: 12),
                    
                    // Price and Distance
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (delivery.distanceKm != null)
                          Text(
                            '${delivery.distanceKm!.toStringAsFixed(1)} km',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        Text(
                          '₱${delivery.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatLocationTime(String? timestamp) {
    if (timestamp == null) return 'recently';
    
    try {
      final time = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(time);
      
      if (difference.inMinutes < 1) return 'just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return '${difference.inDays}d ago';
    } catch (e) {
      return 'recently';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
