import 'package:flutter/material.dart';
import 'notification_explainer_screen.dart';

/// Welcome onboarding screen presenting value proposition and direct "Get started" entry.
/// No login or signup required — users start immediately.
class WelcomeScreen extends StatelessWidget {
  final VoidCallback? onGetStarted;
  final VoidCallback? onSignInSuccess; // Alias for backward compatibility
  final bool simulateCancel;
  final bool simulateOffline;

  const WelcomeScreen({
    super.key,
    this.onGetStarted,
    this.onSignInSuccess,
    this.simulateCancel = false,
    this.simulateOffline = false,
  });

  void _handleGetStarted(BuildContext context) {
    if (onGetStarted != null) {
      onGetStarted!();
    } else if (onSignInSuccess != null) {
      onSignInSuccess!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const NotificationExplainerScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40.0),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // App Title & Headline
                      Text(
                        'NextClass',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Never miss a class\nor a quiz.',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 3 Value Rows
                      _buildValueRow(
                        context,
                        icon: Icons.photo_camera_outlined,
                        title: 'Snap a photo of your timetable',
                        subtitle: "We'll read every day, time, and room for you.",
                      ),
                      const SizedBox(height: 24),
                      _buildValueRow(
                        context,
                        icon: Icons.auto_awesome_outlined,
                        title: 'We find every class for you',
                        subtitle: 'No manual entry required. Just verify and save.',
                      ),
                      const SizedBox(height: 24),
                      _buildValueRow(
                        context,
                        icon: Icons.notifications_active_outlined,
                        title: 'Get reminded right on time',
                        subtitle: '15 min before class and the evening before each quiz.',
                      ),

                      const Spacer(),
                      const SizedBox(height: 24),

                      // Direct "Get started" Action Button (No login/signup required)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          key: const Key('get_started_button'),
                          onPressed: () => _handleGetStarted(context),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get started',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Friendly Tagline
                      Center(
                        child: Text(
                          "Chalo, let's get organised.",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildValueRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 22,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
