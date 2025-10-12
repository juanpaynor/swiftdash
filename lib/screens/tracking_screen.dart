import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/realtime_service.dart';
import '../services/delivery_service.dart';
import '../models/delivery.dart';
import '../widgets/shared_delivery_map.dart';
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
  
  late StreamSubscription _locationSubscription;
  late StreamSubscription _deliverySubscription;
  late StreamSubscription _driverSubscription;
  
  Delivery? _delivery;
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

  Future<void> _cancelDelivery() async {
    // Show warning dialog first
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Cancel Delivery?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel this delivery?',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                '⚠️ Frequent cancellations may result in longer wait times for future deliveries.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Keep Delivery',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancel Delivery'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Cancel the delivery
      await DeliveryService.cancelDelivery(widget.deliveryId);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery cancelled successfully'),
            backgroundColor: Colors.orange,
          ),
        );
        
        // Navigate back to home after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            context.go('/');
          }
        });
      }
      
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel delivery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getStatusText() {
    if (_delivery == null) return 'Loading...';
    
    switch (_delivery!.status) {
      case 'pending':
        return 'Looking for a driver';
      case 'driver_offered':
        return 'Driver found - waiting for acceptance';
      case 'driver_assigned':
        return 'Driver is preparing for pickup';
      case 'going_to_pickup':
        return 'Driver is heading to pickup location';
      case 'pickup_arrived':
        return 'Driver has arrived at pickup';
      case 'package_collected':
        return 'Package collected - heading to delivery';
      case 'going_to_destination':
        return 'Driver is on the way to you';
      case 'at_destination':
        return 'Driver has arrived at your location';
      case 'in_transit':
        return 'Your delivery is on the way';
      case 'delivered':
        return 'Delivery completed successfully';
      case 'cancelled':
        return 'Delivery cancelled';
      case 'failed':
        return 'Delivery failed';
      default:
        return _delivery!.status.replaceAll('_', ' ').toUpperCase();
    }
  }

  Color _getStatusColor() {
    if (_delivery == null) return Colors.grey;
    
    switch (_delivery!.status) {
      case 'pending':
        return Colors.orange;
      case 'driver_offered':
        return Colors.amber;
      case 'driver_assigned':
      case 'going_to_pickup':
      case 'pickup_arrived':
        return Colors.blue;
      case 'package_collected':
      case 'going_to_destination':
      case 'at_destination':
      case 'in_transit':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return SmartBackHandler(
      child: Scaffold(
        body: Stack(
        children: [
          // Full-screen live map (Uber/DoorDash style)
          _buildFullScreenMap(),
          
          // Top status bar (floating over map)
          _buildTopStatusBar(),
          
          // Draggable bottom sheet (Uber-style)
          _buildDraggableBottomSheet(),
        ],
      ),
    ));
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

  // Top floating status bar
  Widget _buildTopStatusBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Back button - Fixed navigation
            GestureDetector(
              onTap: () {
                // Use go_router for proper navigation
                context.go('/');
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.arrow_back_ios_rounded, size: 16),
              ),
            ),
            const SizedBox(width: 16),
            
            // Status indicator
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getStatusColor(),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            
            // Status text
            Expanded(
              child: Text(
                _getStatusText(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
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

  // Draggable bottom sheet (Uber/DoorDash style)
  Widget _buildDraggableBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.3, // Start at 30% of screen height
      minChildSize: 0.2,     // Minimum 20% (collapsed)
      maxChildSize: 0.8,     // Maximum 80% (expanded)
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: _buildBottomSheetContent(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Bottom sheet content
  Widget _buildBottomSheetContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Delivery info header
        _buildDeliveryHeader(),
        
        const SizedBox(height: 24),
        
        // Driver info (if assigned)
        if (_delivery?.driverId != null) ...[
          _buildDriverSection(),
          const SizedBox(height: 24),
        ],
        
        // Route phase indicator (polyline visualization)
        _buildRoutePhaseIndicator(),
        
        const SizedBox(height: 24),
        
        // Live location updates debug info
        _buildLocationDebugSection(),
        
        const SizedBox(height: 24),
        
        // Delivery progress timeline
        _buildDeliveryProgress(),
        
        const SizedBox(height: 24),
        
        // Delivery details
        _buildDeliveryDetails(),
        
        const SizedBox(height: 24),
        
        // Action buttons
        _buildActionButtons(),
        
        // Add some bottom padding for safe area
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildDeliveryHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery #${widget.deliveryId.substring(0, 8)}',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _getRoutePhaseMessage(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        
        // Enhanced ETA and route info
        if (_driverLocation != null || _estimatedMinutes != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time, 
                size: 16, 
                color: _getETAColor(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _getEstimatedTime(),
                  style: TextStyle(
                    fontSize: 14,
                    color: _getETAColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          // Route distance info (if available)
          if (_routeDistanceKm != null && _routeDistanceKm! > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.route, 
                  size: 16, 
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Route distance: ${_routeDistanceKm!.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ] else if (_delivery?.status == 'driver_assigned' || _delivery?.status == 'pickup_arrived') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.orange[600]),
              const SizedBox(width: 4),
              Text(
                'Preparing for pickup...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Get appropriate color for ETA display based on delivery phase
  Color _getETAColor() {
    if (_delivery == null) return Colors.grey;
    
    switch (_delivery!.status) {
      case 'driver_assigned':
      case 'going_to_pickup':
        return Colors.blue[600]!; // Blue for pickup phase
      case 'package_collected':
      case 'going_to_destination':
      case 'in_transit':
        return Colors.purple[600]!; // Purple for delivery phase
      case 'pickup_arrived':
      case 'at_destination':
        return Colors.green[600]!; // Green for arrival
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildDriverSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Driver',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              // Driver avatar with profile picture
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue[100],
                backgroundImage: _driverProfile?['profile_picture_url'] != null 
                    ? NetworkImage(_driverProfile!['profile_picture_url']) 
                    : null,
                child: _driverProfile?['profile_picture_url'] == null 
                    ? const Icon(Icons.person, color: Colors.blue, size: 28)
                    : null,
              ),
              const SizedBox(width: 16),
              
              // Driver info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Driver name
                    Text(
                      _driverProfile?['full_name'] ?? 'Loading driver info...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Vehicle type and model
                    if (_driverProfile?['vehicle_types'] != null || _driverProfile?['vehicle_model'] != null)
                      Row(
                        children: [
                          Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_driverProfile?['vehicle_types']?['name'] ?? 'Vehicle'} ${_driverProfile?['vehicle_model'] ?? ''}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    
                    // Plate number
                    if (_driverProfile?['plate_number'] != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.confirmation_number, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _driverProfile!['plate_number'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Driver rating and deliveries
                    if (_driverProfile?['rating'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_driverProfile!['rating'].toStringAsFixed(1)} • ${_driverProfile?['total_deliveries'] ?? 0} deliveries',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_driverProfile?['is_verified'] == true) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.blue[600],
                            ),
                          ],
                        ],
                      ),
                    ],
                    
                    // Last location update
                    if (_driverLocation != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last updated: ${_formatLastUpdate()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: Icons.phone,
                    color: Colors.green,
                    onPressed: _callDriver,
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.message,
                    color: Colors.blue,
                    onPressed: _messageDriver,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildRoutePhaseIndicator() {
    if (_delivery == null) return const SizedBox.shrink();
    
    // Determine current phase
    final String currentPhase = _getCurrentRoutePhase();
    if (currentPhase == 'none') return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getPhaseBackgroundColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getPhaseBorderColor()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getPhaseIconColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getPhaseIcon(),
                  color: _getPhaseIconColor(),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPhaseTitle(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _getPhaseIconColor(),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getPhaseDescription(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Route visualization indicator
          if (_routeDistanceKm != null || _estimatedMinutes != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Polyline color indicator
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _getPolylineColor(),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Route active on map',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  if (_routeDistanceKm != null) ...[
                    Text(
                      '${_routeDistanceKm!.toStringAsFixed(1)}km',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getPhaseIconColor(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getCurrentRoutePhase() {
    if (_delivery == null) return 'none';
    
    switch (_delivery!.status) {
      case 'driver_assigned':
      case 'going_to_pickup':
        return 'driverToPickup';
      case 'package_collected':
      case 'going_to_destination':
      case 'in_transit':
        return 'pickupToDelivery';
      default:
        return 'none';
    }
  }

  Color _getPhaseBackgroundColor() {
    final phase = _getCurrentRoutePhase();
    switch (phase) {
      case 'driverToPickup':
        return Colors.blue[50]!;
      case 'pickupToDelivery':
        return Colors.purple[50]!;
      default:
        return Colors.grey[50]!;
    }
  }

  Color _getPhaseBorderColor() {
    final phase = _getCurrentRoutePhase();
    switch (phase) {
      case 'driverToPickup':
        return Colors.blue[200]!;
      case 'pickupToDelivery':
        return Colors.purple[200]!;
      default:
        return Colors.grey[200]!;
    }
  }

  Color _getPhaseIconColor() {
    final phase = _getCurrentRoutePhase();
    switch (phase) {
      case 'driverToPickup':
        return Colors.blue[600]!;
      case 'pickupToDelivery':
        return Colors.purple[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getPhaseIcon() {
    final phase = _getCurrentRoutePhase();
    switch (phase) {
      case 'driverToPickup':
        return Icons.my_location;
      case 'pickupToDelivery':
        return Icons.local_shipping;
      default:
        return Icons.route;
    }
  }

  String _getPhaseTitle() {
    final phase = _getCurrentRoutePhase();
    switch (phase) {
      case 'driverToPickup':
        return 'Phase 1: Heading to Pickup';
      case 'pickupToDelivery':
        return 'Phase 2: Delivery in Progress';
      default:
        return 'Route Planning';
    }
  }

  String _getPhaseDescription() {
    final phase = _getCurrentRoutePhase();
    switch (phase) {
      case 'driverToPickup':
        return 'Driver is traveling to collect your package';
      case 'pickupToDelivery':
        return 'Package collected, driver heading to you';
      default:
        return 'Calculating optimal route';
    }
  }

  Color _getPolylineColor() {
    final phase = _getCurrentRoutePhase();
    switch (phase) {
      case 'driverToPickup':
        return Colors.blue;
      case 'pickupToDelivery':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLocationDebugSection() {
    if (_driverLocation == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi_tethering, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Live Tracking Active',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Channel: driver-location-${widget.deliveryId}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            'Lat: ${_driverLocation!['latitude']?.toString() ?? 'N/A'}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            'Lng: ${_driverLocation!['longitude']?.toString() ?? 'N/A'}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDetails() {
    if (_delivery == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        
        // Pickup location
        _buildLocationRow(
          icon: Icons.my_location,
          iconColor: Colors.green,
          title: 'Pickup',
          address: _delivery!.pickupAddress,
        ),
        
        const SizedBox(height: 16),
        
        // Delivery location
        _buildLocationRow(
          icon: Icons.location_on,
          iconColor: Colors.red,
          title: 'Delivery',
          address: _delivery!.deliveryAddress,
        ),
      ],
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

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

  String _getRoutePhaseMessage() {
    if (_delivery == null) return '';
    
    switch (_delivery!.status) {
      case 'driver_assigned':
      case 'going_to_pickup':
        return '🚗 Driver is heading to pickup location';
      case 'package_collected':
      case 'going_to_destination':
      case 'in_transit':
        return '🚚 Driver has your package and is on the way';
      case 'pickup_arrived':
        return '📍 Driver has arrived at pickup location';
      case 'at_destination':
        return '🏁 Driver has arrived at your location';
      default:
        return _getStatusText();
    }
  }

  Widget _buildDeliveryProgress() {
    final currentStatus = _delivery?.status ?? 'pending';
    final steps = [
      {'status': 'pending', 'title': 'Order placed', 'icon': Icons.check_circle},
      {'status': 'driver_offered', 'title': 'Driver found', 'icon': Icons.search},
      {'status': 'driver_assigned', 'title': 'Driver assigned', 'icon': Icons.person},
      {'status': 'going_to_pickup', 'title': 'Heading to pickup', 'icon': Icons.directions},
      {'status': 'pickup_arrived', 'title': 'Driver at pickup', 'icon': Icons.my_location},
      {'status': 'package_collected', 'title': 'Package collected', 'icon': Icons.inventory},
      {'status': 'going_to_destination', 'title': 'On the way to you', 'icon': Icons.local_shipping},
      {'status': 'at_destination', 'title': 'Driver arrived', 'icon': Icons.location_on},
      {'status': 'delivered', 'title': 'Delivered', 'icon': Icons.check_circle_outline},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isCompleted = _isStepCompleted(step['status'] as String, currentStatus);
            final isCurrent = step['status'] == currentStatus;
            
            return _buildProgressStep(
              icon: step['icon'] as IconData,
              title: step['title'] as String,
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              isLast: index == steps.length - 1,
            );
          }).toList(),
        ],
      ),
    );
  }

  bool _isStepCompleted(String stepStatus, String currentStatus) {
    final statusOrder = [
      'pending', 'driver_offered', 'driver_assigned', 'going_to_pickup', 
      'pickup_arrived', 'package_collected', 'going_to_destination', 
      'at_destination', 'in_transit', 'delivered'
    ];
    
    final stepIndex = statusOrder.indexOf(stepStatus);
    final currentIndex = statusOrder.indexOf(currentStatus);
    
    return stepIndex <= currentIndex && stepIndex != -1 && currentIndex != -1;
  }

  Widget _buildProgressStep({
    required IconData icon,
    required String title,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted || isCurrent ? Colors.blue : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isCompleted || isCurrent ? Colors.white : Colors.grey[600],
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: isCompleted ? Colors.blue : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                color: isCompleted || isCurrent ? Colors.black87 : Colors.grey[600],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final canCancel = _delivery?.status != 'delivered' && 
                     _delivery?.status != 'cancelled' && 
                     _delivery?.status != 'failed';

    return Column(
      children: [
        // Cancel delivery button (only if not delivered/cancelled)
        if (canCancel)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _cancelDelivery,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancel Delivery',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        
        if (canCancel) const SizedBox(height: 12),
        
        // Debug: Test WebSocket Connection
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              await _realtimeService.debugWebSocketConnection();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('WebSocket connection test completed - check debug logs')),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Test WebSocket Connection',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Debug: Test Manual Broadcast
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              await _realtimeService.testBroadcastLocation(widget.deliveryId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test broadcast sent - check debug logs for results')),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.purple,
              side: const BorderSide(color: Colors.purple),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Test Manual Broadcast',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Help/Support button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support feature coming soon')),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Get Help',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}