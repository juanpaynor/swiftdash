import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_theme.dart';
import '../widgets/modern_widgets.dart';
import '../models/delivery.dart';
import '../models/vehicle_type.dart';
import '../services/delivery_service.dart';

class MatchingScreen extends StatefulWidget {
  final String deliveryId;
  
  const MatchingScreen({
    super.key,
    required this.deliveryId,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _searchController;
  
  Delivery? _delivery;
  VehicleType? _vehicleType;
  String _currentMessage = "Looking for available drivers...";
  int _searchStep = 0;
  bool _isSearching = true;
  bool _searchFailed = false;
  String? _failureReason;
  Timer? _searchTimer;
  
  // NEW: Real-time subscription and cancellation flag
  StreamSubscription<List<Map<String, dynamic>>>? _deliverySubscription;
  bool _isCancelled = false;
  
  final List<String> _searchMessages = [
    "Looking for available drivers...",
    "Checking driver locations...", 
    "Finding the best match...",
    "Contacting nearby drivers...",
    "Almost there! Finalizing match...",
  ];

  final List<String> _noDriverMessages = [
    "Expanding search radius...",
    "Checking more drivers...",
    "Looking for backup options...", 
    "Trying alternative routes...",
    "Still searching for you...",
  ];

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _searchController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _loadDeliveryDetails();
    _startDriverSearch();
    
    // Listen for delivery updates
    _listenForDriverMatch();
  }

  @override
  void dispose() {
    // Mark as cancelled to prevent any further actions
    _isCancelled = true;
    
    // Cancel all timers and subscriptions
    _pulseController.dispose();
    _searchController.dispose();
    _searchTimer?.cancel();
    _acceptanceTimeoutTimer?.cancel();
    _deliverySubscription?.cancel();
    
    super.dispose();
  }

  void _startDriverSearch() async {
    // Start the search animation
    _startSearchAnimation();
    
    try {
      debugPrint('🔍 Starting driver search for delivery: ${widget.deliveryId}');
      
      // First, let's check if we can find drivers manually
      await _debugAvailableDrivers();
      
      // Actually call the pair driver function
      final result = await DeliveryService.requestPairDriver(widget.deliveryId);
      
      debugPrint('🚗 Driver search result: $result');
      
      if (result['ok'] == true) {
        // Success - driver has been OFFERED the delivery (not yet accepted)
        debugPrint('✅ Driver offered delivery: ${result['offered_driver_id']}');
        debugPrint('📊 Found ${result['drivers_found']} drivers, closest at ${result['closest_driver_distance']}km');
        
        // Immediately update UI to show driver found, waiting for acceptance
        setState(() {
          _currentMessage = "Driver found! Waiting for acceptance...";
          _isSearching = true; // Keep search animation but change message
        });
        
        // Start 3-minute timeout for driver acceptance
        _startDriverAcceptanceTimeout();
        
        // The real-time listener will handle the final acceptance/rejection
      } else {
        // No drivers found
        debugPrint('❌ No drivers found: ${result['message']}');
        debugPrint('🔧 Full error response: $result');
        _handleSearchFailure(result['message'] ?? 'No available drivers found');
      }
    } catch (e) {
      debugPrint('💥 Driver search error: $e');
      debugPrint('🔧 Error type: ${e.runtimeType}');
      debugPrint('🔧 Error details: ${e.toString()}');
      _handleSearchFailure('Unable to find drivers at the moment. Please try again.');
    }
  }

  void _handleSearchFailure(String reason) {
    if (!mounted) return;
    
    setState(() {
      _isSearching = false;
      _searchFailed = true;
      _failureReason = reason;
      _currentMessage = "No drivers available right now";
    });
    
    _searchTimer?.cancel();
  }

  void _startSearchAnimation() {
    // Cycle through search messages
    _searchTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      // FIXED: Check if cancelled in addition to other conditions
      if (!mounted || _searchFailed || _isCancelled) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _searchStep = (_searchStep + 1) % _searchMessages.length;
        _currentMessage = _searchMessages[_searchStep];
      });
      
