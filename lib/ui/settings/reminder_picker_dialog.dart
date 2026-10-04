import 'package:flutter/material.dart';
import '../../data/models/user_settings.dart';

/// Modal dialog for selecting class reminder pre-notification lead time (Flow 7).
/// Options:
/// - Off (null)
/// - 5 min
/// - 10 min
/// - 15 min (default)
/// - 30 min
/// - 60 min
class ReminderPickerDialog extends StatefulWidget {
  final int? currentMinutes;

  const ReminderPickerDialog({
    super.key,
    this.currentMinutes,
  });

  /// Displays the ReminderPickerDialog and returns the selected interval in minutes (or null for Off).
  static Future<int?> show(
    BuildContext context, {
    int? currentMinutes = 15,
  }) {
    return showDialog<int?>(
      context: context,
      builder: (ctx) => ReminderPickerDialog(currentMinutes: currentMinutes),
    );
  }

  @override
  State<ReminderPickerDialog> createState() => _ReminderPickerDialogState();
}

class _ReminderPickerDialogState extends State<ReminderPickerDialog> {
  int? _selectedMinutes;

  static const List<int?> _options = UserSettings.classReminderOptions;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.currentMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      title: Row(
        children: [
          Icon(
            Icons.school_outlined,
            size: 24,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            'Class reminder',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _options.map((opt) {
            final isSelected = _selectedMinutes == opt;
            final label = opt == null ? 'Off' : '$opt min before';

            return ListTile(
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              onTap: () {
                setState(() => _selectedMinutes = opt);
                Navigator.of(context).pop(opt);
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
