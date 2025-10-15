import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/realtime_service.dart';
import '../services/delivery_service.dart';
import '../services/multi_stop_service.dart';
import '../models/delivery.dart';
import '../models/delivery_stop.dart';
import '../widgets/shared_delivery_map.dart';
import '../widgets/vertical_progress_stepper.dart';
import '../widgets/modern_floating_card.dart';
import '../widgets/modern_top_navigation.dart';
import '../constants/modern_colors.dart';
import '../utils/back_button_handler.dart';

/// Uber-style tracking screen with full-screen map and floating overlay cards
/// 
/// 🔧 IMPLEMENTS EXACT WEBSOCKET BROADCAST SPECIFICATIONS:
/// 1. Supabase Realtime Channels: _supabase.channel('driver-location-{deliveryId}')
/// 2. Broadcasting: channel.sendBroadcastMessage() - NO database writes, zero latency
/// 3. Listening: channel.onBroadcast() - instant callbacks, direct map updates
/// 4. Channel Management: granular channels, auto cleanup, no memory leaks
/// 
/// Driver app broadcasts GPS via: channel.sendBroadcastMessage('location_update', payload)
/// Customer app listens via: channel.onBroadcast(event: 'location_update', callback: updateMap)
class TrackingScreen extends StatefulWidget {
  final String deliveryId;

