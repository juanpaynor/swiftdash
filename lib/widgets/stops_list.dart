import 'package:flutter/material.dart';
import '../models/delivery_stop.dart';
import 'stop_card.dart';

/// List widget for displaying and managing multiple delivery stops
class StopsList extends StatelessWidget {
  final List<DeliveryStop> stops;
  final DeliveryStop? currentStop;
  final Function(int oldIndex, int newIndex)? onReorder;
  final Function(DeliveryStop)? onStopTap;
  final Function(DeliveryStop)? onRemoveStop;
  final bool allowReorder;
  final bool showRemoveButtons;
  final bool showStatusBadges;

  const StopsList({
    Key? key,
    required this.stops,
    this.currentStop,
    this.onReorder,
    this.onStopTap,
    this.onRemoveStop,
    this.allowReorder = false,
    this.showRemoveButtons = false,
    this.showStatusBadges = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No stops added yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (allowReorder && onReorder != null) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stops.length,
        onReorder: onReorder!,
        proxyDecorator: (child, index, animation) {
          return Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final stop = stops[index];
          final isCurrentStop = currentStop?.id == stop.id;
          
          return _buildStopItem(
            key: ValueKey(stop.id ?? index),
            stop: stop,
            index: index,
            isCurrentStop: isCurrentStop,
            showDragHandle: true,
          );
        },
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final stop = stops[index];
        final isCurrentStop = currentStop?.id == stop.id;
        
        return _buildStopItem(
          stop: stop,
          index: index,
          isCurrentStop: isCurrentStop,
          showDragHandle: false,
        );
      },
    );
  }

  Widget _buildStopItem({
    Key? key,
    required DeliveryStop stop,
    required int index,
    required bool isCurrentStop,
    required bool showDragHandle,
  }) {
    return Container(
      key: key,
      child: Row(
        children: [
          // Drag handle for reordering
          if (showDragHandle)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle,
                  color: Colors.grey[400],
                ),
              ),
            ),
          
          // Stop card
          Expanded(
            child: StopCard(
              stop: stop,
              isCurrentStop: isCurrentStop,
              onTap: onStopTap != null ? () => onStopTap!(stop) : null,
              onRemove: showRemoveButtons && onRemoveStop != null && !stop.isPickup
                  ? () => onRemoveStop!(stop)
                  : null,
              showRemoveButton: showRemoveButtons && !stop.isPickup,
              showStatusBadge: showStatusBadges,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact stops summary widget for displaying stop count
class StopsSummary extends StatelessWidget {
  final int totalStops;
  final int completedStops;
  final VoidCallback? onTap;

  const StopsSummary({
    Key? key,
    required this.totalStops,
    required this.completedStops,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          children: [
            Icon(
              Icons.route,
              color: Colors.blue[700],
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Multi-Stop Delivery',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completedStops of $totalStops stops completed',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
            // Progress indicator
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                children: [
                  CircularProgressIndicator(
                    value: totalStops > 0 ? completedStops / totalStops : 0,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue[700]!,
                    ),
                    strokeWidth: 4,
                  ),
                  Center(
                    child: Text(
                      '${((completedStops / totalStops) * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: Colors.blue[700],
              ),
          ],
        ),
      ),
    );
  }
}
