import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/delivery.dart';
import '../models/vehicle_type.dart';
import '../services/realtime_service.dart';
import '../services/delivery_service.dart';

/// State provider for tracking screen with optimized real-time updates
class TrackingStateProvider extends ChangeNotifier {
  final String deliveryId;
  final CustomerRealtimeService _realtimeService = CustomerRealtimeService();
  
  // Subscriptions for cleanup
  StreamSubscription? _locationSubscription;
  StreamSubscription? _deliverySubscription;
  StreamSubscription? _driverSubscription;
  
  // State variables
  Delivery? _delivery;
  Map<String, dynamic>? _driverLocation;
  Map<String, dynamic>? _driverProfile;
  bool _isLoading = true;
  String? _error;
  double? _routeDistanceKm;
  double? _estimatedMinutes;

  // Getters
  Delivery? get delivery => _delivery;
  Map<String, dynamic>? get driverLocation => _driverLocation;
  Map<String, dynamic>? get driverProfile => _driverProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double? get routeDistanceKm => _routeDistanceKm;
  double? get estimatedMinutes => _estimatedMinutes;
  
  // Computed properties
  String? get driverName => _driverProfile?['first_name'] != null && _driverProfile?['last_name'] != null
      ? '${_driverProfile!['first_name']} ${_driverProfile!['last_name']}'
      : null;
  
  String? get driverVehicleType => _driverProfile?['vehicle_type'];
  String? get driverVehicleModel => _driverProfile?['vehicle_model'];
  String? get driverPlateNumber => _driverProfile?['plate_number'];
  String? get driverProfilePictureUrl => _driverProfile?['profile_picture_url'];
  double? get driverRating => _driverProfile?['rating']?.toDouble();

  TrackingStateProvider({required this.deliveryId});

  /// Initialize tracking state and subscriptions
  Future<void> initialize() async {
    await _loadDeliveryAndSubscribe();
  }

