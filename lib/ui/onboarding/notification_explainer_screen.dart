import 'package:flutter/material.dart';
import '../../core/theme/next_class_colors.dart';
import '../upload/upload_screen.dart';

/// Step 2 of Onboarding: Explains notification value before prompting system permissions.
class NotificationExplainerScreen extends StatelessWidget {
  final VoidCallback? onComplete;

  const NotificationExplainerScreen({super.key, this.onComplete});

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
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Step 2 of 3',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Want a nudge\nbefore class?',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "We'll remind you before each class and the evening before each quiz. That's all, no spam.",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Mock Notification Card 1: Class Reminder
              _buildNotificationPreviewCard(
                context,
                icon: Icons.calendar_month_outlined,
                iconColor: theme.colorScheme.primary,
                appName: 'NextClass · now',
                title: 'Physics in 15 min · Room B-12',
                body: '09:30 – 10:20 · Ms. Sara',
              ),
              const SizedBox(height: 16),

              // Mock Notification Card 2: Quiz Reminder
              _buildNotificationPreviewCard(
                context,
                icon: Icons.quiz_outlined,
                iconColor: ncColors.quiz,
                appName: 'NextClass · 8:00 pm',
                title: 'Quiz tomorrow: Chemistry — Ch. 4–5',
                body: 'Fri, 3 Oct · Bring a calculator',
              ),

              const Spacer(),

              // Primary Action: Allow reminders
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _proceed(context),
                  child: const Text('Allow reminders'),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary Action: Not now
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _proceed(context),
                  child: const Text('Not now'),
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
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
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
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
