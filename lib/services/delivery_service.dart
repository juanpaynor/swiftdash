import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery.dart';
import '../models/vehicle_type.dart';
import '../models/delivery_stop.dart';
import 'multi_stop_service.dart';

class DeliveryService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final MultiStopService _multiStopService = MultiStopService();

  // Get a server-calculated quote from the Edge Function
  static Future<Map<String, dynamic>> getQuote({
    required String vehicleTypeId,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    double? weightKg,
    double? surge,
  }) async {
    final res = await _supabase.functions.invoke('quote', body: {
      'vehicleTypeId': vehicleTypeId,
      'pickup': {'lat': pickupLat, 'lng': pickupLng},
      'dropoff': {'lat': dropoffLat, 'lng': dropoffLng},
      if (weightKg != null) 'weightKg': weightKg,
      if (surge != null) 'surge': surge,
    });
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    return Map<String, dynamic>.from(data as dynamic);
  }

  // Get all vehicle types
  static Future<List<VehicleType>> getVehicleTypes() async {
    final response = await _supabase
        .from('vehicle_types')
        .select()
        .eq('is_active', true)
        .order('base_price');

    return (response as List)
        .map((type) => VehicleType.fromJson(type))
        .toList();
  }

  // Create a new delivery
  static Future<Delivery> createDelivery(Map<String, dynamic> deliveryData) async {
    final response = await _supabase
        .from('deliveries')
        .insert(deliveryData)
        .select()
        .single();

    return Delivery.fromJson(response);
  }

  // Create delivery via Edge Function (trusted pricing and atomic insert)
  static Future<Delivery> bookDeliveryViaFunction({
    required String vehicleTypeId,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String pickupContactName,
    required String pickupContactPhone,
    String? pickupInstructions,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffContactName,
    required String dropoffContactPhone,
    String? dropoffInstructions,
    String? packageDescription,
    double? packageWeightKg,
    double? packageValue,
    // Payment information
    String? paymentBy,
    String? paymentMethod,
    String? paymentStatus,
    String? mayaCheckoutId,
    String? mayaPaymentId,
    String? paymentReference,
    Map<String, dynamic>? paymentMetadata,
  }) async {
    final res = await _supabase.functions.invoke('book_delivery', body: {
      'vehicleTypeId': vehicleTypeId,
      'pickup': {
        'address': pickupAddress,
        'location': {'lat': pickupLat, 'lng': pickupLng},
        'contactName': pickupContactName,
        'contactPhone': pickupContactPhone,
        if (pickupInstructions != null) 'instructions': pickupInstructions,
      },
      'dropoff': {
        'address': dropoffAddress,
        'location': {'lat': dropoffLat, 'lng': dropoffLng},
        'contactName': dropoffContactName,
        'contactPhone': dropoffContactPhone,
        if (dropoffInstructions != null) 'instructions': dropoffInstructions,
      },
      'package': {
        if (packageDescription != null) 'description': packageDescription,
        if (packageWeightKg != null) 'weightKg': packageWeightKg,
        if (packageValue != null) 'value': packageValue,
      },
      // Payment information
      if (paymentBy != null) 'payment': {
        'paymentBy': paymentBy,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'mayaCheckoutId': mayaCheckoutId,
        'mayaPaymentId': mayaPaymentId,
        'paymentReference': paymentReference,
        'paymentMetadata': paymentMetadata,
      },
    });

    final data = res.data as Map<String, dynamic>;
    return Delivery.fromJson(data);
  }

  // Create delivery with payment information directly
  static Future<Delivery> createDeliveryWithPayment({
    required String vehicleTypeId,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String pickupContactName,
    required String pickupContactPhone,
    String? pickupInstructions,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffContactName,
    required String dropoffContactPhone,
    String? dropoffInstructions,
    String? packageDescription,
    double? packageWeightKg,
    double? packageValue,
    required double totalPrice,
    // Scheduling
    bool isScheduled = false,
    DateTime? scheduledPickupTime,
    // Payment information
    required String paymentBy,
    required String paymentMethod,
    required String paymentStatus,
    String? mayaCheckoutId,
    String? mayaPaymentId,
    String? paymentReference,
    String? paymentErrorMessage,
    Map<String, dynamic>? paymentMetadata,
  }) async {
    final deliveryData = {
      'vehicle_type_id': vehicleTypeId,
      'pickup_address': pickupAddress,
      'pickup_latitude': pickupLat,
      'pickup_longitude': pickupLng,
      'pickup_contact_name': pickupContactName,
      'pickup_contact_phone': pickupContactPhone,
      if (pickupInstructions != null) 'pickup_instructions': pickupInstructions,
      'delivery_address': dropoffAddress,
      'delivery_latitude': dropoffLat,
      'delivery_longitude': dropoffLng,
      'delivery_contact_name': dropoffContactName,
      'delivery_contact_phone': dropoffContactPhone,
      if (dropoffInstructions != null) 'delivery_instructions': dropoffInstructions,
      'package_description': packageDescription ?? 'Package delivery',
      if (packageWeightKg != null) 'package_weight': packageWeightKg,
      if (packageValue != null) 'package_value': packageValue,
      'total_price': totalPrice,
      'status': 'pending',
      // Scheduling fields
      'is_scheduled': isScheduled,
      if (scheduledPickupTime != null) 'scheduled_pickup_time': scheduledPickupTime.toIso8601String(),
      // Payment fields
      'payment_by': paymentBy,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      if (mayaCheckoutId != null) 'maya_checkout_id': mayaCheckoutId,
      if (mayaPaymentId != null) 'maya_payment_id': mayaPaymentId,
      if (paymentReference != null) 'payment_reference': paymentReference,
      if (paymentErrorMessage != null) 'payment_error_message': paymentErrorMessage,
      if (paymentMetadata != null) 'payment_metadata': paymentMetadata,
      if (paymentStatus == 'paid') 'payment_processed_at': DateTime.now().toIso8601String(),
    };

    return createDelivery(deliveryData);
  }

  // Create multi-stop delivery with automatic route optimization
  static Future<Delivery> createMultiStopDelivery({
    required String vehicleTypeId,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String pickupContactName,
    required String pickupContactPhone,
    String? pickupInstructions,
    required List<Map<String, dynamic>> dropoffStops, // List of stop data
    String? packageDescription,
    double? packageWeightKg,
    double? packageValue,
    required double totalPrice,
    // Scheduling
    bool isScheduled = false,
    DateTime? scheduledPickupTime,
    // Payment information
    required String paymentBy,
    required String paymentMethod,
    required String paymentStatus,
    String? mayaCheckoutId,
    String? mayaPaymentId,
    String? paymentReference,
    String? paymentErrorMessage,
    Map<String, dynamic>? paymentMetadata,
  }) async {
    // Optimize route first
    final dropoffLocations = dropoffStops.map((stop) => {
      'lat': stop['latitude'] as double,
      'lng': stop['longitude'] as double,
    }).toList();

    final optimizationResult = await _multiStopService.optimizeRoute(
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLocations: dropoffLocations,
    );

    List<int>? optimizedOrder;
    if (optimizationResult['success'] == true) {
      optimizedOrder = (optimizationResult['optimizedOrder'] as List).cast<int>();
    }

    // Create delivery record
    final deliveryData = {
      'vehicle_type_id': vehicleTypeId,
      'pickup_address': pickupAddress,
      'pickup_latitude': pickupLat,
      'pickup_longitude': pickupLng,
      'pickup_contact_name': pickupContactName,
      'pickup_contact_phone': pickupContactPhone,
      if (pickupInstructions != null) 'pickup_instructions': pickupInstructions,
      // Use first stop for delivery_address fields (for backward compatibility)
      'delivery_address': dropoffStops.first['address'],
      'delivery_latitude': dropoffStops.first['latitude'],
      'delivery_longitude': dropoffStops.first['longitude'],
      // For multi-stop, use generic contact info (specific contact per stop will be in delivery_stops table)
      'delivery_contact_name': dropoffStops.first['recipientName'] ?? 'Multiple recipients',
      'delivery_contact_phone': dropoffStops.first['recipientPhone'] ?? '',
      'package_description': packageDescription ?? 'Package delivery',
      if (packageWeightKg != null) 'package_weight': packageWeightKg,
      if (packageValue != null) 'package_value': packageValue,
      'total_price': totalPrice,
      'status': 'pending',
      // Multi-stop fields
      'is_multi_stop': true,
      'total_stops': dropoffStops.length + 1, // +1 for pickup
      'current_stop_index': 0,
      // Scheduling fields
      'is_scheduled': isScheduled,
      if (scheduledPickupTime != null) 'scheduled_pickup_time': scheduledPickupTime.toIso8601String(),
      // Payment fields
      'payment_by': paymentBy,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      if (mayaCheckoutId != null) 'maya_checkout_id': mayaCheckoutId,
      if (mayaPaymentId != null) 'maya_payment_id': mayaPaymentId,
      if (paymentReference != null) 'payment_reference': paymentReference,
      if (paymentErrorMessage != null) 'payment_error_message': paymentErrorMessage,
      if (paymentMetadata != null) 'payment_metadata': paymentMetadata,
      if (paymentStatus == 'paid') 'payment_processed_at': DateTime.now().toIso8601String(),
    };

    final delivery = await createDelivery(deliveryData);

    // Create stops
    final pickupData = {
      'address': pickupAddress,
      'latitude': pickupLat,
      'longitude': pickupLng,
      'contactName': pickupContactName,
      'contactPhone': pickupContactPhone,
      'instructions': pickupInstructions,
    };

    await _multiStopService.createStops(
      deliveryId: delivery.id,
      pickupData: pickupData,
      dropoffData: dropoffStops,
      optimizedOrder: optimizedOrder,
    );

    return delivery;
  }

  static Future<Map<String, dynamic>> requestPairDriver(String deliveryId) async {
    final res = await _supabase.functions.invoke('pair_driver', body: {
      'deliveryId': deliveryId,
    });
    return (res.data as Map<String, dynamic>);
  }

  // Get user's deliveries (excluding cancelled ones for recent activity)
  static Future<List<Delivery>> getUserDeliveries(String userId, {bool excludeCancelled = true}) async {
    var query = _supabase
        .from('deliveries')
        .select()
        .eq('customer_id', userId);
    
    if (excludeCancelled) {
      query = query.neq('status', 'cancelled');
    }
    
    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((delivery) => Delivery.fromJson(delivery))
        .toList();
  }

  // Get delivery by ID
  static Future<Delivery?> getDeliveryById(String deliveryId) async {
    final response = await _supabase
        .from('deliveries')
        .select()
        .eq('id', deliveryId)
        .maybeSingle();

    return response != null ? Delivery.fromJson(response) : null;
  }

  // Update delivery status
  static Future<Delivery> updateDeliveryStatus(String deliveryId, String status) async {
    final response = await _supabase
        .from('deliveries')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', deliveryId)
        .select()
        .single();

    return Delivery.fromJson(response);
  }

  // Cancel delivery
  static Future<void> cancelDelivery(String deliveryId) async {
    await _supabase
        .from('deliveries')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String()
        })
        .eq('id', deliveryId);
  }

  // Delete delivery completely
  static Future<void> deleteDelivery(String deliveryId) async {
    await _supabase
        .from('deliveries')
        .delete()
        .eq('id', deliveryId);
  }

  // Rate delivery
  static Future<void> rateDelivery(String deliveryId, int rating) async {
    await _supabase
        .from('deliveries')
        .update({
          'customer_rating': rating,
          'updated_at': DateTime.now().toIso8601String()
        })
        .eq('id', deliveryId);
  }

  // Driver location tracking integration
  // Driver location tracking integration
  // NOTE: The realtime schema now uses `driver_current_status` table for lightweight
  // driver status and last-known location. Update queries/subscriptions to use it.
  static Future<Map<String, dynamic>?> getDriverLocation(String driverId) async {
    final response = await _supabase
        .from('driver_current_status')
        .select('current_latitude, current_longitude, last_updated, status, battery_level, app_version, device_info, current_delivery_id')
        .eq('driver_id', driverId)
        .maybeSingle();

    return response;
  }

  // Stream delivery updates (real-time)
  static Stream<Delivery> streamDeliveryUpdates(String deliveryId) {
    return _supabase
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('id', deliveryId)
        .map((data) => Delivery.fromJson(data.first));
  }

  // Stream driver location updates for active delivery
  static Stream<Map<String, dynamic>?> streamDriverLocation(String driverId) {
    // Stream the lightweight driver_current_status row for live updates.
  return _supabase
    .from('driver_current_status:driver_id=eq.$driverId')
    .stream(primaryKey: ['driver_id'])
    .map((data) => data.isNotEmpty ? data.first : null);
  }

  // Get active deliveries count (for analytics)
  static Future<int> getActiveDeliveriesCount() async {
    final response = await _supabase
        .from('deliveries')
        .select('id')
        .inFilter('status', ['pending', 'driver_assigned', 'pickup_arrived', 'package_collected', 'in_transit']);

    return (response as List).length;
  }

  // Multi-stop delivery methods
  
  /// Get all stops for a multi-stop delivery
  static Future<List<DeliveryStop>> getDeliveryStops(String deliveryId) async {
    return await _multiStopService.getStops(deliveryId);
  }

  /// Get current stop for a multi-stop delivery
  static Future<DeliveryStop?> getCurrentStop(String deliveryId) async {
    final stops = await _multiStopService.getStops(deliveryId);
    return _multiStopService.getCurrentStop(stops);
  }

  /// Update stop status (for driver app or internal use)
  static Future<DeliveryStop> updateStopStatus({
    required String stopId,
    required String status,
    DateTime? arrivedAt,
    DateTime? completedAt,
    String? proofPhotoUrl,
    String? signatureUrl,
    String? completionNotes,
  }) async {
    return await _multiStopService.updateStopStatus(
      stopId: stopId,
      status: status,
      arrivedAt: arrivedAt,
      completedAt: completedAt,
      proofPhotoUrl: proofPhotoUrl,
      signatureUrl: signatureUrl,
      completionNotes: completionNotes,
    );
  }

  /// Update delivery's current stop index
  static Future<void> updateCurrentStopIndex(String deliveryId, int currentStopIndex) async {
    await _supabase
        .from('deliveries')
        .update({
          'current_stop_index': currentStopIndex,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', deliveryId);
  }

  /// Stream stops updates for real-time tracking
  static Stream<List<DeliveryStop>> streamDeliveryStops(String deliveryId) {
    return _supabase
        .from('delivery_stops')
        .stream(primaryKey: ['id'])
        .eq('delivery_id', deliveryId)
        .order('stop_number')
        .map((data) => data.map((json) => DeliveryStop.fromJson(json)).toList());
  }

  // Scheduled Delivery Management

  /// Get scheduled deliveries for current user
  /// Returns list of pending scheduled deliveries (no driver assigned yet)
  static Future<List<Delivery>> getScheduledDeliveries({
    bool upcomingOnly = true,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    
    final response = await _supabase
        .from('deliveries')
        .select()
        .eq('customer_id', userId)
        .eq('is_scheduled', true)
        .eq('status', 'pending') // Only pending (no driver assigned)
        .order('scheduled_pickup_time', ascending: true);
    
    var deliveries = (response as List)
        .map((json) => Delivery.fromJson(json))
        .toList();
    
    // Filter upcoming only if requested
    if (upcomingOnly) {
      final now = DateTime.now();
      deliveries = deliveries.where((d) {
        return d.scheduledPickupTime != null && d.scheduledPickupTime!.isAfter(now);
      }).toList();
    }
    
    return deliveries;
  }

  /// Cancel a scheduled delivery (before driver assignment)
  /// Throws exception if delivery cannot be cancelled
  static Future<void> cancelScheduledDelivery(String deliveryId) async {
    // Verify it's still pending and scheduled
    final delivery = await getDeliveryById(deliveryId);
    
    if (delivery == null) {
      throw Exception('Delivery not found');
    }
    
    if (!delivery.isScheduled) {
      throw Exception('Not a scheduled delivery');
    }
    
    if (delivery.driverId != null) {
      throw Exception('Cannot cancel - driver already assigned');
    }
    
    if (delivery.status != 'pending') {
      throw Exception('Delivery is no longer pending');
    }
    
    // Update status to cancelled
    await _supabase
        .from('deliveries')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', deliveryId);
  }

  /// Update scheduled pickup time (before driver assignment)
  /// Validates new time is at least 1 hour from now
  static Future<void> updateScheduledTime({
    required String deliveryId,
    required DateTime newScheduledTime,
  }) async {
    // Verify it's still pending and scheduled
    final delivery = await getDeliveryById(deliveryId);
    
    if (delivery == null) {
      throw Exception('Delivery not found');
    }
    
    if (!delivery.isScheduled) {
      throw Exception('Not a scheduled delivery');
    }
    
    if (delivery.driverId != null) {
      throw Exception('Cannot reschedule - driver already assigned');
    }
    
    if (delivery.status != 'pending') {
      throw Exception('Delivery is no longer pending');
    }
    
    // Validate new time is at least 1 hour from now
    final minTime = DateTime.now().add(const Duration(hours: 1));
    if (newScheduledTime.isBefore(minTime)) {
      throw Exception('New time must be at least 1 hour from now');
    }
    
    // Update scheduled time
    await _supabase
        .from('deliveries')
        .update({
          'scheduled_pickup_time': newScheduledTime.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', deliveryId);
  }

  /// Check if a scheduled delivery is ready for driver assignment
  /// Returns true if within 15 minutes of scheduled pickup time
  static bool isReadyForDriverAssignment(Delivery delivery) {
    if (!delivery.isScheduled || delivery.scheduledPickupTime == null) {
      return false;
    }
    
    final now = DateTime.now();
    final fifteenMinutesBeforePickup = delivery.scheduledPickupTime!.subtract(const Duration(minutes: 15));
    
    return now.isAfter(fifteenMinutesBeforePickup) || now.isAtSameMomentAs(fifteenMinutesBeforePickup);
  }

  /// Get time remaining until driver assignment for scheduled delivery
  /// Returns Duration, or null if not scheduled or already past assignment time
  static Duration? getTimeUntilDriverAssignment(Delivery delivery) {
    if (!delivery.isScheduled || delivery.scheduledPickupTime == null) {
      return null;
    }
    
    final now = DateTime.now();
    final fifteenMinutesBeforePickup = delivery.scheduledPickupTime!.subtract(const Duration(minutes: 15));
    
    if (now.isAfter(fifteenMinutesBeforePickup)) {
      return null; // Already past assignment time
    }
    
    return fifteenMinutesBeforePickup.difference(now);
  }
}