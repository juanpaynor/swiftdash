import 'package:flutter/material.dart';
import '../models/delivery_stop.dart';

/// Card widget for displaying a single delivery stop
class StopCard extends StatelessWidget {
  final DeliveryStop stop;
  final bool isCurrentStop;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool showRemoveButton;
  final bool showStatusBadge;

  const StopCard({
    Key? key,
    required this.stop,
    this.isCurrentStop = false,
    this.onTap,
    this.onRemove,
    this.showRemoveButton = false,
    this.showStatusBadge = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isCurrentStop ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentStop
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stop number badge
              _buildStopBadge(context),
              const SizedBox(width: 12),
              
              // Stop details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stop.displayTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isCurrentStop
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                          ),
                        ),
                        if (showStatusBadge) _buildStatusBadge(context),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Address
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            stop.shortAddress,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Recipient info if available
                    if (stop.recipientName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            stop.recipientName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Phone if available
                    if (stop.recipientPhone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            stop.recipientPhone!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Notes if available
                    if (stop.deliveryNotes != null &&
                        stop.deliveryNotes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.note,
                              size: 14,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                stop.deliveryNotes!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Remove button
              if (showRemoveButton && onRemove != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.red,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopBadge(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isCurrentStop
            ? Theme.of(context).primaryColor
            : stop.isCompleted
                ? Colors.green
                : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: stop.isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : Text(
                stop.isPickup ? stop.displayIcon : '${stop.stopNumber}',
                style: TextStyle(
                  color: isCurrentStop || stop.isCompleted
                      ? Colors.white
                      : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color badgeColor;
    String badgeText;
    
    switch (stop.status) {
      case 'pending':
        badgeColor = Colors.orange;
        badgeText = 'Pending';
        break;
      case 'in_progress':
        badgeColor = Colors.blue;
        badgeText = 'In Progress';
        break;
      case 'completed':
        badgeColor = Colors.green;
        badgeText = 'Completed';
        break;
      case 'failed':
        badgeColor = Colors.red;
        badgeText = 'Failed';
        break;
      default:
        badgeColor = Colors.grey;
        badgeText = stop.status;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }
}
