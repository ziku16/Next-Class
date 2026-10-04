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
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      icon: Icon(
        Icons.warning_amber_rounded,
        size: 32,
        color: theme.colorScheme.tertiary,
      ),
      title: Text(
        'Replace timetable?',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        'Replacing your timetable will re-align all recurring classes. Continue?',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Replace timetable'),
        ),
      ],
    );
  }
}
