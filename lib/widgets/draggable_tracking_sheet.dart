import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/delivery.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import 'animated_status_banner.dart';
import 'circular_progress_ring.dart';
import 'chat_modal.dart';

class DraggableTrackingSheet extends StatefulWidget {
  final Delivery delivery;
  final bool isDriverOnline;
  final int? batteryLevel;
  final DateTime? lastUpdate;
  final String? estimatedArrival;
  final Map<String, dynamic>? driverProfile;
  final VoidCallback? onCancel;
  final DeliveryStage currentStage;
  final ChatService? chatService;

  const DraggableTrackingSheet({
    super.key,
    required this.delivery,
    required this.isDriverOnline,
    this.batteryLevel,
    this.lastUpdate,
    this.estimatedArrival,
    this.driverProfile,
    this.onCancel,
    required this.currentStage,
    this.chatService,
  });

  @override
  State<DraggableTrackingSheet> createState() => _DraggableTrackingSheetState();
}

class _DraggableTrackingSheetState extends State<DraggableTrackingSheet>
    with SingleTickerProviderStateMixin {
  final DraggableScrollableController _controller =
      DraggableScrollableController();

  late TabController _tabController;
  double _currentSize = 0.3; // Collapsed state
  int _unreadCount = 0;
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    // No tabs needed anymore, but keep controller for compatibility
    _tabController = TabController(
      length: 1,
      vsync: this,
    );
    
    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _currentSize = _controller.size;
        });
      }
    });

    // Listen to chat updates
    if (widget.chatService != null) {
      widget.chatService!.messagesStream.listen((messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
          });
        }
      });

      widget.chatService!.unreadCountStream.listen((count) {
        if (mounted) {
          setState(() {
            _unreadCount = count;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: 0.35, // Collapsed
      minChildSize: 0.35,
      maxChildSize: 0.85, // Full - increased to give more space
      snap: true,
      snapSizes: const [0.35, 0.6, 0.85], // Collapsed, Half, Full
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none, // Allow overflow for circular ring
            children: [
              // Main content
              Column(
            children: [
              // Gradient handle bar
              GestureDetector(
                onTap: () {
                  if (_currentSize < 0.5) {
                    _controller.animateTo(
                      0.6,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else if (_currentSize < 0.75) {
                    _controller.animateTo(
                      0.85,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    _controller.animateTo(
                      0.35,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),

              // Status bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    // Online status
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.isDriverOnline
                              ? [
                                  const Color(0xFF10B981),
                                  const Color(0xFF059669)
                                ]
                              : [const Color(0xFF6B7280), const Color(0xFF4B5563)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.isDriverOnline ? 'Online' : 'Offline',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Battery indicator
                    if (widget.batteryLevel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _getBatteryGradient(widget.batteryLevel!),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getBatteryIcon(widget.batteryLevel!),
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.batteryLevel}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),

                    // Last update
                    if (widget.lastUpdate != null)
                      Text(
                        _getLastUpdateText(widget.lastUpdate!),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Chat and Call Action Buttons (replacing tabs)
              if (widget.driverProfile != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFE5E7EB).withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Chat button (with unread indicator)
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: 'Chat',
                          onPressed: () => _messageDriver(),
                          hasNotification: _unreadCount > 0,
                          notificationCount: _unreadCount,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Call button
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.phone_outlined,
                          label: 'Call',
                          onPressed: () => _callDriver(),
                        ),
                      ),
                    ],
                  ),
                ),

              // Content (no tabs, just details)
              Expanded(
                child: _buildDetailsTab(scrollController),
              ),
            ],
          ),
          
          // Floating circular progress ring (overlaps map and sheet)
          Positioned(
            top: -60, // Increased overlap for bigger ring
            left: MediaQuery.of(context).size.width / 2 - 110,  // Adjusted for 220px width
            child: CircularProgressRing(
              currentStage: widget.currentStage,
              size: 220,  // Increased from 180
              eta: widget.estimatedArrival,
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildDetailsTab(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Space for overlapping circular ring
        const SizedBox(height: 120),  // Increased from 100 for bigger ring
        
        // Space for circular ring (no flanking buttons)
        const SizedBox(height: 20),
        
        const SizedBox(height: 12),  // Reduced from 20
        
        // Status message
        Text(
          _getStatusMessage(widget.currentStage),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        
        const SizedBox(height: 16),  // Reduced from 24
        
        // Driver Information Section
        if (widget.driverProfile != null) ...[
          _buildDriverInfoCard(),
          const SizedBox(height: 16),
        ],
                    
                    // ETA Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E4A9B).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Estimated Arrival',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.estimatedArrival ?? 'Calculating...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Delivery info
                    _buildInfoCard(
                      'Delivery Information',
                      Icons.local_shipping,
                      [
                        _InfoRow(
                          'Order ID',
                          '#${widget.delivery.id.substring(0, 8)}',
                        ),
                        _InfoRow('Status', _getStatusText(widget.delivery.status)),
                      ],
                    ),

                    // Multi-stop progress
                    if (widget.delivery.stops != null && widget.delivery.stops!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildMultiStopProgress(),
                    ],

                    // Pickup & Delivery addresses
                    const SizedBox(height: 16),
                    _buildAddressCard(
                      'Pickup Location',
                      widget.delivery.pickupAddress,
                      Icons.store,
                      const Color(0xFF4FC3F7),
                    ),

                    const SizedBox(height: 12),
                    _buildAddressCard(
                      'Delivery Location',
                      widget.delivery.deliveryAddress,
                      Icons.home,
                      const Color(0xFF10B981),
                    ),

                    // Additional details
                    if (_currentSize > 0.5) ...[
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        'Package Details',
                        Icons.inventory_2,
                        [
                          _InfoRow(
                            'Description',
                            widget.delivery.packageDescription,
                          ),
                          if (widget.delivery.deliveryInstructions != null)
                            _InfoRow(
                              'Instructions',
                              widget.delivery.deliveryInstructions!,
                            ),
                        ],
                      ),
                    ],

                    // Cancel Button
                    if (widget.onCancel != null &&
                        widget.delivery.status != 'delivered' &&
                        widget.delivery.status != 'cancelled') ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _showCancelConfirmation(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cancel_outlined, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Cancel Delivery',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

        const SizedBox(height: 20),
      ],
    );
  }



  Widget _buildMessagePreview(ChatMessage message) {
    final isFromMe = message.senderType == SenderType.customer;
    
    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          gradient: isFromMe
              ? const LinearGradient(
                  colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isFromMe ? null : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isFromMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isFromMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: (isFromMe ? const Color(0xFF2E4A9B) : Colors.black)
                  .withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isFromMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E4A9B),
                  ),
                ),
              ),
            Text(
              message.message,
              style: TextStyle(
                fontSize: 14,
                color: isFromMe ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: isFromMe
                    ? Colors.white.withOpacity(0.7)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  void _openFullChat() {
    if (widget.chatService == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatModal(
          chatService: widget.chatService!,
          deliveryId: widget.delivery.id,
          driverName: widget.driverProfile?['full_name'] ?? 'Driver',
          driverPhotoUrl: widget.driverProfile?['profile_picture_url'],
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _buildDriverInfoCard() {
    final driver = widget.driverProfile!;
    final driverName = driver['full_name'] ?? 'Driver';
    final profilePictureUrl = driver['profile_picture_url'];
    final vehicleType = driver['vehicle_types']?['name'] ?? 'Vehicle';
    final vehicleModel = driver['vehicle_model'] ?? '';
    final licensePlate = driver['license_plate'] ?? driver['vehicle_plate'] ?? '';
    final rating = (driver['rating'] ?? 0.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),  // Increased padding
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF9FAFB), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),  // Larger radius
        border: Border.all(
          color: const Color(0xFF2E4A9B).withOpacity(0.2),
          width: 2,  // Thicker border
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E4A9B).withOpacity(0.12),  // More shadow
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Picture - Bigger
          Container(
            width: 90,  // Increased from 70
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                width: 3,
                color: Colors.white,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E4A9B).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              gradient: profilePictureUrl == null
                  ? const LinearGradient(
                      colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            child: profilePictureUrl != null
                ? ClipOval(
                    child: Image.network(
                      profilePictureUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 45,  // Larger icon
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  )
                : const Icon(
                    Icons.person,
                    size: 45,  // Larger icon
                    color: Colors.white,
                  ),
          ),
          const SizedBox(width: 20),  // More spacing

          // Driver Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Driver Name - Larger
                Text(
                  driverName,
                  style: const TextStyle(
                    fontSize: 20,  // Increased from 18
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),  // More spacing

                // Vehicle Model - PROMINENT (if available)
                if (vehicleModel.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_car,
                        size: 18,
                        color: Color(0xFF2E4A9B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vehicleModel,
                          style: const TextStyle(
                            fontSize: 16,  // Larger and bold
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                // License Plate - PROMINENT (if available)
                if (licensePlate.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFFFD700),  // Gold border
                        width: 2,
                      ),
                    ),
                    child: Text(
                      licensePlate.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Vehicle Type Badge (smaller, less prominent)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E4A9B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        vehicleType,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E4A9B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Rating
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < rating.floor()
                            ? Icons.star
                            : (index < rating ? Icons.star_half : Icons.star_border),
                        size: 14,
                        color: const Color(0xFFFBBF24),
                      );
                    }),
                    const SizedBox(width: 6),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool hasNotification = false,
    int notificationCount = 0,
  }) {
    return Container(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E4A9B),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0xFF2E4A9B).withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 20),
                if (hasNotification && notificationCount > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        notificationCount > 9 ? '9+' : notificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusMessage(DeliveryStage stage) {
    switch (stage) {
      case DeliveryStage.orderConfirmed:
        return "Your order has been confirmed";
      case DeliveryStage.driverAssigned:
        return "Driver is on the way to pickup";
      case DeliveryStage.goingToPickup:
        return "Driver heading to pickup location";
      case DeliveryStage.atPickup:
        return "Driver has arrived at pickup";
      case DeliveryStage.packageCollected:
        return "Driver has your package!";
      case DeliveryStage.onTheWay:
        return "Driver heading to you now";
      case DeliveryStage.delivered:
        return "Package delivered! Enjoy! 🎉";
    }
  }

  void _callDriver() async {
    final phoneNumber = widget.driverProfile?['phone_number'];
    if (phoneNumber != null) {
      final uri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  void _messageDriver() async {
    // Open in-app chat directly
    if (widget.chatService != null) {
      // Open full chat modal immediately
      _openFullChat();
    } else {
      // Fallback to SMS if chat not available
      final phoneNumber = widget.driverProfile?['phone_number'];
      if (phoneNumber != null) {
        final uri = Uri.parse('sms:$phoneNumber');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    }
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 12),
            Text(
              'Cancel Delivery?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this delivery? This action cannot be undone.',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'No, Keep It',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onCancel != null) {
                widget.onCancel!();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiStopProgress() {
    final stops = widget.delivery.stops ?? [];
    final completedStops =
        stops.where((s) => s.status == 'completed').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF9FAFB), Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2E4A9B).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds);
                },
                child: const Icon(
                  Icons.route,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds);
                },
                child: const Text(
                  'Multi-Stop Delivery',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$completedStops of ${stops.length} stops completed',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
              const Spacer(),
              Text(
                '${((completedStops / stops.length) * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E4A9B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completedStops / stops.length,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1DA1F2)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<_InfoRow> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        row.label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAddressCard(
    String title,
    String address,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getBatteryGradient(int level) {
    if (level > 50) {
      return [const Color(0xFF10B981), const Color(0xFF059669)];
    } else if (level > 20) {
      return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
    } else {
      return [const Color(0xFFEF4444), const Color(0xFFDC2626)];
    }
  }

  IconData _getBatteryIcon(int level) {
    if (level > 80) return Icons.battery_full;
    if (level > 50) return Icons.battery_5_bar;
    if (level > 20) return Icons.battery_3_bar;
    return Icons.battery_1_bar;
  }

  String _getLastUpdateText(DateTime lastUpdate) {
    final diff = DateTime.now().difference(lastUpdate);
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'driver_assigned':
        return 'Driver Assigned';
      case 'picked_up':
        return 'Picked Up';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

class _InfoRow {
  final String label;
  final String value;

  _InfoRow(this.label, this.value);
}
