import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../models/vehicle_type.dart';

class DeliveryContactsScreen extends StatefulWidget {
  final VehicleType selectedVehicleType;
  final Map<String, dynamic> locationData;

  const DeliveryContactsScreen({
    super.key,
    required this.selectedVehicleType,
    required this.locationData,
  });

  @override
  State<DeliveryContactsScreen> createState() => _DeliveryContactsScreenState();
}

class _DeliveryContactsScreenState extends State<DeliveryContactsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Pickup contact
  final _pickupContactNameController = TextEditingController();
  final _pickupContactPhoneController = TextEditingController();
  final _pickupInstructionsController = TextEditingController();
  
  // Main delivery contact
  final _deliveryContactNameController = TextEditingController();
  final _deliveryContactPhoneController = TextEditingController();
  final _deliveryInstructionsController = TextEditingController();
  
  // Additional stops contacts (for multi-stop)
  final List<Map<String, TextEditingController>> _stopControllers = [];
  
  bool get _isMultiStop => widget.locationData['isMultiStop'] == true;
  List<dynamic> get _additionalStops => widget.locationData['stops'] ?? [];

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers for each additional stop
    for (int i = 0; i < _additionalStops.length; i++) {
      _stopControllers.add({
        'name': TextEditingController(),
        'phone': TextEditingController(),
      });
    }
  }

  @override
  void dispose() {
    _pickupContactNameController.dispose();
    _pickupContactPhoneController.dispose();
    _pickupInstructionsController.dispose();
    _deliveryContactNameController.dispose();
    _deliveryContactPhoneController.dispose();
    _deliveryInstructionsController.dispose();
    
    for (final controllers in _stopControllers) {
      controllers['name']?.dispose();
      controllers['phone']?.dispose();
    }
    
    super.dispose();
  }

  void _continueToSummary() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all contact details'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();

    // Build contact data
    final Map<String, dynamic> contactData = {
      'pickupContact': {
        'name': _pickupContactNameController.text.trim(),
        'phone': _pickupContactPhoneController.text.trim(),
        'instructions': _pickupInstructionsController.text.trim(),
      },
      'deliveryContact': {
        'name': _deliveryContactNameController.text.trim(),
        'phone': _deliveryContactPhoneController.text.trim(),
        'instructions': _deliveryInstructionsController.text.trim(),
      },
    };

    // Add additional stops contacts if multi-stop
    if (_isMultiStop) {
      final List<Map<String, String>> additionalStops = [];
      for (int i = 0; i < _stopControllers.length; i++) {
        additionalStops.add({
          'name': _stopControllers[i]['name']!.text.trim(),
          'phone': _stopControllers[i]['phone']!.text.trim(),
        });
      }
      contactData['additional_stops'] = additionalStops;
    }

    // Navigate to order summary with all data
    context.push(
      '/order-summary',
      extra: {
        'selectedVehicleType': widget.selectedVehicleType,
        'locationData': widget.locationData,
        'contactData': contactData,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Contact Details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Contact Information',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Enter pickup and delivery contact information',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Pickup Contact Section
                    _buildPickupContactSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Delivery Contact Section  
                    _buildDeliveryContactSection(),
                    
                    // Additional Stops
                    if (_isMultiStop) ...[
                      for (int i = 0; i < _additionalStops.length; i++) ...[
                        const SizedBox(height: 24),
                        _buildContactSection(
                          title: 'Stop ${i + 2}',
                          address: _additionalStops[i]['address'] ?? '',
                          nameController: _stopControllers[i]['name']!,
                          phoneController: _stopControllers[i]['phone']!,
                          isFirst: false,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            
            // Bottom Continue Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _continueToSummary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Continue to Summary',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupContactSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.upload_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup Contact',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.locationData['pickupAddress'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Contact Name
          Text(
            'Contact Name',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _pickupContactNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Enter pickup contact name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.orange, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter pickup contact name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Contact Phone
          Text(
            'Contact Phone',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _pickupContactPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '09XX XXX XXXX',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.orange, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter pickup contact phone';
              }
              // Basic Philippine phone number validation
              final phoneRegex = RegExp(r'^(09|\+639)\d{9}$');
              if (!phoneRegex.hasMatch(value.replaceAll(' ', '').replaceAll('-', ''))) {
                return 'Invalid phone number format';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Pickup Instructions (Optional)
          Text(
            'Pickup Instructions (Optional)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _pickupInstructionsController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g., Ring bell twice, Gate code: 1234, etc.',
              prefixIcon: const Icon(Icons.notes_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.orange, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryContactSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.download_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Contact',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.locationData['deliveryAddress'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Recipient Name
          Text(
            'Recipient Name',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _deliveryContactNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Enter recipient name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter recipient name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Recipient Phone
          Text(
            'Recipient Phone',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _deliveryContactPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '09XX XXX XXXX',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter recipient phone number';
              }
              // Basic Philippine phone number validation
              final phoneRegex = RegExp(r'^(09|\+639)\d{9}$');
              if (!phoneRegex.hasMatch(value.replaceAll(' ', '').replaceAll('-', ''))) {
                return 'Invalid phone number format';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Delivery Instructions (Optional)
          Text(
            'Delivery Instructions (Optional)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _deliveryInstructionsController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g., Leave at door, Call on arrival, etc.',
              prefixIcon: const Icon(Icons.notes_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection({
    required String title,
    required String address,
    required TextEditingController nameController,
    required TextEditingController phoneController,
    required bool isFirst,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isFirst ? AppTheme.primaryBlue.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFirst ? AppTheme.primaryBlue.withOpacity(0.2) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFirst ? AppTheme.primaryBlue : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
                child: Text(
                  title.split(' ')[1].replaceAll('-', ''),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Recipient Name
          Text(
            'Recipient Name',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Enter recipient name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter recipient name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Recipient Phone
          Text(
            'Recipient Phone',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '09XX XXX XXXX',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter phone number';
              }
              // Basic Philippine phone number validation
              final phoneRegex = RegExp(r'^(09|\+639)\d{9}$');
              if (!phoneRegex.hasMatch(value.replaceAll(' ', '').replaceAll('-', ''))) {
                return 'Invalid phone number format';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
