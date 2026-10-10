import 'package:flutter/material.dart';
import '../../core/theme/next_class_colors.dart';
import '../shared/bouncy_tap.dart';

/// Modal dialog warning before replacing existing timetable data (Flows 7 & 8).
/// Enforces:
/// - 28 dp corner radius
/// - Warning copy explaining recurring class re-alignment
class ReplaceTimetableDialog extends StatelessWidget {
  const ReplaceTimetableDialog({super.key});

  /// Displays the ReplaceTimetableDialog with 28 dp corner radius.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => const ReplaceTimetableDialog(),
    );
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
      icon: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE500),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: nc.border, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: nc.shadow,
              offset: const Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: const Icon(
          Icons.warning_amber_rounded,
          size: 28,
          color: Colors.black,
        ),
      ),
      title: Text(
        'Replace timetable?',
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w900,
          fontSize: 22,
          color: nc.textPrimary,
        ),
      ),
      content: Text(
        'Replacing your timetable will re-align all recurring classes. Continue?',
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          color: nc.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w900,
              color: nc.textPrimary,
            ),
          ),
        ),
        BouncyTap(
          onTap: () => Navigator.of(context).pop(true),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: nc.shadow,
                  offset: const Offset(2.5, 2.5),
                  blurRadius: 0,
                ),
              ],
            ),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: nc.border, width: 2.0),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Replace timetable',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
