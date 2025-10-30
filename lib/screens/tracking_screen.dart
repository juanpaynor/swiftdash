import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/customer_ably_realtime_service.dart';
import '../services/delivery_service.dart';
import '../services/multi_stop_service.dart';
import '../services/mapbox_matrix_service.dart';
import '../services/ably_service.dart';
import '../services/chat_service.dart';
import '../models/delivery.dart';
import '../models/delivery_stop.dart';
import '../models/chat_message.dart';
import '../widgets/shared_delivery_map.dart';
import '../widgets/draggable_tracking_sheet.dart';
import '../widgets/animated_status_banner.dart';
import '../widgets/modern_top_navigation.dart';
import '../constants/modern_colors.dart';
import '../utils/back_button_handler.dart';
import '../config/env.dart';

/// Uber-style tracking screen with full-screen map and floating overlay cards
/// 
/// 🔧 IMPLEMENTS ABLY REALTIME SPECIFICATIONS:
/// 1. Ably Channels: tracking:{deliveryId}
/// 2. Publishing: channel.publish('location_update', payload)
/// 3. Listening: channel.subscribe('location_update') - instant callbacks
/// 4. Presence: Driver online/offline status via presence API
/// 
/// Driver app publishes GPS via: ablyService.publishLocation(deliveryId, location)
/// Customer app listens via: ablyService.subscribeToDelivery(deliveryId)
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
  final CustomerAblyRealtimeService _realtimeService = CustomerAblyRealtimeService();
  final MultiStopService _multiStopService = MultiStopService();
  final AblyService _ablyService = AblyService();
  
  late StreamSubscription _locationSubscription;
  late StreamSubscription _driverSubscription;
  
  // Real-time status (from Ably, not database)
  String? _currentRealtimeStatus;
  
  // Chat service
  ChatService? _chatService;
  
  Delivery? _delivery;
  List<DeliveryStop> _stops = [];
  Map<String, dynamic>? _driverLocation;
  Map<String, dynamic>? _driverProfile;
  bool _isLoading = true;
  String? _error;
  String _driverStatus = 'unknown';
  bool _isDriverOnline = false;
  DateTime? _lastLocationUpdate;
  StreamSubscription? _statusUpdateSubscription;

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

      // Fetch traffic-aware route if driver is assigned
      if (delivery.status == 'driver_assigned' || 
          delivery.status == 'going_to_pickup' ||
          delivery.status == 'package_collected' ||
          delivery.status == 'in_transit') {
        _fetchTrafficAwareRoute();
      }
      
    } catch (e) {
      setState(() {
        _error = 'Failed to load delivery: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeChatService() async {
    try {
      debugPrint('💬 TrackingScreen: Initializing chat service...');
      
      // Get current user info
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ TrackingScreen: No authenticated user, skipping chat initialization');
        return;
      }

      // Get user profile for display name
      final userProfile = await Supabase.instance.client
          .from('user_profiles')
          .select('first_name, last_name')
          .eq('id', currentUser.id)
          .single();
      
      final customerName = '${userProfile['first_name']} ${userProfile['last_name']}';
      
      // Get Ably client from the service
      final ablyClient = _ablyService.realtimeClient;
      if (ablyClient == null) {
        debugPrint('⚠️ TrackingScreen: Ably client not initialized, skipping chat');
        return;
      }

      // Create ChatService instance
      _chatService = ChatService(
        ablyClient: ablyClient,
        currentUserId: currentUser.id,
        currentUserType: SenderType.customer,
        currentUserName: customerName,
      );

      // Initialize chat for this delivery
      await _chatService!.initializeChat(widget.deliveryId);
      
      debugPrint('✅ TrackingScreen: Chat service initialized successfully');
      
      // Trigger UI update to show chat tab
      setState(() {});
    } catch (e, stackTrace) {
      debugPrint('❌ TrackingScreen: Failed to initialize chat: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't fail the whole screen if chat fails
    }
  }

  Future<void> _subscribeToUpdates() async {
    if (_delivery == null) return;

    try {
      debugPrint('� TrackingScreen: Setting up Ably subscriptions for delivery: ${widget.deliveryId}');
      
      // Subscribe to delivery tracking channel
      // 🔥 CRITICAL FIX: Initialize CustomerAblyRealtimeService before subscribing
      await _realtimeService.initialize(Env.ablyClientKey);
      debugPrint('✅ TrackingScreen: CustomerAblyRealtimeService initialized');
      
      await _realtimeService.subscribeToDelivery(widget.deliveryId);
      debugPrint('✅ TrackingScreen: Ably subscription setup complete');
      
      // Initialize chat service
      await _initializeChatService();
      
      // Subscribe to Ably status updates (replaces Supabase Realtime)
      debugPrint('🔧 TrackingScreen: Setting up Ably status stream');
      
      _statusUpdateSubscription = _realtimeService.statusUpdateStream.listen(
        (statusData) {
          if (mounted) {
            debugPrint('� Ably: Status update received');
            debugPrint('📋 New status: ${statusData['status']}');
            _updateDeliveryStatus(statusData);
          }
        },
        onError: (error) {
          debugPrint('❌ Ably status subscription error: $error');
        },
      );
      
      debugPrint('✅ TrackingScreen: Ably status subscription active');
      
      // Start a timer to detect if no location updates are received
      Timer(const Duration(seconds: 30), () {
        if (mounted && _driverLocation == null && _delivery?.status == 'driver_assigned') {
          debugPrint('⚠️ No driver location updates received after 30 seconds');
          debugPrint('⚠️ This suggests the driver app is not publishing to Ably');
        }
      });
      
      // Listen to location updates
      _locationSubscription = _realtimeService.locationStream.listen(
        (locationData) {
          if (mounted) {
            debugPrint('📍 Ably: Location update received: ${locationData['latitude']}, ${locationData['longitude']}');
            
            // Convert Ably format to our internal format
            final location = {
              'deliveryId': locationData['delivery_id'],
              'latitude': locationData['latitude'],
              'longitude': locationData['longitude'],
              'timestamp': locationData['timestamp'],
              'bearing': locationData['bearing'],
              'speed': locationData['speed'],
              'accuracy': locationData['accuracy'],
              'batteryLevel': locationData['battery_level'],
            };
            
            _updateDriverLocation(location);
          }
        },
        onError: (error) {
          debugPrint('❌ Ably location subscription error: $error');
        },
      );
      
      // Listen to driver status (presence)
      _driverSubscription = _realtimeService.driverStatusStream.listen(
        (status) {
          if (mounted) {
            setState(() {
              _driverStatus = status;
            });
            debugPrint('� Ably: Driver status: $status');
          }
        },
        onError: (error) {
          debugPrint('❌ Ably driver status error: $error');
        },
      );
      
      // Check if driver is online
      final isOnline = await _realtimeService.isDriverOnline();
      if (mounted) {
        setState(() {
          _driverStatus = isOnline ? 'online' : 'offline';
        });
        debugPrint('👋 Ably: Initial driver status: $_driverStatus');
      }
      
      // Log subscription activity every 10 seconds
      Timer.periodic(const Duration(seconds: 10), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        debugPrint('📊 Ably Status Check:');
        debugPrint('   - Channel: tracking:${widget.deliveryId}');
        debugPrint('   - Driver location received: ${_driverLocation != null ? 'YES' : 'NO'}');
        debugPrint('   - Driver status: $_driverStatus');
        debugPrint('   - Delivery status: ${_delivery?.status}');
      });
    } catch (e) {
      debugPrint('Failed to subscribe to Ably updates: $e');
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
      
      debugPrint('📊 Driver profile response: $response');
      debugPrint('🖼️ Profile picture URL: ${response['profile_picture_url']}');
      
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
      debugPrint('✅ Profile picture in state: ${_driverProfile?['profile_picture_url']}');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to fetch driver profile: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      // Don't set error state, just continue without driver profile
    }
  }

  void _updateDriverLocation(Map<String, dynamic> location) {
    final now = DateTime.now();
    final timeSinceLastUpdate = _lastLocationUpdate != null 
        ? now.difference(_lastLocationUpdate!).inMilliseconds 
        : 0;
    
    debugPrint('🚗 TrackingScreen: _updateDriverLocation called (${timeSinceLastUpdate}ms since last update)');
    
    setState(() {
      _driverLocation = location;
      _lastLocationUpdate = now;
      _isDriverOnline = _driverStatus == 'online';
    });

    final lat = location['latitude']?.toDouble();
    final lng = location['longitude']?.toDouble();
    final timestamp = location['timestamp'];
    final speed = location['speed'];
    
    debugPrint('🚗 Location update: lat=$lat, lng=$lng, speed=${speed}km/h, timestamp=$timestamp');
    
    if (lat != null && lng != null) {
      debugPrint('✅ Driver location updated successfully');
      debugPrint('🗺️ Map will receive driverLatitude: $lat, driverLongitude: $lng');
      debugPrint('🗺️ Delivery coordinates - pickup: (${_delivery?.pickupLatitude}, ${_delivery?.pickupLongitude})');
      debugPrint('🗺️ Delivery coordinates - delivery: (${_delivery?.deliveryLatitude}, ${_delivery?.deliveryLongitude})');
      
      // Recalculate ETA based on current driver position
      _recalculateETA(lat, lng);
      
      // Update client-side ETA if we have a traffic route
      _updateClientSideETA(lat, lng);
      
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
    final previousStatus = _currentRealtimeStatus;
    final newStatus = deliveryData['status'];
    
    debugPrint('📊 STATUS UPDATE (Ably):');
    debugPrint('   Previous: "$previousStatus"');
    debugPrint('   New: "$newStatus"');
    debugPrint('   Stage mapping: ${_getDeliveryStage(newStatus)}');
    
    // Update real-time status (from Ably)
    setState(() {
      _currentRealtimeStatus = newStatus;
      
      // Also update delivery model for UI consistency
      if (_delivery != null) {
        _delivery = _delivery!.copyWith(
          status: newStatus,
          updatedAt: DateTime.now(), // Use current time since Ably is instant
        );
      }
    });

    // Show status update notification if status changed
    if (previousStatus != null && previousStatus != newStatus) {
      _showStatusUpdateNotification(newStatus);

      // Navigate to completion screen when delivered
      if (newStatus == 'delivered' && _delivery != null) {
        debugPrint('🎉 Delivery completed - navigating to completion screen');
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            // Use GoRouter navigation with extra parameter
            context.go('/completion', extra: _delivery);
          }
        });
        return; // Don't fetch route for completed delivery
      }

      // Fetch new traffic route when status changes to key states
      if (newStatus == 'driver_assigned' || 
          newStatus == 'going_to_pickup' ||
          newStatus == 'package_collected' ||
          newStatus == 'in_transit') {
        debugPrint('🔄 Status changed to $newStatus - fetching new traffic route');
        _fetchTrafficAwareRoute();
      }
    }
  }

  void _showStatusUpdateNotification(String newStatus) {
    final String message;
    final Color backgroundColor;
    
    // Note: Customer only sees tracking screen AFTER driver has been assigned and accepted
    // Status flow starts from 'going_to_pickup', not from 'driver_offered' or 'driver_assigned'
    switch (newStatus) {
      case 'going_to_pickup':
        message = 'Driver is heading to pickup location';
        backgroundColor = const Color(0xFF2196F3);
        break;
      case 'at_pickup':
        message = 'Driver has arrived at pickup location';
        backgroundColor = const Color(0xFF2196F3);
        break;
      case 'package_collected':
        message = 'Package collected - heading your way!';
        backgroundColor = const Color(0xFF2196F3);
        break;
      case 'in_transit':
        message = 'Driver is on the way to drop off';
        backgroundColor = const Color(0xFF2196F3);
        break;
      case 'at_destination':
        message = 'Driver has arrived at your location';
        backgroundColor = const Color(0xFF2196F3);
        break;
      case 'delivered':
        message = 'Delivery completed successfully!';
        backgroundColor = const Color(0xFF2196F3);
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
    _driverSubscription.cancel();
    _statusUpdateSubscription?.cancel(); // Cancel Ably status subscription
    _realtimeService.unsubscribe();
    _chatService?.dispose(); // Clean up chat service
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
                onPressed: () => context.go('/location-selection'),
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
            
            // Modern floating focus card (bottom) - now with animated status banner
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
    debugPrint('   - driverProfilePictureUrl: ${_driverProfile?['profile_picture_url']}');
    debugPrint('   - driverId: ${_delivery?.driverId}');
    debugPrint('   - isMultiStop: ${_delivery?.isMultiStop}');
    debugPrint('   - stopsCount: ${_stops.length}');
    
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
        // Driver profile picture for personalized marker
        driverProfilePictureUrl: _driverProfile?['profile_picture_url'],
        driverId: _delivery?.driverId,
        // Multi-stop delivery support
        isMultiStop: _delivery?.isMultiStop ?? false,
        additionalStops: _delivery?.isMultiStop == true ? _getAdditionalStopsForMap() : null,
        // Traffic-aware route segments for polyline rendering
        trafficSegments: _currentTrafficRoute?.segments.map((segment) => {
          'coordinates': segment.coordinates,
          'congestion': segment.congestion.name,
          'distance': segment.distance,
          'duration': segment.duration,
        }).toList(),
      ),
    );
  }

  // Convert DeliveryStop list to Map format for SharedDeliveryMap
  List<Map<String, dynamic>> _getAdditionalStopsForMap() {
    if (_stops.isEmpty) return [];
    
    return _stops.map((stop) => {
      'latitude': stop.latitude,
      'longitude': stop.longitude,
      'address': stop.address,
      'stopNumber': stop.stopNumber,
      'status': stop.status,
      'recipientName': stop.recipientName,
      'recipientPhone': stop.recipientPhone,
    }).toList();
  }



  // Route calculation results
  double? _routeDistanceKm;
  double? _estimatedMinutes;

  // Traffic-aware routing (Matrix API)
  TrafficAwareRoute? _currentTrafficRoute;
  String? _clientSideETA;
  DateTime? _lastMatrixApiCall;

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
      onBackPressed: () => context.go('/location-selection'),
      onHelpPressed: () => _showHelpDialog(),
    );
  }

  DeliveryStage _getDeliveryStage(String? status) {
    debugPrint('🎯 Mapping status to stage: "$status"');
    switch (status?.toLowerCase()) {
      case 'confirmed':
      case 'pending':
        return DeliveryStage.orderConfirmed;
      case 'accepted':
      case 'driver_assigned':
        return DeliveryStage.driverAssigned;
      case 'picking_up':
      case 'going_to_pickup':
        return DeliveryStage.goingToPickup;
      case 'arrived':
      case 'at_pickup':
        return DeliveryStage.atPickup;
      case 'picked_up':
      case 'package_collected':
        return DeliveryStage.packageCollected;
      case 'in_transit':
      case 'on_the_way':
      case 'delivering':
      case 'at_destination':  // Driver arrived at customer location
        return DeliveryStage.onTheWay;
      case 'delivered':
      case 'completed':
        return DeliveryStage.delivered;
      default:
        debugPrint('⚠️ Unknown status: "$status" - defaulting to orderConfirmed');
        return DeliveryStage.orderConfirmed;
    }
  }

  Widget _buildModernFloatingCard() {
    return DraggableTrackingSheet(
      delivery: _delivery!,
      isDriverOnline: _isDriverOnline,
      batteryLevel: _driverLocation?['battery_level'] as int?,
      lastUpdate: _lastLocationUpdate,
      estimatedArrival: _calculateArrivalTime(),
      driverProfile: _driverProfile,
      onCancel: _cancelDelivery,
      currentStage: _getDeliveryStage(_delivery?.status),
      chatService: _chatService,
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
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.10,
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

  void _recalculateETA(double driverLat, double driverLng) {
    if (_delivery == null) return;

    double targetLat;
    double targetLng;
    bool isToPickup;

    // Determine destination based on delivery status
    final status = _delivery!.status;
    if (status == 'driver_assigned' || status == 'going_to_pickup') {
      // Driver is heading to pickup location
      targetLat = _delivery!.pickupLatitude;
      targetLng = _delivery!.pickupLongitude;
      isToPickup = true;
    } else if (status == 'picked_up' || status == 'in_transit') {
      // Driver is heading to delivery location
      targetLat = _delivery!.deliveryLatitude;
      targetLng = _delivery!.deliveryLongitude;
      isToPickup = false;
    } else {
      // No need to calculate ETA for other statuses
      return;
    }

    // Calculate straight-line distance (Haversine formula)
    const double earthRadiusKm = 6371;
    final dLat = _degreesToRadians(targetLat - driverLat);
    final dLng = _degreesToRadians(targetLng - driverLng);
    
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degreesToRadians(driverLat)) *
            cos(_degreesToRadians(targetLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distanceKm = earthRadiusKm * c;

    // Apply road factor (straight line vs actual road distance)
    // Roads typically add 20-40% to straight-line distance
    final roadDistanceKm = distanceKm * 1.3;

    // Calculate estimated time
    const double citySpeed = 25.0; // km/h average city speed
    const double pickupTime = 3.0; // minutes for pickup
    const double deliveryTime = 2.0; // minutes for delivery
    
    final travelTimeMinutes = (roadDistanceKm / citySpeed) * 60;
    final processTime = isToPickup ? pickupTime : deliveryTime;
    final totalMinutes = travelTimeMinutes + processTime;

    setState(() {
      _estimatedMinutes = totalMinutes;
      _routeDistanceKm = roadDistanceKm;
    });

    debugPrint('⏱️ ETA Recalculated: ${totalMinutes.toStringAsFixed(1)} min (${roadDistanceKm.toStringAsFixed(2)} km)');
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _cancelDelivery() async {
    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cancelling delivery...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Call the delivery service to cancel
      await DeliveryService.cancelDelivery(widget.deliveryId);

      if (!mounted) return;
      
      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delivery cancelled successfully',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate back to location selection after a short delay
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      context.go('/location-selection');
    } catch (e) {
      if (!mounted) return;
      
      // Close loading dialog if open
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Failed to cancel delivery: ${e.toString()}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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

  // ==================== MATRIX API TRAFFIC-AWARE ROUTING ====================

  /// Fetch traffic-aware route using Matrix API
  /// Call #2: Driver assignment - multi-leg route (driver → pickup → delivery)
  /// Call #3: Pickup complete - direct route (driver → delivery)
  Future<void> _fetchTrafficAwareRoute() async {
    if (_delivery == null || _driverLocation == null) return;

    final driverLat = _driverLocation!['latitude']?.toDouble();
    final driverLng = _driverLocation!['longitude']?.toDouble();

    if (driverLat == null || driverLng == null) return;

    // Determine waypoints based on delivery status
    final List<List<double>> coordinates;
    
    final status = _delivery!.status;
    if (status == 'driver_assigned' || status == 'going_to_pickup') {
      // Call #2: Multi-leg route (driver → pickup → delivery)
      coordinates = [
        [driverLng, driverLat],
        [_delivery!.pickupLongitude, _delivery!.pickupLatitude],
        [_delivery!.deliveryLongitude, _delivery!.deliveryLatitude],
      ];
      debugPrint('🚦 Fetching Matrix API route (Call #2): driver → pickup → delivery');
    } else if (status == 'package_collected' || status == 'in_transit') {
      // Call #3: Direct route (driver → delivery)
      coordinates = [
        [driverLng, driverLat],
        [_delivery!.deliveryLongitude, _delivery!.deliveryLatitude],
      ];
      debugPrint('🚦 Fetching Matrix API route (Call #3): driver → delivery');
    } else {
      // No route needed for other statuses
      return;
    }

    try {
      final route = await MapboxMatrixService.getTrafficAwareRoute(coordinates);

      if (route != null && mounted) {
        setState(() {
          _currentTrafficRoute = route;
          _lastMatrixApiCall = DateTime.now();
          _estimatedMinutes = route.durationMinutes;
          _routeDistanceKm = route.distanceKm;
        });

        debugPrint('✅ Traffic route loaded: ${route.distanceKm.toStringAsFixed(1)}km, ${route.durationInTraffic}');
        debugPrint('📊 Heavy traffic: ${route.hasHeavyTraffic}');
      }
    } catch (e) {
      debugPrint('❌ Matrix API error: $e');
    }
  }

  /// Update client-side ETA using driver's actual GPS speed
  /// Called every GPS update (3-5 seconds) - NO API COST
  void _updateClientSideETA(double driverLat, double driverLng) {
    if (_delivery == null || _currentTrafficRoute == null) return;

    // Determine destination based on status
    double targetLat;
    double targetLng;

    final status = _delivery!.status;
    if (status == 'driver_assigned' || status == 'going_to_pickup') {
      targetLat = _delivery!.pickupLatitude;
      targetLng = _delivery!.pickupLongitude;
    } else if (status == 'package_collected' || status == 'in_transit') {
      targetLat = _delivery!.deliveryLatitude;
      targetLng = _delivery!.deliveryLongitude;
    } else {
      return;
    }

    // Calculate remaining distance
    final remainingDistance = MapboxMatrixService.getDistanceMeters(
      fromLat: driverLat,
      fromLng: driverLng,
      toLat: targetLat,
      toLng: targetLng,
    );

    // Get driver's speed from GPS (meters per second)
    final driverSpeed = (_driverLocation?['speed'] as num?)?.toDouble() ?? 0.0;

    // Calculate client-side ETA
    final etaString = MapboxMatrixService.calculateClientSideETA(
      remainingDistanceMeters: remainingDistance,
      driverSpeedMps: driverSpeed,
      fallbackDurationSeconds: _currentTrafficRoute!.totalDuration,
    );

    setState(() {
      _clientSideETA = etaString;
    });

    debugPrint('⏱️ Client-side ETA: $etaString (speed: ${driverSpeed.toStringAsFixed(1)} m/s)');
  }
}