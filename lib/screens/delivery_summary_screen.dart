import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_theme.dart';
import '../models/delivery.dart';
import '../models/vehicle_type.dart';
import '../widgets/modern_widgets.dart';
import '../widgets/shared_delivery_map.dart';

class DeliverySummaryScreen extends StatefulWidget {
  final Delivery delivery;
  final VehicleType vehicleType;
  final double distance;
  final double price;

  const DeliverySummaryScreen({
    super.key,
    required this.delivery,
    required this.vehicleType,
    required this.distance,
    required this.price,
  });

  @override
  State<DeliverySummaryScreen> createState() => _DeliverySummaryScreenState();
}

class _DeliverySummaryScreenState extends State<DeliverySummaryScreen> {
  final GlobalKey<State<SharedDeliveryMap>> _mapKey = GlobalKey<State<SharedDeliveryMap>>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupMapLocations();
    });
  }

  void _setupMapLocations() {
    // Map locations will be set via initial parameters
    // Since the state methods are private, we'll pass initial addresses to the widget
  }

  void _proceedToMatching() {
    HapticFeedback.lightImpact();
    context.go('/matching/${widget.delivery.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          'Delivery Summary',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacing20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Delivery confirmed section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.spacing24),
                    decoration: BoxDecoration(
                      color: AppTheme.successLight,
                      borderRadius: BorderRadius.circular(AppTheme.radius16),
                      border: Border.all(
                        color: AppTheme.successColor.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.successColor,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        Text(
                          'Delivery Confirmed!',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        Text(
                          'Your delivery has been created successfully.\nWe\'re now finding the best driver for you.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacing24),

                  // Route map
                  SharedDeliveryMap(
                    key: _mapKey,
                    initialPickupAddress: widget.delivery.pickupAddress,
                    initialDeliveryAddress: widget.delivery.deliveryAddress,
                  ),

                  const SizedBox(height: AppTheme.spacing24),

                  // Delivery details
                  _buildSectionCard(
                    title: 'Delivery Details',
                    child: Column(
                      children: [
                        _buildDetailRow(
                          icon: Icons.local_shipping,
                          iconColor: AppTheme.primaryBlue,
                          title: 'Vehicle Type',
                          value: widget.vehicleType.name,
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        _buildDetailRow(
                          icon: Icons.route,
                          iconColor: AppTheme.infoColor,
                          title: 'Distance',
                          value: '${widget.distance.toStringAsFixed(1)} km',
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        _buildDetailRow(
                          icon: Icons.schedule,
                          iconColor: AppTheme.warningColor,
                          title: 'Estimated Time',
                          value: '${(widget.distance * 3).round()}-${(widget.distance * 5).round()} mins',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacing16),

                  // Locations
                  _buildSectionCard(
                    title: 'Locations',
                    child: Column(
                      children: [
                        _buildLocationRow(
                          icon: Icons.my_location,
                          iconColor: AppTheme.successColor,
                          title: 'Pickup Location',
                          address: widget.delivery.pickupAddress,
                          contact: widget.delivery.pickupContactName,
                          phone: widget.delivery.pickupContactPhone,
                        ),
                        const SizedBox(height: AppTheme.spacing20),
                        Container(
                          height: 1,
                          color: AppTheme.dividerColor.withOpacity(0.3),
                        ),
                        const SizedBox(height: AppTheme.spacing20),
                        _buildLocationRow(
                          icon: Icons.location_on,
                          iconColor: AppTheme.errorColor,
                          title: 'Delivery Location',
                          address: widget.delivery.deliveryAddress,
                          contact: widget.delivery.deliveryContactName,
                          phone: widget.delivery.deliveryContactPhone,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacing16),

                  // Package info
                  _buildSectionCard(
                    title: 'Package Information',
                    child: Column(
                      children: [
                        _buildDetailRow(
                          icon: Icons.inventory_2,
                          iconColor: AppTheme.primaryBlue,
                          title: 'Description',
                          value: widget.delivery.packageDescription,
                        ),
                        if (widget.delivery.packageWeight != null) ...[
                          const SizedBox(height: AppTheme.spacing16),
                          _buildDetailRow(
                            icon: Icons.scale,
                            iconColor: AppTheme.infoColor,
                            title: 'Weight',
                            value: '${widget.delivery.packageWeight!.toStringAsFixed(1)} kg',
                          ),
                        ],
                        if (widget.delivery.packageValue != null) ...[
                          const SizedBox(height: AppTheme.spacing16),
                          _buildDetailRow(
                            icon: Icons.attach_money,
                            iconColor: AppTheme.warningColor,
                            title: 'Declared Value',
                            value: '₱${widget.delivery.packageValue!.toStringAsFixed(0)}',
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacing16),

                  // Price breakdown
                  _buildSectionCard(
                    title: 'Price Breakdown',
                    child: Column(
                      children: [
                        _buildPriceRow(
                          'Base Price',
                          '₱${widget.vehicleType.basePrice.toStringAsFixed(0)}',
                        ),
                        const SizedBox(height: AppTheme.spacing12),
                        _buildPriceRow(
                          'Distance (${widget.distance.toStringAsFixed(1)} km)',
                          '₱${(widget.distance * widget.vehicleType.pricePerKm).toStringAsFixed(0)}',
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        Container(
                          height: 1,
                          color: AppTheme.dividerColor.withOpacity(0.3),
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              '₱${widget.price.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacing64), // Space for button
                ],
              ),
            ),
          ),

          // Bottom action
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowLight,
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: ModernButton(
                text: 'Find Driver',
                onPressed: _proceedToMatching,
                icon: Icons.search,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: iconColor,
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
    required String contact,
    required String phone,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: iconColor,
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$contact • $phone',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}