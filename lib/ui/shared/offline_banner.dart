import 'package:flutter/material.dart';
import '../../domain/services/connectivity_service.dart';

/// Slim inverse surface banner displayed immediately below the system status bar when offline (Flow 9).
/// Features:
/// - `colorScheme.inverseSurface` background with `colorScheme.onInverseSurface` foreground
/// - "wifi_off You're offline. Showing your saved timetable." copy
/// - Automatic slide-up and collapse animation upon reconnection
/// - Optional Retry action button
class OfflineBanner extends StatelessWidget {
  final bool? isOffline;
  final VoidCallback? onRetry;
  final Duration animationDuration;

  const OfflineBanner({
    super.key,
    this.isOffline,
    this.onRetry,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    if (isOffline != null) {
      return _buildAnimatedContainer(context, isOffline!);
    }

    final service = ConnectivityService();
    return ListenableBuilder(
      listenable: service,
      builder: (ctx, _) => _buildAnimatedContainer(ctx, service.isOffline),
    );
  }

  Widget _buildAnimatedContainer(BuildContext context, bool offline) {
    final theme = Theme.of(context);

    return AnimatedSize(
      duration: animationDuration,
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: offline
          ? Container(
              key: const Key('offline_banner_container'),
              width: double.infinity,
              color: theme.colorScheme.inverseSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SafeArea(
                bottom: false,
                top: false,
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 18,
                      color: theme.colorScheme.onInverseSurface,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "You're offline. Showing your saved timetable.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onInverseSurface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: const Size(40, 32),
                          textStyle: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
