import 'package:flutter/material.dart';

/// Helper utility to display standard NextClass floating SnackBars with actions.
class UndoSnackBar {
  UndoSnackBar._();

  /// Displays a 5-second floating SnackBar with an explicit Undo action button.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    String actionLabel = 'Undo',
    Duration duration = const Duration(seconds: 5),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final theme = Theme.of(context);

    return messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onInverseSurface,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        action: SnackBarAction(
          label: actionLabel,
          textColor: theme.colorScheme.primaryContainer,
          onPressed: onUndo,
        ),
      ),
    );
  }

  /// Displays a simple informative floating SnackBar.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showMessage(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final theme = Theme.of(context);

    return messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onInverseSurface,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: theme.colorScheme.primaryContainer,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}
