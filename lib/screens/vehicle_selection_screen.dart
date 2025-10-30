import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../models/vehicle_type.dart';
import '../widgets/modern_widgets.dart';
import '../constants/app_theme.dart';

class VehicleSelectionScreen extends StatefulWidget {
  const VehicleSelectionScreen({super.key});

  @override
  State<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends State<VehicleSelectionScreen>
    with TickerProviderStateMixin {
  List<VehicleType> _vehicleTypes = [];
  bool _isLoading = true;
  VehicleType? _selectedVehicleType;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppTheme.animationMedium,
      vsync: this,
    );
    _loadVehicleTypes();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleTypes() async {
    try {
      final response = await Supabase.instance.client
          .from('vehicle_types')
          .select()
          .eq('is_active', true)
          .order('base_price');

      List<VehicleType> types = (response as List)
          .map((type) => VehicleType.fromJson(type))
          .toList();
      
      // Sort by price (lowest to highest)
      types.sort((a, b) => a.basePrice.compareTo(b.basePrice));
      
      setState(() {
        _vehicleTypes = types;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ModernToast.error(
          context: context,
          message: 'Error loading vehicle types: $e',
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _continueToLocationSelection() {
    if (_selectedVehicleType == null) {
      ModernToast.error(
        context: context,
        message: 'Please select a vehicle type',
      );
      return;
    }
    
    HapticFeedback.lightImpact();
    context.push('/location-selection', extra: _selectedVehicleType);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          'Choose Vehicle',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Select the perfect vehicle for your delivery',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Different vehicles have different pricing and capacity',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Vehicle list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _vehicleTypes.length,
              itemBuilder: (context, index) {
                final vehicleType = _vehicleTypes[index];
                final isSelected = _selectedVehicleType?.id == vehicleType.id;
                
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: VehicleSelectionCard(
                    vehicleType: vehicleType,
                    isSelected: isSelected,
                    onSelect: () {
                      setState(() {
                        _selectedVehicleType = vehicleType;
                      });
                      HapticFeedback.selectionClick();
                    },
                  ),
                );
              },
            ),
          ),
          
          // Continue button
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 20,
              top: 20,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedVehicleType != null ? _continueToLocationSelection : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _selectedVehicleType != null 
                      ? 'Continue with ${_selectedVehicleType!.name}'
                      : 'Select a vehicle to continue',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleSelectionCard extends StatelessWidget {
  final VehicleType vehicleType;
  final bool isSelected;
  final VoidCallback onSelect;

  const VehicleSelectionCard({
    super.key,
    required this.vehicleType,
    required this.isSelected,
    required this.onSelect,
  });

  // Helper method to get size icon based on weight capacity
  IconData _getSizeIcon() {
    if (vehicleType.maxWeightKg <= 5) return Icons.radio_button_checked;
    if (vehicleType.maxWeightKg <= 20) return Icons.circle;
    if (vehicleType.maxWeightKg <= 50) return Icons.adjust;
    return Icons.album;
  }

  // Helper method to get size label based on weight capacity
  String _getSizeLabel() {
    if (vehicleType.maxWeightKg <= 5) return 'Small';
    if (vehicleType.maxWeightKg <= 20) return 'Medium';
    if (vehicleType.maxWeightKg <= 50) return 'Large';
    return 'Extra Large';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected 
              ? vehicleType.primaryColor 
              : AppTheme.dividerColor.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected 
            ? [
                BoxShadow(
                  color: vehicleType.primaryColor.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ] 
            : [
                BoxShadow(
                  color: AppTheme.shadowLight,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Icon, Details, and Price
                Row(
                  children: [
                    // Vehicle icon
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSmallScreen ? 50 : 60,
                      height: isSmallScreen ? 50 : 60,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? vehicleType.primaryColor.withOpacity(0.15) 
                            : vehicleType.lightColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected 
                              ? vehicleType.primaryColor.withOpacity(0.4)
                              : vehicleType.primaryColor.withOpacity(0.1),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: vehicleType.primaryColor.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: isSelected ? 1.1 : 1.0,
                        child: Icon(
                          vehicleType.icon,
                          size: isSmallScreen ? 28 : 32,
                          color: isSelected 
                              ? vehicleType.primaryColor 
                              : vehicleType.primaryColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Vehicle details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            vehicleType.name,
                            style: GoogleFonts.inter(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (vehicleType.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              vehicleType.description!,
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 12 : 14,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₱${vehicleType.basePrice.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.w700,
                            color: isSelected 
                                ? vehicleType.primaryColor 
                                : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Base fare',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 10 : 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Bottom section: Vehicle specs using Wrap for responsiveness
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Weight capacity
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: vehicleType.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: vehicleType.primaryColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fitness_center,
                            size: 12,
                            color: vehicleType.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Max ${vehicleType.maxWeightKg.toInt()}kg',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: vehicleType.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Size indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getSizeIcon(),
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getSizeLabel(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: vehicleType.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Selected',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}