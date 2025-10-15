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
  
  // Main delivery contact
  final _mainContactNameController = TextEditingController();
  final _mainContactPhoneController = TextEditingController();
  
  // Additional stops contacts
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
    _mainContactNameController.dispose();
    _mainContactPhoneController.dispose();
    
    for (var controllers in _stopControllers) {
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
      'mainContact': {
        'name': _mainContactNameController.text.trim(),
        'phone': _mainContactPhoneController.text.trim(),
      },
    };

    // Add additional stops contacts if multi-stop
    if (_isMultiStop) {
      final List<Map<String, String>> stopsContacts = [];
      for (int i = 0; i < _stopControllers.length; i++) {
        stopsContacts.add({
          'name': _stopControllers[i]['name']!.text.trim(),
          'phone': _stopControllers[i]['phone']!.text.trim(),
        });
      }
      contactData['stopsContacts'] = stopsContacts;
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
                      'Who will receive the delivery?',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Enter contact information for each delivery stop',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Main Delivery Contact
                    _buildContactSection(
                      title: _isMultiStop ? 'Stop 1 - Main Delivery' : 'Delivery Contact',
                      address: widget.locationData['deliveryAddress'] ?? '',
                      nameController: _mainContactNameController,
                      phoneController: _mainContactPhoneController,
                      isFirst: true,
                    ),
                    
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
