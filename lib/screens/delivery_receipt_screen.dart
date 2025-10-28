import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/delivery.dart';

class DeliveryReceiptScreen extends StatelessWidget {
  final Delivery delivery;

  const DeliveryReceiptScreen({
    super.key,
    required this.delivery,
  });

  String _generateReceiptText() {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════');
    buffer.writeln('      SWIFTDASH RECEIPT');
    buffer.writeln('═══════════════════════════\n');
    
    buffer.writeln('Order ID: #${delivery.id.substring(0, 8)}');
    buffer.writeln('Date: ${DateFormat('MMM dd, yyyy h:mm a').format(delivery.createdAt)}\n');
    
    buffer.writeln('PICKUP:');
    buffer.writeln(delivery.pickupAddress);
    buffer.writeln();
    
    buffer.writeln('DELIVERY:');
    buffer.writeln(delivery.deliveryAddress);
    
    if (delivery.stops != null && delivery.stops!.isNotEmpty) {
      buffer.writeln('\nADDITIONAL STOPS: ${delivery.stops!.length}');
    }
    
    buffer.writeln('\n───────────────────────────');
    buffer.writeln('TOTAL:           ₱${delivery.totalPrice.toStringAsFixed(2)}');
    
    if (delivery.status == 'delivered') {
      buffer.writeln('\n✓ Delivered on ${DateFormat('MMM dd, yyyy h:mm a').format(delivery.completedAt!)}');
      buffer.writeln('Received by: ${delivery.deliveryContactName}');
    }
    
    buffer.writeln('\n═══════════════════════════');
    buffer.writeln('Thank you for using SwiftDash!');
    
    return buffer.toString();
  }

  void _shareReceipt() {
    Share.share(_generateReceiptText(), subject: 'SwiftDash Delivery Receipt');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF9FAFB), Color(0xFFE0E7FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Gradient header
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x332E4A9B),
                      blurRadius: 15,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Receipt',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white),
                        onPressed: _shareReceipt,
                        tooltip: 'Share Receipt',
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Receipt card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header with logo
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.receipt_long,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'SWIFTDASH',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Delivery Receipt',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '#${delivery.id.substring(0, 8)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date
                                  _buildInfoRow(
                                    Icons.calendar_today,
                                    'Order Date',
                                    DateFormat('MMM dd, yyyy • h:mm a')
                                        .format(delivery.createdAt),
                                  ),
                                  const SizedBox(height: 16),

                                  if (delivery.status == 'delivered' &&
                                      delivery.completedAt != null) ...[
                                    _buildInfoRow(
                                      Icons.check_circle,
                                      'Delivered',
                                      DateFormat('MMM dd, yyyy • h:mm a')
                                          .format(delivery.completedAt!),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  const Divider(),
                                  const SizedBox(height: 16),

                                  // Addresses
                                  ShaderMask(
                                    shaderCallback: (bounds) {
                                      return const LinearGradient(
                                        colors: [
                                          Color(0xFF2E4A9B),
                                          Color(0xFF1DA1F2)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ).createShader(bounds);
                                    },
                                    child: const Text(
                                      'ROUTE',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  _buildAddressSection(
                                    'Pickup Location',
                                    delivery.pickupAddress,
                                    Icons.store,
                                    const Color(0xFF4FC3F7),
                                  ),
                                  const SizedBox(height: 16),

                                  _buildAddressSection(
                                    'Delivery Location',
                                    delivery.deliveryAddress,
                                    Icons.home,
                                    const Color(0xFF10B981),
                                  ),

                                  if (delivery.stops != null && delivery.stops!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFE0E7FF),
                                            Color(0xFFCFDCFE)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.route,
                                            size: 18,
                                            color: Color(0xFF2E4A9B),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${delivery.stops!.length} additional stop${delivery.stops!.length > 1 ? 's' : ''}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2E4A9B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 24),

                                  // Total
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF2E4A9B),
                                          Color(0xFF1DA1F2)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'TOTAL',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        Text(
                                          '₱${delivery.totalPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Delivery confirmation
                                  if (delivery.status == 'delivered') ...[
                                    const SizedBox(height: 24),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF10B981),
                                          width: 2,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF10B981),
                                            size: 32,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Delivery Confirmed',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Received by: ${delivery.deliveryContactName}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Footer
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Thank you for using SwiftDash!',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Share button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E4A9B).withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _shareReceipt,
                          icon: const Icon(Icons.share, color: Colors.white),
                          label: const Text(
                            'Share Receipt',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection(
    String label,
    String address,
    IconData icon,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}

