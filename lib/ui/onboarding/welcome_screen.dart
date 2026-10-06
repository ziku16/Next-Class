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
      backgroundColor: const Color(0xFFFAF6EE),
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
                      const SizedBox(height: 12),

                      // Slanted Sticker Tag
                      Transform.rotate(
                        angle: -0.03,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE500),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.black, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(2.5, 2.5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: const Text(
                            'NEXTCLASS ↗',
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1.0,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Main Headline
                      const Text(
                        'Never miss a class\nor a quiz.',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w900,
                          fontSize: 34,
                          height: 1.1,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 3 Value Rows in Brutalist Cards
                      _buildValueRow(
                        context,
                        icon: Icons.photo_camera_outlined,
                        iconColor: const Color(0xFFFFE500),
                        title: 'Snap a photo of your timetable',
                        subtitle: "We'll read every day, time, and room for you.",
                      ),
                      const SizedBox(height: 14),
                      _buildValueRow(
                        context,
                        icon: Icons.auto_awesome_outlined,
                        iconColor: const Color(0xFF00E676),
                        title: 'We find every class for you',
                        subtitle: 'No manual entry required. Just verify and save.',
                      ),
                      const SizedBox(height: 14),
                      _buildValueRow(
                        context,
                        icon: Icons.notifications_active_outlined,
                        iconColor: const Color(0xFFFF5500),
                        title: 'Get reminded right on time',
                        subtitle: '15 min before class and the evening before each quiz.',
                      ),

                      const Spacer(),
                      const SizedBox(height: 24),

                      // Direct "Get started" Action Button (No login/signup required)
                      Container(
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(4, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            key: const Key('get_started_button'),
                            onPressed: () => _handleGetStarted(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5500),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: const BorderSide(color: Colors.black, width: 2.5),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Get started',
                                  style: TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Friendly Tagline
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: const Text(
                            "Chalo, let's get organised.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
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
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black, width: 2.0),
            ),
            child: Icon(
              icon,
              size: 24,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
