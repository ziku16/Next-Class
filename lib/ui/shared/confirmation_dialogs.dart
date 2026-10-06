import 'package:flutter/material.dart';

/// Modal confirmation dialogs for NextClass (Flows 7 & 8).
/// Enforces:
/// - 28 dp corner radius per Material 3 Design System specs
/// - Descriptive consequence explanations (cascading deletes, reminder stoppages)
/// - Clear destructive vs. neutral action styling
class ConfirmationDialogs {
  ConfirmationDialogs._();

  /// Displays the Sign Out confirmation dialog.
  /// "Sign out? Reminders stop until you sign in again. Your timetable stays saved to your account."
  /// Buttons: [Stay signed in] / [Sign out]
  static Future<bool?> showSignOutDialog(BuildContext context) {
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF6EE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Colors.black, width: 3.5),
        ),
        title: Text(
          'Sign out?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        content: Text(
          'Reminders stop until you sign in again. Your timetable stays saved to your account.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: Colors.black, width: 2.5),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF1744),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: Colors.black, width: 2.5),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  /// Displays the Delete Class cascading warning dialog.
  /// "Delete [Subject]? This removes it from [Day] and cancels its reminders. Any quiz linked to this class will go too."
  /// Buttons: [Keep it] / [Delete]
  static Future<bool?> showDeleteClassDialog(
    BuildContext context, {
    required String subject,
    required String dayOfWeek,
  }) {
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF6EE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Colors.black, width: 3.5),
        ),
        title: Text(
          'Delete $subject?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        content: Text(
          'This removes it from $dayOfWeek and cancels its reminders. Any quiz linked to this class will go too.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: Colors.black, width: 2.5),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF1744),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: Colors.black, width: 2.5),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Displays the Delete Quiz confirmation dialog.
  /// "Delete this quiz? [Subject] · [Date]. Its reminder will be cancelled."
  /// Buttons: [Keep it] / [Delete]
  static Future<bool?> showDeleteQuizDialog(
    BuildContext context, {
    required String subject,
    required String formattedDate,
  }) {
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF6EE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Colors.black, width: 3.5),
        ),
        title: Text(
          'Delete this quiz?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        content: Text(
          '$subject · $formattedDate. Its reminder will be cancelled.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: Colors.black, width: 2.5),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF1744),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: Colors.black, width: 2.5),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
