import 'package:flutter/material.dart';
import '../shared/google_button.dart';
import '../shared/nc_banner.dart';
import '../shared/undo_snackbar.dart';
import 'notification_explainer_screen.dart';

/// Welcome onboarding screen presenting value proposition and Google authentication.
class WelcomeScreen extends StatefulWidget {
  final VoidCallback? onSignInSuccess;
  final bool simulateCancel;
  final bool simulateOffline;

  const WelcomeScreen({
    super.key,
    this.onSignInSuccess,
    this.simulateCancel = false,
    this.simulateOffline = false,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Simulate authentication delay
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (widget.simulateCancel) {
      _showCancelledMessage();
      return;
    }

    if (widget.simulateOffline) {
      _showOfflineError();
      return;
    }

    if (widget.onSignInSuccess != null) {
      widget.onSignInSuccess!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const NotificationExplainerScreen(),
        ),
      );
    }
  }

  void _showCancelledMessage() {
    UndoSnackBar.showMessage(
      context,
      message: 'Sign-in cancelled. Tap the button to try again.',
    );
  }

  void _showOfflineError() {
    setState(() {
      _errorMessage = "Couldn't sign you in. Check your internet and try again.";
    });
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
                      const SizedBox(height: 16),

                      // Optional error banner
                      if (_errorMessage != null) ...[
                        NcBanner(
                          kind: NcBannerKind.error,
                          message: _errorMessage!,
                          onDismiss: () => setState(() => _errorMessage = null),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Google Sign-In Button
                      GoogleButton(
                        isLoading: _isLoading,
                        onPressed: _handleGoogleSignIn,
                      ),
                      const SizedBox(height: 16),

                      // Disclaimer
                      Center(
                        child: Text(
                          "Chalo, let's get organised.\nBy continuing you agree to our Terms and Privacy Policy.",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
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
