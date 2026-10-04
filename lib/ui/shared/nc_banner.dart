import 'package:flutter/material.dart';
import '../../core/theme/next_class_colors.dart';

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
    final theme = Theme.of(context);
    final ncColors = context.ncColors;

    Color bg;
    Color fg;
    IconData icon;

    switch (kind) {
      case NcBannerKind.info:
        bg = ncColors.infoContainer;
        fg = ncColors.onInfoContainer;
        icon = Icons.info_outline;
        break;
      case NcBannerKind.warning:
        bg = ncColors.warningContainer;
        fg = ncColors.onWarningContainer;
        icon = Icons.warning_amber_rounded;
        break;
      case NcBannerKind.error:
        bg = theme.colorScheme.errorContainer;
        fg = theme.colorScheme.onErrorContainer;
        icon = Icons.error_outline;
        break;
      case NcBannerKind.permission:
        bg = theme.colorScheme.secondaryContainer;
        fg = theme.colorScheme.onSecondaryContainer;
        icon = Icons.notifications_off_outlined;
        break;
      case NcBannerKind.offline:
        bg = theme.colorScheme.inverseSurface;
        fg = theme.colorScheme.onInverseSurface;
        icon = Icons.wifi_off_rounded;
        break;
    }

    final content = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isDocked ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: isDocked ? BorderRadius.zero : BorderRadius.circular(12),
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fg,
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
                foregroundColor: fg,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(48, 48),
                textStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
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
