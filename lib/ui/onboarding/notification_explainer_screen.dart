import 'package:flutter/material.dart';
import '../../core/theme/next_class_colors.dart';
import '../../domain/services/notification_service.dart';
import '../upload/upload_screen.dart';

/// Step 2 of Onboarding: Explains notification value before prompting system permissions.
class NotificationExplainerScreen extends StatelessWidget {
  final VoidCallback? onComplete;

  const NotificationExplainerScreen({super.key, this.onComplete});

  void _handleAllow(BuildContext context) {
    try {
      NotificationService().initialize().then((_) {
        NotificationService().requestPermissions();
      });
    } catch (_) {}
    _proceed(context);
  }

  void _proceed(BuildContext context) {
    if (onComplete != null) {
      onComplete!();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const UploadScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ncColors = context.ncColors;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF6EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: Colors.black, width: 3.0)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE500),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black, width: 1.5),
          ),
          child: const Text(
            'Step 2 of 3',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
              color: Colors.black,
            ),
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Want a nudge\nbefore class?',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  height: 1.15,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "NextClass sends 2 types of reminders: before each class and for upcoming quizzes. That's all, zero spam.",
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),

              // Type 1: Class Reminder
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE500),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: const Text(
                  '1. CLASS REMINDERS',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildNotificationPreviewCard(
                context,
                icon: Icons.calendar_month_outlined,
                iconColor: const Color(0xFFFF5500),
                appName: 'NextClass · now',
                title: 'Physics in 15 min · Room B-12',
                body: '09:30 – 10:20 · Ms. Sara',
              ),
              const SizedBox(height: 20),

              // Type 2: Quiz Reminder
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: const Text(
                  '2. QUIZ REMINDERS',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildNotificationPreviewCard(
                context,
                icon: Icons.quiz_outlined,
                iconColor: const Color(0xFFFF5500),
                appName: 'NextClass · 8:00 pm',
                title: 'Quiz tomorrow: Chemistry — Ch. 4–5',
                body: 'Fri, 3 Oct · Bring a calculator',
              ),

              const SizedBox(height: 32),

              // Primary Action: Allow reminders
              Container(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(3.5, 3.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    key: const Key('allow_notifications_button'),
                    onPressed: () => _handleAllow(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5500),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: Colors.black, width: 2.5),
                      ),
                    ),
                    child: const Text(
                      'Allow reminders',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary Action: Not now
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _proceed(context),
                  child: const Text(
                    'Not now',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      fontSize: 15,
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
  }

  Widget _buildNotificationPreviewCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String appName,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.black,
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                appName,
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: const TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
