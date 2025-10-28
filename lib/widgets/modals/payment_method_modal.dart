import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

/// Payment method selection modal - Angkas style
class PaymentMethodModal extends StatefulWidget {
  final String? initialMethod; // 'cash' or 'maya'
  final String? initialPaymentBy; // 'sender' or 'recipient'

  const PaymentMethodModal({
    Key? key,
    this.initialMethod,
    this.initialPaymentBy,
  }) : super(key: key);

  @override
  State<PaymentMethodModal> createState() => _PaymentMethodModalState();
}

class _PaymentMethodModalState extends State<PaymentMethodModal>
    with SingleTickerProviderStateMixin {
  late String _selectedMethod;
  late String _selectedPaymentBy;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  
  // Package details controllers
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  
  // Tip amount
  double _tipAmount = 0.0;
  final TextEditingController _customTipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.initialMethod ?? 'cash';
    _selectedPaymentBy = widget.initialPaymentBy ?? 'sender';

    // Animation setup (400ms slide-up)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _weightController.dispose();
    _valueController.dispose();
    _customTipController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final result = {
      'paymentMethod': _selectedMethod,
      'paymentBy': _selectedPaymentBy,
      'packageDescription': _descriptionController.text.isNotEmpty 
          ? _descriptionController.text 
          : 'Package delivery',
      'packageWeightKg': _weightController.text.isNotEmpty 
          ? double.tryParse(_weightController.text) 
          : null,
      'packageValue': _valueController.text.isNotEmpty 
          ? double.tryParse(_valueController.text) 
          : null,
      'tipAmount': _tipAmount,
    };
    print('💳 Payment modal confirming with result: $result');
    
    // Animate out then close
    _animationController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  void _closeModal() {
    _animationController.reverse().then((_) {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Package Details Section
                      const Text(
                        'Package Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPackageDetailsFields(),
                      const SizedBox(height: 24),
                      
                      // Who Pays Section
                      const Text(
                        'Who pays for this delivery?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildWhoPayOptions(),
                      const SizedBox(height: 24),
                      
                      // Payment Method Section
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentOption(
                        method: 'cash',
                        icon: Icons.payments_outlined,
                        title: 'Cash',
                        subtitle: _selectedPaymentBy == 'sender' 
                            ? 'Pay driver at pickup'
                            : 'Recipient pays driver at delivery',
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentOption(
                        method: 'maya',
                        icon: Icons.credit_card_outlined,
                        title: 'Card Payment',
                        subtitle: 'Coming soon',
                        isDisabled: true,
                      ),
                      const SizedBox(height: 24),
                      
                      // Tip Section
                      const Text(
                        'Add a tip for the driver (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTipOptions(),
                      const SizedBox(height: 24),
                      
                      _buildConfirmButton(),
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
      height: 64,
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          const Center(
            child: Text(
              'Payment & Delivery',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textInverse,
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: AppTheme.textInverse),
              onPressed: _closeModal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageDetailsFields() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // Description field
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Package description',
              hintText: 'e.g., Documents, Food, Electronics',
              prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppTheme.primaryBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          
          // Weight and Value row
          Row(
            children: [
              // Weight field
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Weight (kg)',
                    hintText: 'Optional',
                    prefixIcon: const Icon(Icons.scale_outlined, color: AppTheme.primaryBlue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Value field
              Expanded(
                child: TextField(
                  controller: _valueController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Value (₱)',
                    hintText: 'Optional',
                    prefixIcon: const Icon(Icons.attach_money, color: AppTheme.primaryBlue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhoPayOptions() {
    return Column(
      children: [
        _buildWhoPayOption(
          value: 'sender',
          title: 'I will pay (Sender)',
          subtitle: 'Pay for the delivery yourself',
        ),
        const SizedBox(height: 12),
        _buildWhoPayOption(
          value: 'recipient',
          title: 'Recipient will pay (COD)',
          subtitle: 'Recipient pays cash on delivery',
        ),
      ],
    );
  }

  Widget _buildWhoPayOption({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedPaymentBy == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentBy = value;
          // Force cash if recipient pays
          if (value == 'recipient') {
            _selectedMethod = 'cash';
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withOpacity(0.1)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.borderColor,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color:
                  isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String method,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    bool isDisabled = false,
  }) {
    final isSelected = _selectedMethod == method && !isDisabled;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: isDisabled ? null : () => setState(() => _selectedMethod = method),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.accentGradient : null,
            color: isSelected ? null : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.transparent : AppTheme.borderColor,
              width: isSelected ? 0 : 1,
            ),
            boxShadow: isSelected ? AppTheme.cardShadow : null,
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.textInverse.withOpacity(0.2)
                      : AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppTheme.textInverse : AppTheme.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppTheme.textInverse : AppTheme.textPrimary,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.textInverse.withOpacity(0.2)
                                  : AppTheme.successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.textInverse
                                    : AppTheme.successColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? AppTheme.textInverse.withOpacity(0.8)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Checkmark
              if (isSelected && !isDisabled)
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppTheme.textInverse,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppTheme.primaryBlue,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipOptions() {
    final tipAmounts = [0.0, 20.0, 50.0, 100.0];
    
    return Column(
      children: [
        // Preset tip amounts
        Row(
          children: tipAmounts.map((amount) {
            final isSelected = _tipAmount == amount && _customTipController.text.isEmpty;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: amount == tipAmounts.last ? 0 : 8,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _tipAmount = amount;
                      _customTipController.clear();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppTheme.accentGradient : null,
                      color: isSelected ? null : AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : AppTheme.borderColor,
                        width: isSelected ? 0 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        amount == 0 ? 'No tip' : '₱${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppTheme.textInverse : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        
        // Custom tip amount
        TextField(
          controller: _customTipController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Custom tip amount',
            hintText: 'Enter custom amount',
            prefixText: '₱ ',
            prefixIcon: Icon(
              Icons.volunteer_activism_outlined,
              color: _customTipController.text.isNotEmpty 
                  ? AppTheme.primaryBlue 
                  : AppTheme.textSecondary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (value) {
            setState(() {
              final customAmount = double.tryParse(value);
              if (customAmount != null && customAmount > 0) {
                _tipAmount = customAmount;
              } else {
                _tipAmount = 0.0;
              }
            });
          },
        ),
        
        // Tip summary
        if (_tipAmount > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.successColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.thumb_up_outlined,
                  color: AppTheme.successColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You\'re adding ₱${_tipAmount.toStringAsFixed(2)} tip for the driver',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.successColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.buttonShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onConfirm,
          borderRadius: BorderRadius.circular(12),
          child: const Center(
            child: Text(
              'Confirm',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textInverse,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Show payment method modal
Future<Map<String, dynamic>?> showPaymentMethodModal({
  required BuildContext context,
  String? initialMethod,
  String? initialPaymentBy,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    builder: (context) {
      return PaymentMethodModal(
        initialMethod: initialMethod,
        initialPaymentBy: initialPaymentBy,
      );
    },
  );
}