  /// Load delivery data and setup real-time subscriptions
  Future<void> _loadDeliveryAndSubscribe() async {
    _setLoading(true);

    try {
      // Load delivery details
      final delivery = await DeliveryService.getDeliveryById(deliveryId);
      if (delivery == null) {
        _setError('Delivery not found');
        return;
      }

      _delivery = delivery;

      // Load driver profile if assigned
      if (delivery.driverId != null) {
        await _fetchDriverProfile(delivery.driverId!);
        _setupDriverLocationSubscription();
        _setupDriverStatusSubscription(delivery.driverId!);
      }

      // Setup delivery status subscription
      _setupDeliverySubscription();
      
      _clearError();
    } catch (e) {
      _setError('Failed to load delivery: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch driver profile information
  Future<void> _fetchDriverProfile(String driverId) async {
    try {
      final response = await Supabase.instance.client
          .from('driver_profiles')
          .select()
          .eq('driver_id', driverId)
          .maybeSingle();

      if (response != null) {
        _driverProfile = response;
      }
    } catch (e) {
      debugPrint('Failed to fetch driver profile: $e');
    }
  }

  /// Setup real-time driver location subscription
  void _setupDriverLocationSubscription() {
    _locationSubscription = _realtimeService
        .driverLocationUpdates
        .listen(
          (location) {
            _driverLocation = location;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Driver location subscription error: $error');
          },
        );

    // Subscribe to broadcast channel
    _realtimeService.subscribeToDriverLocation(deliveryId);
  }

  /// Setup delivery status subscription
  void _setupDeliverySubscription() {
    _deliverySubscription = _realtimeService
        .deliveryUpdates
        .listen(
          (deliveryData) {
            // Convert map to Delivery object if needed
            if (deliveryData['id'] == deliveryId) {
              // Update delivery data - you may need to convert this properly
              // _delivery = Delivery.fromMap(deliveryData);
              
              notifyListeners();
            }
          },
          onError: (error) {
            debugPrint('Delivery subscription error: $error');
          },
        );

    // Subscribe to delivery updates
    _realtimeService.subscribeToDelivery(deliveryId);
  }

  /// Setup driver status subscription
  void _setupDriverStatusSubscription(String driverId) {
    _driverSubscription = _realtimeService
        .driverStatusUpdates
        .listen(
          (driverData) {
            // Update driver profile with latest data
            if (driverData['driver_id'] == driverId) {
              _driverProfile = {...?_driverProfile, ...driverData};
              notifyListeners();
            }
          },
          onError: (error) {
            debugPrint('Driver status subscription error: $error');
          },
        );

    // Subscribe to driver status updates
    _realtimeService.subscribeToDriverStatus(driverId);
  }

  /// Update route calculation data
  void onRouteCalculated(double distanceKm, double estimatedMinutes) {
    _routeDistanceKm = distanceKm;
    _estimatedMinutes = estimatedMinutes;
    notifyListeners();
  }

  /// Cleanup subscriptions and resources
  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  void _cleanup() {
    _locationSubscription?.cancel();
    _deliverySubscription?.cancel();
    _driverSubscription?.cancel();
    _realtimeService.unsubscribeFromDriverLocation(deliveryId);
    _realtimeService.unsubscribeFromDelivery(deliveryId);
    if (_delivery?.driverId != null) {
      _realtimeService.unsubscribeFromDriverStatus(_delivery!.driverId!);
    }
  }

  // Utility methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}

/// Provider for delivery creation flow state
class DeliveryCreationProvider extends ChangeNotifier {
  VehicleType? _selectedVehicleType;
  String? _pickupAddress;
  double? _pickupLatitude;
  double? _pickupLongitude;
  String? _deliveryAddress;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  double? _distance;
  double? _price;
  bool _isCalculating = false;

  // Getters
  VehicleType? get selectedVehicleType => _selectedVehicleType;
  String? get pickupAddress => _pickupAddress;
  double? get pickupLatitude => _pickupLatitude;
  double? get pickupLongitude => _pickupLongitude;
  String? get deliveryAddress => _deliveryAddress;
  double? get deliveryLatitude => _deliveryLatitude;
  double? get deliveryLongitude => _deliveryLongitude;
  double? get distance => _distance;
  double? get price => _price;
  bool get isCalculating => _isCalculating;
  
  bool get canProceedToLocation => _selectedVehicleType != null;
  bool get canProceedToSummary => 
      _pickupAddress != null && 
      _deliveryAddress != null && 
      _pickupLatitude != null && 
      _pickupLongitude != null && 
      _deliveryLatitude != null && 
      _deliveryLongitude != null;

  /// Set selected vehicle type
  void setVehicleType(VehicleType vehicleType) {
    _selectedVehicleType = vehicleType;
    notifyListeners();
  }

  /// Set pickup location
  void setPickupLocation(String address, double latitude, double longitude) {
    _pickupAddress = address;
    _pickupLatitude = latitude;
    _pickupLongitude = longitude;
    _recalculateIfNeeded();
  }

  /// Set delivery location
  void setDeliveryLocation(String address, double latitude, double longitude) {
    _deliveryAddress = address;
    _deliveryLatitude = latitude;
    _deliveryLongitude = longitude;
    _recalculateIfNeeded();
  }

  /// Recalculate distance and price if both locations are set
  void _recalculateIfNeeded() {
    if (canProceedToSummary && !_isCalculating) {
      _calculateDistanceAndPrice();
    }
  }

  /// Calculate distance and price
  Future<void> _calculateDistanceAndPrice() async {
    _isCalculating = true;
    notifyListeners();

    try {
      // Calculate distance using your existing service
      // This is a placeholder - implement actual calculation
      _distance = 5.2; // km
      _price = _selectedVehicleType?.basePrice ?? 0.0 + (_distance! * 1.5);
    } catch (e) {
      debugPrint('Failed to calculate distance and price: $e');
    } finally {
      _isCalculating = false;
      notifyListeners();
    }
  }

  /// Clear all state
  void clear() {
    _selectedVehicleType = null;
    _pickupAddress = null;
    _pickupLatitude = null;
    _pickupLongitude = null;
    _deliveryAddress = null;
    _deliveryLatitude = null;
    _deliveryLongitude = null;
    _distance = null;
    _price = null;
    _isCalculating = false;
    notifyListeners();
  }
}