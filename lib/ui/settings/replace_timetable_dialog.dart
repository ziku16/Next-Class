import 'package:flutter/material.dart';

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
    return AlertDialog(
      backgroundColor: const Color(0xFFFAF6EE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black, width: 3.5),
      ),
      icon: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE500),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black, width: 2.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(2, 2),
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
      title: const Text(
        'Replace timetable?',
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w900,
          fontSize: 22,
          color: Colors.black,
        ),
      ),
      content: const Text(
        'Replacing your timetable will re-align all recurring classes. Continue?',
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: Offset(2.5, 2.5),
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
                side: const BorderSide(color: Colors.black, width: 2.0),
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
      ],
    );
  }
}
