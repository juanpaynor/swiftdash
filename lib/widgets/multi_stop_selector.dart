import 'package:flutter/material.dart';

/// Toggle widget for enabling/disabling multi-stop mode
class MultiStopSelector extends StatelessWidget {
  final bool isMultiStop;
  final ValueChanged<bool> onChanged;
  final int currentStopCount;
  final int maxStops;

  const MultiStopSelector({
    Key? key,
    required this.isMultiStop,
    required this.onChanged,
    this.currentStopCount = 0,
    this.maxStops = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => onChanged(!isMultiStop),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMultiStop
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.route,
                  color: isMultiStop
                      ? Theme.of(context).primaryColor
                      : Colors.grey[600],
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
                          'Multi-Stop Delivery',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isMultiStop
                                ? Theme.of(context).primaryColor
                                : Colors.grey[800],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isMultiStop)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isMultiStop
                          ? 'Add up to ${maxStops - currentStopCount} more stops'
                          : 'Deliver to multiple locations in one trip',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (isMultiStop && currentStopCount > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$currentStopCount ${currentStopCount == 1 ? 'stop' : 'stops'} added',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Toggle switch
              Switch(
                value: isMultiStop,
                onChanged: onChanged,
                activeColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Info banner about multi-stop pricing
class MultiStopPricingInfo extends StatelessWidget {
  final double additionalStopCharge;
  final int additionalStops;

  const MultiStopPricingInfo({
    Key? key,
    required this.additionalStopCharge,
    this.additionalStops = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multi-Stop Pricing',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  additionalStops > 0
                      ? '₱${additionalStopCharge.toStringAsFixed(0)} × $additionalStops extra ${additionalStops == 1 ? 'stop' : 'stops'} = ₱${(additionalStopCharge * additionalStops).toStringAsFixed(2)}'
                      : 'Additional ₱${additionalStopCharge.toStringAsFixed(0)} per extra stop (first stop included)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