  const TrackingScreen({
    super.key,
    required this.deliveryId,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final CustomerRealtimeService _realtimeService = CustomerRealtimeService();
  final MultiStopService _multiStopService = MultiStopService();
  
  late StreamSubscription _locationSubscription;
  late StreamSubscription _deliverySubscription;
  late StreamSubscription _driverSubscription;
  
  Delivery? _delivery;
  List<DeliveryStop> _stops = [];
  Map<String, dynamic>? _driverLocation;
  Map<String, dynamic>? _driverProfile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeliveryAndSubscribe();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  Future<void> _loadDeliveryAndSubscribe() async {
    try {
      // Load delivery details
      final delivery = await DeliveryService.getDeliveryById(widget.deliveryId);
      if (delivery == null) {
        setState(() {
          _error = 'Delivery not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _delivery = delivery;
      });

      // Load stops if this is a multi-stop delivery
      if (delivery.isMultiStop) {
        try {
          final stops = await _multiStopService.getStops(widget.deliveryId);
          setState(() {
            _stops = stops;
          });
        } catch (e) {
          debugPrint('Failed to load stops: $e');
        }
      }

      setState(() {
        _isLoading = false;
      });

      // Fetch driver profile information if driver is assigned
      if (delivery.driverId != null) {
        await _fetchDriverProfile(delivery.driverId!);
      }

      // Subscribe to real-time updates
      await _subscribeToUpdates();
      
    } catch (e) {
      setState(() {
        _error = 'Failed to load delivery: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _subscribeToUpdates() async {
    if (_delivery == null) return;

    try {
      debugPrint('🔧 TrackingScreen: Setting up subscriptions for delivery: ${widget.deliveryId}');
      
      // Subscribe to driver location broadcasts
      await _realtimeService.subscribeToDriverLocation(widget.deliveryId);
      debugPrint('🔧 TrackingScreen: Location subscription setup complete');
      
      // Start a timer to detect if no location updates are received
      Timer(const Duration(seconds: 30), () {
        if (mounted && _driverLocation == null && _delivery?.status == 'driver_assigned') {
          debugPrint('⚠️ No driver location updates received after 30 seconds');
          debugPrint('⚠️ This suggests the driver app is not broadcasting location');
        }
      });
      
      _locationSubscription = _realtimeService.driverLocationUpdates.listen(
        (location) {
          debugPrint('🎯 TrackingScreen: Location update received from stream');
          debugPrint('🎯 Expected deliveryId: ${widget.deliveryId}');
          debugPrint('🎯 Received deliveryId: ${location['deliveryId']}');
          debugPrint('🎯 Mounted: $mounted');
          debugPrint('🎯 Location data: $location');
          
          if (mounted && location['deliveryId'] == widget.deliveryId) {
            debugPrint('✅ TrackingScreen: Processing location update');
            _updateDriverLocation(location);
          } else {
            debugPrint('⏭️ TrackingScreen: Skipping location update (wrong delivery or unmounted)');
          }
        },
        onError: (error) {
          debugPrint('❌ Location subscription error: $error');
        },
      );
      
      // Log subscription activity every 10 seconds to monitor WebSocket
      Timer.periodic(const Duration(seconds: 10), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        debugPrint('📊 WebSocket Status Check:');
        debugPrint('   - Subscribed to: driver-location-${widget.deliveryId}');
        debugPrint('   - Driver location received: ${_driverLocation != null ? 'YES' : 'NO'}');
        debugPrint('   - Delivery status: ${_delivery?.status}');
        debugPrint('   - Expected driver: ${_delivery?.driverId}');
        
        if (_driverLocation == null && (_delivery?.status == 'driver_assigned' || _delivery?.status == 'going_to_pickup')) {
          debugPrint('⚠️ No driver location updates - check if driver app is broadcasting');
        }
      });

      // Subscribe to delivery status updates
      await _realtimeService.subscribeToDelivery(widget.deliveryId);
      _deliverySubscription = _realtimeService.deliveryUpdates.listen(
        (delivery) {
          if (mounted && delivery['id'] == widget.deliveryId) {
            _updateDeliveryStatus(delivery);
          }
        },
        onError: (error) {
          debugPrint('Delivery subscription error: $error');
        },
      );

      // Subscribe to driver status if we have a driver assigned
      if (_delivery!.driverId != null) {
        await _realtimeService.subscribeToDriverStatus(_delivery!.driverId!);
        _driverSubscription = _realtimeService.driverStatusUpdates.listen(
          (driverData) {
            if (mounted && driverData['driver_id'] == _delivery!.driverId) {
              _updateDriverStatus(driverData);
            }
          },
          onError: (error) {
            debugPrint('Driver subscription error: $error');
          },
        );
      }
    } catch (e) {
      debugPrint('Failed to subscribe to updates: $e');
    }
  }

  // Fetch complete driver profile information
  Future<void> _fetchDriverProfile(String driverId) async {
    try {
      debugPrint('🔧 Fetching driver profile for: $driverId');
      
      final response = await Supabase.instance.client
          .from('driver_profiles')
          .select('''
            id,
            profile_picture_url,
            vehicle_model,
            plate_number,
            rating,
            total_deliveries,
            is_verified,
            vehicle_types!inner(name)
          ''')
          .eq('id', driverId)
          .single();
      
      // Also get user profile for driver name
      final userResponse = await Supabase.instance.client
          .from('user_profiles')
          .select('first_name, last_name')
          .eq('id', driverId)
          .single();
      
      setState(() {
        _driverProfile = {
          ...response,
          'first_name': userResponse['first_name'],
          'last_name': userResponse['last_name'],
          'full_name': '${userResponse['first_name']} ${userResponse['last_name']}',
        };
      });
      
      debugPrint('✅ Driver profile loaded: ${_driverProfile?['full_name']}');
    } catch (e) {
      debugPrint('❌ Failed to fetch driver profile: $e');
      // Don't set error state, just continue without driver profile
    }
  }

  void _updateDriverLocation(Map<String, dynamic> location) {
    debugPrint('🚗 TrackingScreen: _updateDriverLocation called');
    debugPrint('🚗 Raw location data: $location');
    debugPrint('🚗 Location keys: ${location.keys.toList()}');
    debugPrint('🚗 Location values: ${location.values.toList()}');
    
    // Log current state before update
    debugPrint('🚗 Previous _driverLocation: $_driverLocation');
    debugPrint('🚗 Current delivery status: ${_delivery?.status}');
    debugPrint('🚗 Widget mounted: $mounted');
    
    setState(() {
      _driverLocation = location;
    });

    final lat = location['latitude']?.toDouble();
    final lng = location['longitude']?.toDouble();
    
    debugPrint('🚗 Parsed coordinates: lat=$lat, lng=$lng');
    
    if (lat != null && lng != null) {
      debugPrint('✅ Driver location updated successfully');
      debugPrint('🗺️ Map will receive driverLatitude: $lat, driverLongitude: $lng');
      debugPrint('🗺️ Delivery coordinates - pickup: (${_delivery?.pickupLatitude}, ${_delivery?.pickupLongitude})');
      debugPrint('🗺️ Delivery coordinates - delivery: (${_delivery?.deliveryLatitude}, ${_delivery?.deliveryLongitude})');
      
      // Force a rebuild to ensure map gets updated coordinates
      debugPrint('🔄 Triggering UI rebuild for map update...');
    } else {
      debugPrint('❌ Invalid coordinates received: lat=$lat, lng=$lng');
      debugPrint('❌ Full location object: $location');
      debugPrint('❌ Raw latitude value: ${location['latitude']} (${location['latitude']?.runtimeType})');
      debugPrint('❌ Raw longitude value: ${location['longitude']} (${location['longitude']?.runtimeType})');
    }
    
    // Additional debug info about map state
    debugPrint('🗺️ SharedDeliveryMap will receive:');
    debugPrint('   - driverLatitude: ${_driverLocation?['latitude']?.toDouble()}');
    debugPrint('   - driverLongitude: ${_driverLocation?['longitude']?.toDouble()}');
    debugPrint('   - deliveryStatus: ${_delivery?.status}');
    debugPrint('   - driverVehicleType: ${_driverProfile?['vehicle_types']?['name']}');
  }

  void _updateDeliveryStatus(Map<String, dynamic> deliveryData) {
    final previousStatus = _delivery?.status;
    
    setState(() {
      if (_delivery != null) {
        _delivery = _delivery!.copyWith(
          status: deliveryData['status'],
          updatedAt: DateTime.tryParse(deliveryData['updated_at'] ?? ''),
        );
      }
    });

    // Show status update notification if status changed
    if (previousStatus != null && previousStatus != deliveryData['status']) {
      _showStatusUpdateNotification(deliveryData['status']);
    }
  }

  void _showStatusUpdateNotification(String newStatus) {
    final String message;
    final Color backgroundColor;
    
    switch (newStatus) {
      case 'driver_offered':
        message = 'Driver found - waiting for acceptance';
        backgroundColor = Colors.amber;
        break;
      case 'driver_assigned':
        message = 'Driver assigned and preparing for pickup';
        backgroundColor = Colors.blue;
        break;
      case 'going_to_pickup':
        message = 'Driver is heading to pickup location';
        backgroundColor = Colors.blue;
        break;
      case 'pickup_arrived':
        message = 'Driver has arrived at pickup location';
        backgroundColor = Colors.orange;
        break;
      case 'package_collected':
        message = 'Package collected - heading your way!';
        backgroundColor = Colors.purple;
        break;
      case 'going_to_destination':
        message = 'Driver is on the way to you';
        backgroundColor = Colors.green;
        break;
      case 'at_destination':
        message = 'Driver has arrived at your location';
        backgroundColor = Colors.amber;
        break;
      case 'in_transit':
        message = 'Your delivery is on the way';
        backgroundColor = Colors.green;
        break;
      case 'delivered':
        message = 'Delivery completed successfully!';
        backgroundColor = Colors.green;
        break;
      case 'cancelled':
        message = 'Delivery has been cancelled';
        backgroundColor = Colors.red;
        break;
      default:
        return; // Don't show notification for unknown statuses
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _updateDriverStatus(Map<String, dynamic> driverData) {
    setState(() {
      // Update driver profile with latest data
      _driverProfile = {...?_driverProfile, ...driverData};
    });
  }

  void _cleanup() {
    _locationSubscription.cancel();
    _deliverySubscription.cancel();
    _driverSubscription.cancel();
    _realtimeService.unsubscribeFromDriverLocation(widget.deliveryId);
    _realtimeService.unsubscribeFromDelivery(widget.deliveryId);
    if (_delivery?.driverId != null) {
      _realtimeService.unsubscribeFromDriverStatus(_delivery!.driverId!);
    }
  }

  Future<void> _callDriver() async {
    // TODO: Add driver phone to delivery model or fetch from driver profile
    // For now, we'll show a placeholder message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Driver contact feature coming soon')),
    );
  }

  Future<void> _messageDriver() async {
    // TODO: Add driver phone to delivery model or fetch from driver profile  
    // For now, we'll show a placeholder message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Driver messaging feature coming soon')),
    );
  }





  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: ModernColors.screenBackground,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernColors.primaryBlue),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: ModernColors.screenBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: const TextStyle(color: ModernColors.darkGrey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernColors.primaryBlue,
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SmartBackHandler(
      child: Scaffold(
        backgroundColor: ModernColors.screenBackground,
        body: Stack(
          children: [
            // Full-screen immersive map
            _buildFullScreenMap(),
            
            // Modern top navigation bar
            _buildModernTopNavigation(),
            
            // Vertical progress stepper (left side)
            if (_delivery != null) _buildVerticalProgressStepper(),
            
            // Modern floating focus card (bottom)
            if (_delivery != null) _buildModernFloatingCard(),
          ],
        ),
      ),
    );
  }

  // Full-screen map with real-time driver tracking
  Widget _buildFullScreenMap() {
    debugPrint('🔍 Building SharedDeliveryMap with:');
    debugPrint('   - driverLatitude: ${_driverLocation?['latitude']?.toDouble()}');
    debugPrint('   - driverLongitude: ${_driverLocation?['longitude']?.toDouble()}');
    debugPrint('   - deliveryStatus: ${_delivery?.status}');
    debugPrint('   - driverVehicleType: ${_driverProfile?['vehicle_types']?['name']}');
    
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: SharedDeliveryMap(
        // Set pickup and delivery locations from delivery data
        pickupLatitude: _delivery?.pickupLatitude,
        pickupLongitude: _delivery?.pickupLongitude,
        deliveryLatitude: _delivery?.deliveryLatitude,
        deliveryLongitude: _delivery?.deliveryLongitude,
        initialPickupAddress: _delivery?.pickupAddress,
        initialDeliveryAddress: _delivery?.deliveryAddress,
        // Real-time driver location tracking
        driverLatitude: _driverLocation?['latitude']?.toDouble(),
        driverLongitude: _driverLocation?['longitude']?.toDouble(),
        // Polyline phase management
        deliveryStatus: _delivery?.status,
        onRouteCalculated: _onRouteCalculated,
        // Driver vehicle type for map icons
        driverVehicleType: _driverProfile?['vehicle_types']?['name'],
      ),
    );
  }



  // Route calculation results
  double? _routeDistanceKm;
  double? _estimatedMinutes;

  void _onRouteCalculated(double distanceKm, double estimatedMinutes) {
    setState(() {
      _routeDistanceKm = distanceKm;
      _estimatedMinutes = estimatedMinutes;
    });
    
    print('📊 Route calculated: ${distanceKm.toStringAsFixed(1)}km, ${estimatedMinutes.toStringAsFixed(0)} min');
  }







  // Helper methods for modern UI components
  
  String _formatLastUpdate() {
    if (_driverLocation?['timestamp'] == null) return 'Unknown';
    
    try {
      final timestamp = DateTime.tryParse(_driverLocation!['timestamp']);
      if (timestamp == null) return 'Unknown';
      
      final now = DateTime.now();
      final difference = now.difference(timestamp);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else {
        return '${difference.inHours}h ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getEstimatedTime() {
    if (_delivery == null) return 'Calculating...';
    
    switch (_delivery!.status) {
      case 'driver_assigned':
      case 'going_to_pickup':
        if (_estimatedMinutes != null) {
          return 'ETA to pickup: ${_estimatedMinutes!.round()} min';
        }
        return 'Driver preparing - ETA 5-10 min';
      case 'pickup_arrived':
        return 'Driver at pickup location';
      case 'package_collected':
      case 'going_to_destination':
      case 'in_transit':
        if (_estimatedMinutes != null && _routeDistanceKm != null) {
          return 'ETA: ${_estimatedMinutes!.round()} min (${_routeDistanceKm!.toStringAsFixed(1)}km)';
        }
        return 'ETA ${_calculateDeliveryETA()}';
      case 'at_destination':
        return 'Driver has arrived at your location';
      case 'delivered':
        return 'Delivered successfully';
      default:
        return 'Location updating live';
    }
  }

  String _calculateDeliveryETA() {
    // Fallback ETA calculation when route data isn't available
    if (_delivery?.status == 'package_collected') {
      return '15-25 min';
    } else if (_delivery?.status == 'in_transit') {
      return '10-20 min';
    }
    return '20-30 min';
  }

  // Modern UI Components

  Widget _buildModernTopNavigation() {
    return ModernTopNavigationBar(
      orderNumber: widget.deliveryId,
      onBackPressed: () => context.go('/home'),
      onHelpPressed: () => _showHelpDialog(),
    );
  }

  Widget _buildVerticalProgressStepper() {
    final currentStage = DeliveryStage.fromStatus(_delivery?.status);
    return Positioned(
      left: 24,
      top: 140,
      child: VerticalProgressStepper(
        currentStage: currentStage,
      ),
    );
  }

  Widget _buildModernFloatingCard() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ModernFloatingCard(
        eta: _getEstimatedTime(),
        arrivalTime: _calculateArrivalTime(),
        driverName: _driverProfile?['full_name'],
        driverRating: _driverProfile?['rating']?.toDouble(),
        vehicleInfo: _getVehicleInfo(),
        plateNumber: _driverProfile?['plate_number'],
        driverPhotoUrl: _driverProfile?['profile_picture_url'],
        onCallDriver: _callDriver,
        onMessageDriver: _messageDriver,
        deliveryStatus: _delivery?.status,
        additionalContent: _buildAdditionalCardContent(),
      ),
    );
  }

  Widget _buildAdditionalCardContent() {
    return Column(
      children: [
        // Multi-stop progress indicator
        if (_delivery != null && _delivery!.isMultiStop && _stops.isNotEmpty) ...[
          _buildMultiStopProgress(),
          const SizedBox(height: 12),
        ],
        
        // Route information if available
        if (_routeDistanceKm != null && _routeDistanceKm! > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernColors.accentBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ModernColors.borderGrey,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.route,
                  size: 16,
                  color: ModernColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Route distance: ${_routeDistanceKm!.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: ModernColors.mediumGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Debug information (can be removed in production)
        if (_driverLocation != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ModernColors.blueVeryLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ModernColors.blueLight,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.wifi_tethering,
                      size: 14,
                      color: ModernColors.primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live Tracking Active',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ModernColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Last update: ${_formatLastUpdate()}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ModernColors.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMultiStopProgress() {
    final completedStops = _stops.where((s) => s.isCompleted).length;
    final totalStops = _stops.length;
    final currentStop = _multiStopService.getCurrentStop(_stops);
    final progress = _multiStopService.calculateProgress(_stops);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernColors.blueVeryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ModernColors.primaryBlue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route,
                size: 18,
                color: ModernColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'Multi-Stop Delivery',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ModernColors.primaryBlue,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ModernColors.primaryBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completedStops of $totalStops',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(ModernColors.primaryBlue),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          
          // Current stop info
          if (currentStop != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: ModernColors.primaryBlue,
                  child: Text(
                    '${currentStop.stopNumber}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentStop.isPickup ? 'At Pickup' : 'Stop ${currentStop.stopNumber - 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ModernColors.darkGrey,
                        ),
                      ),
                      Text(
                        currentStop.shortAddress,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ModernColors.mediumGrey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          
          // View all stops button
          const SizedBox(height: 8),
          TextButton(
            onPressed: _showAllStopsDialog,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'View all stops',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ModernColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: ModernColors.primaryBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAllStopsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Title
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.route,
                        color: ModernColors.primaryBlue,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Delivery Stops',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: ModernColors.darkGrey,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Stops list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _stops.length,
                    itemBuilder: (context, index) {
                      final stop = _stops[index];
                      final currentStop = _multiStopService.getCurrentStop(_stops);
                      return _buildStopListItem(stop, stop.id == currentStop?.id);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStopListItem(DeliveryStop stop, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? ModernColors.blueVeryLight : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? ModernColors.primaryBlue : Colors.grey[300]!,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stop number badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: stop.isCompleted
                  ? Colors.green
                  : isCurrent
                      ? ModernColors.primaryBlue
                      : Colors.grey[400],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: stop.isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      stop.isPickup ? '📦' : '${stop.stopNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Stop details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      stop.displayTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isCurrent ? ModernColors.primaryBlue : ModernColors.darkGrey,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(stop.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        stop.statusDisplayText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(stop.status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  stop.shortAddress,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ModernColors.mediumGrey,
                  ),
                ),
                if (stop.recipientName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    stop.recipientName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ModernColors.mediumGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return ModernColors.primaryBlue;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String? _getVehicleInfo() {
    final vehicleType = _driverProfile?['vehicle_types']?['name'];
    final vehicleModel = _driverProfile?['vehicle_model'];
    
    if (vehicleType != null && vehicleModel != null) {
      return '$vehicleType - $vehicleModel';
    } else if (vehicleType != null) {
      return vehicleType;
    } else if (vehicleModel != null) {
      return vehicleModel;
    }
    return null;
  }

  String _calculateArrivalTime() {
    if (_estimatedMinutes != null) {
      final now = DateTime.now();
      final arrival = now.add(Duration(minutes: _estimatedMinutes!.round()));
      return '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
    }
    return 'Calculating...';
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Need Help?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: ModernColors.darkGrey,
          ),
        ),
        content: const Text(
          'Contact our support team for assistance with your delivery.',
          style: TextStyle(
            fontSize: 14,
            color: ModernColors.mediumGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: ModernColors.mediumGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement contact support
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernColors.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Contact Support',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}