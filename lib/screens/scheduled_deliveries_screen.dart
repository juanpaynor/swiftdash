import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/delivery.dart';
import '../services/delivery_service.dart';
import '../constants/app_theme.dart';

class ScheduledDeliveriesScreen extends StatefulWidget {
  const ScheduledDeliveriesScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledDeliveriesScreen> createState() => _ScheduledDeliveriesScreenState();
}

class _ScheduledDeliveriesScreenState extends State<ScheduledDeliveriesScreen> {
  List<Delivery> _deliveries = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Today', 'Tomorrow', 'This Week'];

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deliveries = await DeliveryService.getScheduledDeliveries();
      setState(() {
        _deliveries = deliveries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Delivery> get _filteredDeliveries {
    if (_selectedFilter == 'All') return _deliveries;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    return _deliveries.where((delivery) {
      if (delivery.scheduledPickupTime == null) return false;

      final pickupDate = DateTime(
        delivery.scheduledPickupTime!.year,
        delivery.scheduledPickupTime!.month,
        delivery.scheduledPickupTime!.day,
      );

      switch (_selectedFilter) {
        case 'Today':
          return pickupDate == today;
        case 'Tomorrow':
          return pickupDate == tomorrow;
        case 'This Week':
          return pickupDate.isAfter(today.subtract(const Duration(days: 1))) &&
              pickupDate.isBefore(nextWeek);
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _cancelDelivery(Delivery delivery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Scheduled Delivery'),
        content: const Text(
          'Are you sure you want to cancel this scheduled delivery? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await DeliveryService.cancelScheduledDelivery(delivery.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Delivery cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDeliveries();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rescheduleDelivery(Delivery delivery) async {
    final newDateTime = await _showDateTimePicker(
      context,
      initialDateTime: delivery.scheduledPickupTime!,
    );

    if (newDateTime == null) return;

    try {
      await DeliveryService.updateScheduledTime(
        deliveryId: delivery.id,
        newScheduledTime: newDateTime,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Delivery rescheduled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDeliveries();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reschedule: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<DateTime?> _showDateTimePicker(
    BuildContext context, {
    required DateTime initialDateTime,
  }) async {
    final now = DateTime.now();
    final minDate = now.add(const Duration(hours: 1));

    // Show date picker first
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime.isAfter(minDate) ? initialDateTime : minDate,
      firstDate: minDate,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null) return null;

    // Show time picker
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null) return null;

    final newDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Validate minimum 1 hour from now
    if (newDateTime.isBefore(minDate)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup time must be at least 1 hour from now'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    return newDateTime;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Deliveries'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/location-selection'),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                
                return FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  backgroundColor: Colors.grey.shade200,
                  selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryBlue,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryBlue : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              },
            ),
          ),

          // Deliveries list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDeliveries,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading deliveries',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDeliveries,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredDeliveries = _filteredDeliveries;

    if (filteredDeliveries.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filteredDeliveries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildDeliveryCard(filteredDeliveries[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Scheduled Deliveries',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'You have no upcoming scheduled deliveries'
                : 'No deliveries scheduled for $_selectedFilter',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/location-selection'),
            icon: const Icon(Icons.add),
            label: const Text('Schedule a Delivery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(Delivery delivery) {
    final scheduledTime = delivery.scheduledPickupTime!;
    final timeUntilAssignment = DeliveryService.getTimeUntilDriverAssignment(delivery);
    final isReadyForAssignment = DeliveryService.isReadyForDriverAssignment(delivery);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with scheduled time
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: AppTheme.primaryBlue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(scheduledTime),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'at ${DateFormat('h:mm a').format(scheduledTime)}',
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isReadyForAssignment)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Ready',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (timeUntilAssignment != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(timeUntilAssignment),
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Addresses
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildAddressRow(
                  icon: Icons.circle,
                  iconColor: Colors.green,
                  label: 'Pickup',
                  address: delivery.pickupAddress,
                ),
                const SizedBox(height: 12),
                _buildAddressRow(
                  icon: Icons.location_on,
                  iconColor: Colors.red,
                  label: 'Dropoff',
                  address: delivery.deliveryAddress,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Price and actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₱${delivery.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _rescheduleDelivery(delivery),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Reschedule'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                        side: BorderSide(color: AppTheme.primaryBlue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _cancelDelivery(delivery),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
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

  Widget _buildAddressRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}
