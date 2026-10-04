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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        title: Text(
          'Sign out?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Reminders stop until you sign in again. Your timetable stays saved to your account.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        title: Text(
          'Delete $subject?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'This removes it from $dayOfWeek and cancels its reminders. Any quiz linked to this class will go too.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        title: Text(
          'Delete this quiz?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '$subject · $formattedDate. Its reminder will be cancelled.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