      // After first cycle, show "still searching" messages if no driver found
      if (_searchStep == _searchMessages.length - 1 && _isSearching && !_isCancelled) {
        // Switch to extended search messages
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _isSearching && !_searchFailed && !_isCancelled) {
            _startExtendedSearch();
          }
        });
      }
    });
  }

  void _startExtendedSearch() {
    _searchTimer?.cancel();
    int extendedStep = 0;
    
    _searchTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      // FIXED: Check if cancelled in addition to other conditions
      if (!mounted || _searchFailed || _isCancelled) {
        timer.cancel();
        return;
      }
      
      setState(() {
        extendedStep = (extendedStep + 1) % _noDriverMessages.length;
        _currentMessage = _noDriverMessages[extendedStep];
      });
      
      // Extended search now runs for 5 minutes to account for driver acceptance time
      // After 5 minutes (about 75 cycles of 4 seconds), show failure
      if (extendedStep >= 75) {
        timer.cancel();
        if (_isSearching && !_isCancelled) {
          _handleSearchFailure('No drivers available in your area right now');
        }
      }
    });
  }

  Future<void> _loadDeliveryDetails() async {
    try {
      final response = await Supabase.instance.client
          .from('deliveries')
          .select('''
            *,
            vehicle_types (*)
          ''')
          .eq('id', widget.deliveryId)
          .single();
          
      setState(() {
        _delivery = Delivery.fromJson(response);
        // Load vehicle type for price breakdown calculations
        if (response['vehicle_types'] != null) {
          _vehicleType = VehicleType.fromJson(response['vehicle_types']);
        }
      });
      
      // Debug: Check available drivers
      await _debugAvailableDrivers();
      
    } catch (e) {
      if (mounted) {
        ModernToast.error(
          context: context,
          message: 'Error loading delivery details: $e',
        );
        context.go('/home');
      }
    }
  }
  
  Future<void> _debugAvailableDrivers() async {
    try {
      debugPrint('\n🔍 === DEBUGGING DRIVER AVAILABILITY ===');
      
      // Test basic Supabase connection
      debugPrint('🔌 Testing Supabase connection...');
      try {
        // Test with a simple query to see what columns exist
        final testQuery = await Supabase.instance.client
            .from('driver_profiles')
            .select('*')
            .limit(1);
        debugPrint('✅ Supabase connection successful. Test query returned: ${testQuery.length} records');
        if (testQuery.isNotEmpty) {
          debugPrint('📋 driver_profiles columns: ${testQuery.first.keys.toList()}');
        }
      } catch (e) {
        debugPrint('❌ Supabase connection to driver_profiles failed: $e');
      }
      
      // Test driver availability query
      try {
        final availableDrivers = await Supabase.instance.client
            .from('driver_profiles')
            .select('id, is_online, is_available, current_latitude, current_longitude, location_updated_at')
            .eq('is_verified', true)
            .eq('is_online', true)
            .eq('is_available', true)
            .not('current_latitude', 'is', null)
            .not('current_longitude', 'is', null)
            .limit(5);
        debugPrint('✅ Available drivers query successful. Found: ${availableDrivers.length} drivers');
      } catch (e) {
        debugPrint('❌ Available drivers query failed: $e');
        return;
      }

      // 🚨 NEW: Show ALL drivers in database (regardless of criteria)
      debugPrint('\n🔍 === CHECKING ALL DRIVERS IN DATABASE ===');
      try {
        final allDrivers = await Supabase.instance.client
            .from('driver_profiles')
            .select('id, is_verified, is_online, is_available, current_latitude, current_longitude, location_updated_at, created_at')
            .order('created_at', ascending: false)
            .limit(10);
        
        debugPrint('📊 Total drivers in database: ${allDrivers.length}');
        
        if (allDrivers.isEmpty) {
          debugPrint('❌ NO DRIVERS EXIST IN DATABASE!');
          debugPrint('🔧 Driver app needs to create records in driver_profiles table');
        } else {
          debugPrint('📋 Driver records found:');
          for (int i = 0; i < allDrivers.length; i++) {
            final driver = allDrivers[i];
            debugPrint('   Driver ${i + 1}:');
            debugPrint('     ID: ${driver['id']}');
            debugPrint('     is_verified: ${driver['is_verified']}');
            debugPrint('     is_online: ${driver['is_online']}');
            debugPrint('     is_available: ${driver['is_available']}');
            debugPrint('     has_latitude: ${driver['current_latitude'] != null}');
            debugPrint('     has_longitude: ${driver['current_longitude'] != null}');
            debugPrint('     location_updated: ${driver['location_updated_at']}');
            debugPrint('     created: ${driver['created_at']}');
            
            // Check if this driver meets all criteria
            bool meetsAll = driver['is_verified'] == true &&
                           driver['is_online'] == true &&
                           driver['is_available'] == true &&
                           driver['current_latitude'] != null &&
                           driver['current_longitude'] != null;
            debugPrint('     ✅ Meets all criteria: $meetsAll');
            debugPrint('');
          }
        }
      } catch (e) {
        debugPrint('❌ Failed to check all drivers: $e');
      }
      
      // Check delivery details first
      if (_delivery != null) {
        debugPrint('📦 Delivery ID: ${widget.deliveryId}');
        debugPrint('📍 Pickup location: ${_delivery!.pickupLatitude}, ${_delivery!.pickupLongitude}');
        debugPrint('📦 Delivery status: ${_delivery!.status}');
        debugPrint('🚗 Current driver_id: ${_delivery!.driverId}');
      } else {
        debugPrint('❌ Delivery object is null!');
      }
      
      // Check all drivers - try different column names
      debugPrint('🔍 Attempting to discover column structure...');
      
      // Query all drivers with their current status from driver_profiles table
      final allDrivers = await Supabase.instance.client
          .from('driver_profiles')
          .select('''
            id, is_verified, is_online, is_available, 
            current_latitude, current_longitude, location_updated_at,
            rating, total_deliveries
          ''')
          .limit(20);
      
      debugPrint('👥 Total drivers in database: ${allDrivers.length}');
      
      if (allDrivers.isEmpty) {
        debugPrint('❌ NO DRIVERS FOUND IN DATABASE!');
        return;
      }
      
      // Check available drivers using actual table structure
      final availableDrivers = await Supabase.instance.client
          .from('driver_profiles')
          .select('id, is_verified, is_online, is_available, current_latitude, current_longitude, location_updated_at')
          .eq('is_verified', true)
          .eq('is_online', true)
          .eq('is_available', true)
          .not('current_latitude', 'is', null)
          .not('current_longitude', 'is', null);
      
      debugPrint('✅ Available drivers (meeting all criteria): ${availableDrivers.length}');
      
      // Test the query that should match the corrected Edge Function
      debugPrint('\n🎯 Testing corrected driver query...');
      try {
        final edgeFunctionQuery = await Supabase.instance.client
            .from('driver_profiles')
            .select('id, is_verified, is_online, is_available, current_latitude, current_longitude, location_updated_at, rating')
            .eq('is_verified', true)
            .eq('is_online', true)
            .eq('is_available', true)
            .not('current_latitude', 'is', null)
            .not('current_longitude', 'is', null)
            .order('location_updated_at', ascending: false)
            .limit(10);
        
        debugPrint('🎯 Corrected query result: ${edgeFunctionQuery.length} drivers');
        for (var driver in edgeFunctionQuery) {
          debugPrint('   ✅ Driver ${driver['id']} - Lat: ${driver['current_latitude']}, Lng: ${driver['current_longitude']}, Updated: ${driver['location_updated_at']}');
        }
      } catch (e) {
        debugPrint('❌ Corrected query failed: $e');
      }
      
      debugPrint('\n📊 DRIVER ANALYSIS:');
      int verifiedCount = 0;
      int onlineCount = 0;
      int availableCount = 0;
      int withLocationCount = 0;
      int meetingAllCriteriaCount = 0;
      
      for (var driver in allDrivers) {
        final isVerified = driver['is_verified'] == true;
        final isOnline = driver['is_online'] == true;
        final isAvailable = driver['is_available'] == true;
        final hasLatitude = driver['current_latitude'] != null;
        final hasLongitude = driver['current_longitude'] != null;
        final hasLocation = hasLatitude && hasLongitude;
        final meetsAllCriteria = isVerified && isOnline && isAvailable && hasLocation;
        
        if (isVerified) verifiedCount++;
        if (isOnline) onlineCount++;
        if (isAvailable) availableCount++;
        if (hasLocation) withLocationCount++;
        if (meetsAllCriteria) meetingAllCriteriaCount++;
        
        final readyStatus = meetsAllCriteria ? '✅ READY' : '❌ NOT READY';
        final statusText = isOnline && isAvailable ? 'ONLINE & AVAILABLE' : 
                          isOnline ? 'ONLINE BUT BUSY' :
                          isAvailable ? 'AVAILABLE BUT OFFLINE' : 'OFFLINE';
        
        debugPrint('🚗 Driver ${driver['id']}: $readyStatus');
        debugPrint('   ✅ Verified: $isVerified | Status: $statusText | Location: $hasLocation');
        if (hasLocation) {
          debugPrint('   📍 Coords: ${driver['current_latitude']}, ${driver['current_longitude']}');
          debugPrint('   ⏰ Updated: ${driver['location_updated_at']}');
        }
        debugPrint('');
      }
      
      debugPrint('📈 SUMMARY:');
      debugPrint('   👥 Total drivers: ${allDrivers.length}');
      debugPrint('   🌐 Online: $onlineCount');
      debugPrint('   ✅ Available: $availableCount');
      debugPrint('   🔐 Verified: $verifiedCount');
      debugPrint('   📍 With location: $withLocationCount');
      debugPrint('   🎯 Meeting ALL criteria: $meetingAllCriteriaCount');
      debugPrint('=== END DEBUG ===\n');
      
      if (_delivery != null) {
        debugPrint('📍 Delivery pickup location: ${_delivery!.pickupLatitude}, ${_delivery!.pickupLongitude}');
      }
      
    } catch (e) {
      debugPrint('❌ Error checking drivers: $e');
    }
  }

  void _listenForDriverMatch() {
    // Listen for real-time updates on the delivery
    _deliverySubscription = Supabase.instance.client
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('id', widget.deliveryId)
        .listen((data) {
          // FIXED: Check if cancelled before processing any updates
          if (_isCancelled || !mounted) return;
          
          if (data.isNotEmpty) {
            final delivery = Delivery.fromJson(data.first);
            
            // Handle different delivery statuses
            if (!_isCancelled) {
              if (delivery.status == 'driver_offered') {
                // Driver has been offered the delivery, show waiting message
                _onDriverOffered(delivery);
              } else if (delivery.status == 'driver_assigned') {
                // Driver has accepted the delivery!
                _onDriverMatched(delivery);
              } else if (delivery.status == 'cancelled') {
                // Delivery was cancelled
                _handleSearchFailure('Delivery was cancelled');
              }
            }
          }
        });
  }

  void _onDriverOffered(Delivery delivery) {
    // Driver has been offered the delivery, show waiting for acceptance
    if (!mounted || _isCancelled) return;
    
    setState(() {
      _currentMessage = "Driver found! Waiting for acceptance...";
      _isSearching = true; // Keep search animation but change message
    });
    
    debugPrint('📨 Driver offered delivery, waiting for acceptance: ${delivery.driverId}');
    
    // Start 3-minute timeout for driver acceptance
    _startDriverAcceptanceTimeout();
  }

  Timer? _acceptanceTimeoutTimer;
  
  void _startDriverAcceptanceTimeout() {
    _acceptanceTimeoutTimer?.cancel();
    
    // Give driver 3 minutes to accept
    _acceptanceTimeoutTimer = Timer(const Duration(minutes: 3), () {
      if (mounted && !_isCancelled && _isSearching) {
        debugPrint('⏰ Driver acceptance timeout - continuing search');
        setState(() {
          _currentMessage = "Driver didn't respond, finding another driver...";
        });
        
        // Continue searching for another driver
        _startDriverSearch();
      }
    });
  }

  void _onDriverMatched(Delivery delivery) {
    // FIXED: Double-check if cancelled or unmounted before showing dialog
    if (!mounted || _isCancelled) return;
    
    // Stop search timers and mark as successful
    _searchTimer?.cancel();
    _acceptanceTimeoutTimer?.cancel(); // Cancel acceptance timeout
    setState(() {
      _isSearching = false;
      _searchFailed = false;
    });
    
    HapticFeedback.heavyImpact();
    
    // Show success animation then navigate
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildMatchFoundDialog(delivery),
    ).then((_) {
      // FIXED: Check again before navigation
      if (!_isCancelled && mounted) {
        context.go('/tracking/${delivery.id}');
      }
    });
  }

  Widget _buildMatchFoundDialog(Delivery delivery) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radius24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowDark,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 40,
              ),
            ).animate().scale(delay: 200.milliseconds),
            
            const SizedBox(height: AppTheme.spacing20),
            
            Text(
              'Driver Found!',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ).animate(delay: 400.milliseconds).fadeIn().slideY(begin: 0.2),
            
            const SizedBox(height: AppTheme.spacing12),
            
            Text(
              'Your driver is on the way to pickup location',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 600.milliseconds).fadeIn().slideY(begin: 0.2),
            
            const SizedBox(height: AppTheme.spacing24),
            
            ModernButton(
              text: 'Track Delivery',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              icon: Icons.location_on_rounded,
            ).animate(delay: 800.milliseconds).fadeIn().slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with cancel option
              _buildHeader(),
              
              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacing20),
                  child: Column(
                    children: [
                      const SizedBox(height: AppTheme.spacing40),
                      
                      // Animated search indicator
                      _buildSearchIndicator(),
                      
                      const SizedBox(height: AppTheme.spacing40),
                      
                      // Status message
                      _buildStatusMessage(),
                      
                      const SizedBox(height: AppTheme.spacing40),
                      
                      // Search failure options
                      if (_searchFailed) _buildFailureOptions(),
                      
                      const SizedBox(height: AppTheme.spacing40),
                      
                      // Delivery summary
                      if (_delivery != null) _buildDeliverySummary(),
                      
                      const SizedBox(height: AppTheme.spacing40),
                      
                      // Tips while waiting
                      _buildWaitingTips(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing20,
        vertical: AppTheme.spacing16,
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowLight,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onPressed: () {
                // FIXED: Mark as cancelled immediately when user closes
                _isCancelled = true;
                _searchTimer?.cancel();
                _deliverySubscription?.cancel();
                
                // Show confirmation dialog
                _showCancelDialog();
              },
            ),
          ),
          
          const SizedBox(width: AppTheme.spacing16),
          
          Expanded(
            child: Text(
              'Finding Your Driver',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: -0.2).fadeIn();
  }

  Widget _buildSearchIndicator() {
    if (_searchFailed) {
      return Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.errorColor.withOpacity(0.1),
          border: Border.all(
            color: AppTheme.errorColor.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.search_off_rounded,
          color: AppTheme.errorColor,
          size: 50,
        ),
      ).animate().scale(delay: 200.milliseconds);
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.3 * _pulseController.value),
                blurRadius: 40 + (20 * _pulseController.value),
                spreadRadius: 10 * _pulseController.value,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _searchController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _searchController.value * 2 * 3.14159,
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                );
              },
            ),
          ),
        );
      },
    ).animate().scale(delay: 200.milliseconds);
  }

  Widget _buildStatusMessage() {
    return Column(
      children: [
        Text(
          _currentMessage,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _searchFailed ? AppTheme.errorColor : AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn().slideY(begin: 0.2),
        
        const SizedBox(height: AppTheme.spacing12),
        
        if (_searchFailed && _failureReason != null) ...[
          Text(
            _failureReason!,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 200.milliseconds).fadeIn(),
        ] else ...[
          Text(
            _isSearching ? 'This usually takes 1-3 minutes' : 'Please wait...',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ).animate(delay: 200.milliseconds).fadeIn(),
        ],
      ],
    );
  }

  Widget _buildDeliverySummary() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Delivery Request',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Request #${widget.deliveryId.substring(0, 8)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacing20),
          const Divider(color: AppTheme.dividerColor),
          const SizedBox(height: AppTheme.spacing16),
          
          _buildLocationRow(
            icon: Icons.radio_button_checked,
            iconColor: AppTheme.successColor,
            label: 'Pickup',
            address: _delivery!.pickupAddress,
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          _buildLocationRow(
            icon: Icons.location_on,
            iconColor: AppTheme.errorColor,
            label: 'Delivery',
            address: _delivery!.deliveryAddress,
          ),
          
          const SizedBox(height: AppTheme.spacing20),
          const Divider(color: AppTheme.dividerColor),
          const SizedBox(height: AppTheme.spacing16),
          
          // Price breakdown (matching order summary screen)
          if (_delivery!.distanceKm != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Base Fee',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '₱${_vehicleType?.basePrice.toStringAsFixed(2) ?? '0.00'}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distance (${_delivery!.distanceKm!.toStringAsFixed(1)} km)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '₱${(_vehicleType != null ? (_delivery!.distanceKm! * _vehicleType!.pricePerKm) : 0).toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'VAT (12%)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '₱${(_vehicleType != null ? _vehicleType!.calculateVAT(_delivery!.distanceKm!) : 0).toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: AppTheme.dividerColor.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Price',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${_delivery!.totalPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.successColor,
                    ),
                  ),
                  if (_vehicleType != null && _delivery!.distanceKm != null)
                    Text(
                      'Server calculated',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: AppTheme.spacing8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Text(
            address,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingTips() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _searchFailed ? Icons.info_outline : Icons.lightbulb_outline,
                color: _searchFailed ? AppTheme.infoColor : AppTheme.warningColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                _searchFailed ? 'What\'s Next?' : 'While You Wait',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          if (_searchFailed) ...[
            _buildTipItem('🔄 Try searching again in a few minutes'),
            _buildTipItem('📞 Contact support if the issue persists'),
            _buildTipItem('🚗 Drivers may be busy during peak hours'),
            _buildTipItem('📍 Check if your location is in our service area'),
          ] else ...[
            _buildTipItem('📱 You\'ll get notified when a driver accepts'),
            _buildTipItem('🚗 Driver will head to pickup location first'),
            _buildTipItem('📍 You can track the delivery in real-time'),
            _buildTipItem('💬 Contact your driver through the app'),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildFailureOptions() {
    return Column(
      children: [
        ModernCard(
          child: Column(
            children: [
              Icon(
                Icons.sentiment_dissatisfied_outlined,
                size: 48,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                'No Drivers Available',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                'All drivers in your area are currently busy. You can try again or we\'ll notify you when drivers become available.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing20),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ModernButton(
                          text: 'Try Again',
                          onPressed: _retrySearch,
                          icon: Icons.refresh_rounded,
                          isSecondary: true,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: ModernButton(
                          text: 'Cancel',
                          onPressed: () => _showCancelDialog(),
                          icon: Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  ModernButton(
                    text: 'Debug: Check Drivers',
                    onPressed: () async {
                      debugPrint('🔍 Debug button pressed!');
                      try {
                        await _debugAvailableDrivers();
                      } catch (e) {
                        debugPrint('❌ Debug button error: $e');
                      }
                    },
                    icon: Icons.bug_report,
                    isSecondary: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  void _retrySearch() {
    // Cancel any existing timers
    _searchTimer?.cancel();
    _acceptanceTimeoutTimer?.cancel();
    
    setState(() {
      _isSearching = true;
      _searchFailed = false;
      _failureReason = null;
      _searchStep = 0;
      _currentMessage = "Looking for available drivers...";
    });
    
    _startDriverSearch();
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius16),
        ),
        title: Text(
          'Cancel Request?',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel this delivery request? This action cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // FIXED: If user chooses to keep waiting, re-enable the search
              setState(() {
                _isCancelled = false;
              });
              
              // Restart the listener if it was cancelled
              if (_deliverySubscription == null) {
                _listenForDriverMatch();
              }
              
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            child: Text(
              'Keep Waiting',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ModernButton(
            text: 'Cancel Request',
            onPressed: () async {
              if (context.canPop()) {
                context.pop();
              }
              await _cancelDelivery();
            },
            isSecondary: true,
          ),
        ],
      ),
    );
  }

  Future<void> _cancelDelivery() async {
    try {
      // FIXED: Mark as cancelled first to prevent any race conditions
      setState(() {
        _isCancelled = true;
        _isSearching = false;
      });
      
      // Cancel subscriptions and timers immediately
      _searchTimer?.cancel();
      _deliverySubscription?.cancel();
      
      // Update delivery status in database
      await Supabase.instance.client
          .from('deliveries')
          .update({'status': 'cancelled'})
          .eq('id', widget.deliveryId);
          
      if (mounted) {
        ModernToast.success(
          context: context,
          message: 'Delivery request cancelled',
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ModernToast.error(
          context: context,
          message: 'Error cancelling delivery: $e',
        );
      }
    }
  }
}