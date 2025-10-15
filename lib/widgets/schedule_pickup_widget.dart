import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';

class SchedulePickupWidget extends StatefulWidget {
  final bool isScheduled;
  final DateTime? scheduledTime;
  final ValueChanged<bool> onScheduleToggled;
  final ValueChanged<DateTime?> onScheduledTimeChanged;

  const SchedulePickupWidget({
    Key? key,
    required this.isScheduled,
    this.scheduledTime,
    required this.onScheduleToggled,
    required this.onScheduledTimeChanged,
  }) : super(key: key);

  @override
  State<SchedulePickupWidget> createState() => _SchedulePickupWidgetState();
}

class _SchedulePickupWidgetState extends State<SchedulePickupWidget> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Schedule Pickup',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: widget.isScheduled,
                  onChanged: (value) {
                    widget.onScheduleToggled(value);
                    if (!value) {
                      widget.onScheduledTimeChanged(null);
                    }
                  },
                  activeColor: AppTheme.primaryBlue,
                ),
              ],
            ),
            
            if (widget.isScheduled) ...[
              const SizedBox(height: 16),
              _buildScheduleInfo(),
              const SizedBox(height: 12),
              _buildTimePicker(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Driver will be assigned 15 minutes before your scheduled pickup time',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker() {
    final now = DateTime.now();
    final minTime = now.add(const Duration(hours: 1)); // Minimum 1 hour from now
    final selectedTime = widget.scheduledTime ?? minTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Date & Time',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        
        // Date and Time Display with Edit Button
        InkWell(
          onTap: () => _showDateTimePicker(context, selectedTime, minTime),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(selectedTime),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('h:mm a').format(selectedTime),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.edit_calendar,
                  color: AppTheme.primaryBlue,
                ),
              ],
            ),
          ),
        ),
        
        // Quick time slots
        const SizedBox(height: 12),
        Text(
          'Quick Select',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        _buildQuickTimeSlots(now),
      ],
    );
  }

  Widget _buildQuickTimeSlots(DateTime now) {
    final slots = [
      {'label': '1 hour', 'duration': const Duration(hours: 1)},
      {'label': '2 hours', 'duration': const Duration(hours: 2)},
      {'label': '4 hours', 'duration': const Duration(hours: 4)},
      {'label': 'Tomorrow', 'duration': const Duration(days: 1)},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final time = now.add(slot['duration'] as Duration);
        final isSelected = widget.scheduledTime != null &&
            widget.scheduledTime!.difference(now).abs() <
                const Duration(minutes: 5) &&
            widget.scheduledTime!.isAfter(time.subtract(const Duration(minutes: 5)));

        return InkWell(
          onTap: () {
            widget.onScheduledTimeChanged(time);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade300,
              ),
            ),
            child: Text(
              slot['label'] as String,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showDateTimePicker(
    BuildContext context,
    DateTime selectedTime,
    DateTime minTime,
  ) async {
    // First, show date picker
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: selectedTime.isAfter(minTime) ? selectedTime : minTime,
      firstDate: minTime,
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null) return;

    // Then show time picker
    if (context.mounted) {
      final selectedTimeOfDay = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedTime),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppTheme.primaryBlue,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: AppTheme.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (selectedTimeOfDay == null) return;

      // Combine date and time
      final newDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTimeOfDay.hour,
        selectedTimeOfDay.minute,
      );

      // Validate that the selected time is at least 1 hour from now
      if (newDateTime.isBefore(minTime)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please select a time at least 1 hour from now',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      widget.onScheduledTimeChanged(newDateTime);
    }
  }
}

class SchedulePickupInfo extends StatelessWidget {
  final DateTime scheduledTime;

  const SchedulePickupInfo({
    Key? key,
    required this.scheduledTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            color: Colors.amber.shade900,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scheduled Pickup',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMM d at h:mm a').format(scheduledTime),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Driver will be assigned 15 minutes before',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.amber.shade800,
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
