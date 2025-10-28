import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../models/delivery.dart';
import '../services/delivery_service.dart';

final supabase = Supabase.instance.client;

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _searchController = TextEditingController();

  List<Delivery> _allDeliveries = [];
  List<Delivery> _filteredDeliveries = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadDeliveries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _filterDeliveries();
    }
  }

  Future<void> _loadDeliveries() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final deliveries = await DeliveryService.getUserDeliveries(userId);
      if (mounted) {
        setState(() {
          _allDeliveries = deliveries;
          _filterDeliveries();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading deliveries: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _filterDeliveries() {
    setState(() {
      List<Delivery> filtered = _allDeliveries;

      // Filter by tab
      switch (_tabController.index) {
        case 1: // Active
          filtered = filtered
              .where((d) => !['delivered', 'cancelled'].contains(d.status))
              .toList();
          break;
        case 2: // Completed
          filtered =
              filtered.where((d) => d.status == 'delivered').toList();
          break;
        default: // All
          break;
      }

      // Filter by search
      if (_searchQuery.isNotEmpty) {
        filtered = filtered.where((d) {
          return d.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              d.deliveryAddress
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              d.pickupAddress.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();
      }

      // Sort by date (newest first)
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _filteredDeliveries = filtered;
    });
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
              // Gradient App Bar
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
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => context.go('/location-selection'),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Order History',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search orders...',
                            prefixIcon: ShaderMask(
                              shaderCallback: (bounds) {
                                return const LinearGradient(
                                  colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds);
                              },
                              child: const Icon(Icons.search, color: Colors.white),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: Color(0xFF6B7280)),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                      _filterDeliveries();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                            _filterDeliveries();
                          },
                        ),
                      ),
                    ),

                    // Tabs
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: const Color(0xFF2E4A9B),
                        unselectedLabelColor: Colors.white,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        tabs: const [
                          Tab(text: 'All'),
                          Tab(text: 'Active'),
                          Tab(text: 'Completed'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2E4A9B),
                          ),
                        ),
                      )
                    : _filteredDeliveries.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadDeliveries,
                            color: const Color(0xFF2E4A9B),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredDeliveries.length,
                              itemBuilder: (context, index) {
                                return _buildDeliveryCard(
                                  _filteredDeliveries[index],
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_tabController.index) {
      case 1:
        message = 'No active deliveries';
        icon = Icons.local_shipping_outlined;
        break;
      case 2:
        message = 'No completed deliveries yet';
        icon = Icons.check_circle_outline;
        break;
      default:
        message = _searchQuery.isNotEmpty
            ? 'No orders found'
            : 'No deliveries yet';
        icon = Icons.inbox_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds);
            },
            child: Icon(icon, size: 80, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(Delivery delivery) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Navigate to appropriate screen based on status
            if (delivery.status == 'delivered' || delivery.status == 'completed') {
              // Show delivery details/receipt (could add a completion screen route)
              context.go('/tracking/${delivery.id}'); // For now, go to tracking
            } else if (delivery.status == 'cancelled' || delivery.status == 'failed') {
              // Show delivery details
              context.go('/tracking/${delivery.id}');
            } else {
              // Active delivery - go to tracking screen
              context.go('/tracking/${delivery.id}');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${delivery.id.substring(0, 8)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(delivery.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(delivery.status),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),

                // Addresses
                _buildAddressRow(
                  Icons.store,
                  delivery.pickupAddress,
                  const Color(0xFF4FC3F7),
                ),
                const SizedBox(height: 8),
                _buildAddressRow(
                  Icons.home,
                  delivery.deliveryAddress,
                  const Color(0xFF10B981),
                ),

                // Multi-stop indicator
                if (delivery.stops != null && delivery.stops!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE0E7FF), Color(0xFFCFDCFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.route,
                          size: 14,
                          color: Color(0xFF2E4A9B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${delivery.stops!.length} stops',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E4A9B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Price
                if (delivery.totalPrice > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Total: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds);
                        },
                        child: Text(
                          '₱${delivery.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, String address, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF111827),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color startColor;
    Color endColor;
    String text;

    switch (status) {
      case 'delivered':
        startColor = const Color(0xFF10B981);
        endColor = const Color(0xFF059669);
        text = 'Delivered';
        break;
      case 'in_transit':
      case 'picked_up':
        startColor = const Color(0xFF1DA1F2);
        endColor = const Color(0xFF2E4A9B);
        text = 'Active';
        break;
      case 'cancelled':
        startColor = const Color(0xFFEF4444);
        endColor = const Color(0xFFDC2626);
        text = 'Cancelled';
        break;
      default:
        startColor = const Color(0xFFF59E0B);
        endColor = const Color(0xFFD97706);
        text = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final deliveryDate = DateTime(date.year, date.month, date.day);

    if (deliveryDate == today) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (deliveryDate == yesterday) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }
}
