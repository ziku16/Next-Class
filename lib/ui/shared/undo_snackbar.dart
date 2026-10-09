import 'package:flutter/material.dart';

/// Helper utility to display high-contrast Retro-Brutalist floating SnackBars.
class UndoSnackBar {
  UndoSnackBar._();

  /// Displays a floating SnackBar with an explicit Undo action button.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    String actionLabel = 'Undo',
    Duration duration = const Duration(seconds: 5),
  }) {
    return _showBrutalistSnackBar(
      context,
      message: message,
      bgColor: const Color(0xFF121212),
      textColor: Colors.white,
      actionLabel: actionLabel,
      actionBgColor: const Color(0xFFFFDE59),
      actionTextColor: Colors.black,
      onAction: onUndo,
      duration: duration,
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
    return _showBrutalistSnackBar(
      context,
      message: message,
      bgColor: const Color(0xFF121212),
      textColor: Colors.white,
      actionLabel: actionLabel,
      actionBgColor: const Color(0xFFFFDE59),
      actionTextColor: Colors.black,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Displays a high-contrast Retro-Brutalist Success/Accent SnackBar (yellow/black).
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSuccess(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    return _showBrutalistSnackBar(
      context,
      message: message,
      bgColor: const Color(0xFFFFDE59),
      textColor: Colors.black,
      actionLabel: actionLabel,
      actionBgColor: const Color(0xFF121212),
      actionTextColor: Colors.white,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Displays a high-contrast Retro-Brutalist Error SnackBar (red/white).
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showError(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    return _showBrutalistSnackBar(
      context,
      message: message,
      bgColor: const Color(0xFFFF3333),
      textColor: Colors.white,
      actionLabel: actionLabel,
      actionBgColor: const Color(0xFF121212),
      actionTextColor: Colors.white,
      onAction: onAction,
      duration: duration,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _showBrutalistSnackBar(
    BuildContext context, {
    required String message,
    required Color bgColor,
    required Color textColor,
    String? actionLabel,
    Color? actionBgColor,
    Color? actionTextColor,
    VoidCallback? onAction,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    return messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        duration: duration,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        content: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: actionBgColor ?? const Color(0xFFFFDE59),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Text(
                      actionLabel,
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        color: actionTextColor ?? Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
