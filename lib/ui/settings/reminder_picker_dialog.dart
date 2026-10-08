import 'package:flutter/material.dart';
import '../../core/theme/next_class_colors.dart';
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
    final nc = context.ncColors;

    return AlertDialog(
      backgroundColor: nc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: nc.border, width: 3.5),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5500),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: nc.border, width: 1.5),
            ),
            child: const Icon(
              Icons.school_outlined,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Class reminder',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: nc.textPrimary,
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _options.map((opt) {
            final isSelected = _selectedMinutes == opt;
            final label = opt == null ? 'Off' : '$opt min before';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFE500) : nc.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: nc.border,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: nc.shadow,
                      offset: isSelected ? const Offset(2, 2) : const Offset(1.5, 1.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? Colors.black : nc.icon,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        color: isSelected ? Colors.black : nc.textPrimary,
                      ),
                    ),
                    onTap: () {
                      setState(() => _selectedMinutes = opt);
                      Navigator.of(context).pop(opt);
                    },
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w900,
              color: nc.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
