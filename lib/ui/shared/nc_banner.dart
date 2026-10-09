import 'package:flutter/material.dart';

enum NcBannerKind {
  info,
  warning,
  error,
  permission,
  offline,
}

/// Lightweight, custom non-modal banner used throughout NextClass.
/// Replaces heavyweight MaterialBanner with a slim, purpose-built surface.
class NcBanner extends StatelessWidget {
  final NcBannerKind kind;
  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final bool isDocked; // If true, flush to edges under status bar

  const NcBanner({
    super.key,
    required this.kind,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.isDocked = false,
  });

  /// Factory for the AI confidence warning banner
  factory NcBanner.aiWarning({
    Key? key,
    VoidCallback? onDismiss,
  }) {
    return NcBanner(
      key: key,
      kind: NcBannerKind.warning,
      title: "We weren't sure about a few classes.",
      message: 'Please double-check the highlighted ones.',
      onDismiss: onDismiss,
    );
  }

  /// Factory for notifications permission banner
  factory NcBanner.permission({
    Key? key,
    required VoidCallback onTurnOn,
  }) {
    return NcBanner(
      key: key,
      kind: NcBannerKind.permission,
      title: 'Reminders are off',
      message: 'Turn on notifications so we can nudge you before class.',
      actionLabel: 'Turn on',
      onAction: onTurnOn,
    );
  }

  /// Factory for exact alarms warning banner
  factory NcBanner.exactAlarms({
    Key? key,
    required VoidCallback onFix,
  }) {
    return NcBanner(
      key: key,
      kind: NcBannerKind.warning,
      title: 'Exact alarms are off',
      message: 'Reminders may arrive late without exact alarm permissions.',
      actionLabel: 'Fix',
      onAction: onFix,
    );
  }

  /// Factory for docked offline status bar
  factory NcBanner.offline({
    Key? key,
    VoidCallback? onRetry,
  }) {
    return NcBanner(
      key: key,
      kind: NcBannerKind.offline,
      message: "You're offline. Showing your saved timetable.",
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
      isDocked: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (kind) {
      case NcBannerKind.info:
        bg = const Color(0xFF121212);
        fg = Colors.white;
        icon = Icons.info_outline;
        break;
      case NcBannerKind.warning:
        bg = const Color(0xFFFFDE59);
        fg = Colors.black;
        icon = Icons.warning_amber_rounded;
        break;
      case NcBannerKind.error:
        bg = const Color(0xFFFF3333);
        fg = Colors.white;
        icon = Icons.error_outline;
        break;
      case NcBannerKind.permission:
        bg = const Color(0xFFFF6B00);
        fg = Colors.white;
        icon = Icons.notifications_off_outlined;
        break;
      case NcBannerKind.offline:
        bg = const Color(0xFF121212);
        fg = Colors.white;
        icon = Icons.wifi_off_rounded;
        break;
    }

    final content = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isDocked ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: isDocked ? BorderRadius.zero : BorderRadius.circular(8),
        border: isDocked
            ? const Border(bottom: BorderSide(color: Colors.black, width: 2.5))
            : Border.all(color: Colors.black, width: 2.5),
        boxShadow: isDocked
            ? null
            : const [
                BoxShadow(
                  color: Colors.black,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment:
            title != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      color: fg,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                backgroundColor: fg == Colors.black
                    ? const Color(0xFF121212)
                    : const Color(0xFFFFDE59),
                foregroundColor: fg == Colors.black ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: const BorderSide(color: Colors.black, width: 1.5),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
          if (onDismiss != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: fg),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
          ],
        ],
      ),
    );

    if (isDocked) {
      return content;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: content,
    );
  }
}
