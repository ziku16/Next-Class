import 'package:flutter/material.dart';
import '../../core/theme/next_class_colors.dart';

/// Privacy Policy Screen for NextClass.
/// Outlines local-only data architecture, permissions, and zero-tracking commitment.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nc = context.ncColors;

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: nc.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: nc.icon, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'PRIVACY POLICY',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 1.2,
            color: nc.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3.0),
          child: Container(
            color: nc.border,
            height: 3.0,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Header summary badge
          _buildHeroBadge(context),
          const SizedBox(height: 16),

          _buildSectionCard(
            context,
            title: '1. OVERVIEW',
            content:
                'NextClass is an offline-first university timetable and schedule companion designed to help students keep track of their lectures, laboratories, and quizzes. We respect your personal privacy. NextClass does not track you, does not require an account, and stores your timetable data locally on your device.',
          ),
          const SizedBox(height: 14),

          _buildSectionCard(
            context,
            title: '2. DATA STORED LOCALLY',
            content:
                'NextClass stores information you enter or import directly on your phone in private, secure app storage:\n\n'
                '• Course & Subject Names: The names of your enrolled courses.\n'
                '• Schedule Times: Class days of the week, start times, and end times.\n'
                '• Classrooms & Halls: Physical room, hall, or building designations.\n'
                '• Teacher / Instructor Names: Names of professors or instructors.\n'
                '• Quiz Dates & Topics: Scheduled quiz/exam dates, times, and topics.\n'
                '• Notification Settings: User preferences for reminder offsets and quiz alerts.\n\n'
                'This information never leaves your device and is never stored on external company servers.',
          ),
          const SizedBox(height: 14),

          _buildSectionCard(
            context,
            title: '3. NO USER ACCOUNTS',
            content:
                'NextClass does not require registration, login, email addresses, phone numbers, social logins, or student ID credentials. You can use all core features anonymously without providing any personally identifiable information.',
          ),
          const SizedBox(height: 14),

          _buildSectionCard(
            context,
            title: '4. 100% ON-DEVICE TIMETABLE SCANNING',
            content:
                'NextClass offers a timetable scanning feature allowing you to scan or upload a photo of your printed or digital schedule:\n\n'
                '• All timetable image scanning and schedule reading runs 100% locally and offline on your device.\n'
                '• Your timetable photos and schedule data are NEVER uploaded to any cloud server, external server, or third-party service.\n'
                '• NextClass does not transmit, retain, view, share, or sell your schedule photos. All data remains exclusively on your phone.',
          ),
          const SizedBox(height: 14),

          _buildSectionCard(
            context,
            title: '5. DEVICE PERMISSIONS',
            content:
                'NextClass requests the following Android device permissions only to perform essential functions:\n\n'
                '• POST_NOTIFICATIONS: Required on Android 13+ to deliver class start reminders and quiz alerts to your notification shade.\n'
                '• SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM: Required to trigger class reminders at the precise minute configured, even when the device is idle or in battery-saving Doze mode.\n'
                '• RECEIVE_BOOT_COMPLETED: Allows NextClass to automatically re-register your weekly class alarms when your device reboots.\n'
                '• CAMERA / PHOTO ACCESS: Requested only if you choose to take a photo of your schedule or pick an image from your gallery for timetable import.',
          ),
          const SizedBox(height: 14),

          _buildSectionCard(
            context,
            title: '6. ADVERTISING & ANALYTICS',
            content:
                '• Zero Advertising: NextClass contains no advertisements, sponsored content, or ad-network trackers.\n'
                '• Zero Analytics Trackers: We do not use third-party analytics SDKs to track your in-app actions, browsing habits, or behavioral metrics.\n'
                '• Zero Data Selling: We do not sell, rent, or monetize your schedule information.',
          ),
          const SizedBox(height: 14),

          _buildSectionCard(
            context,
            title: '7. DATA RETENTION & DELETION',
            content:
                'Because your data is stored locally on your device, you maintain full control:\n\n'
                '• You can edit or delete individual classes, schedule items, or quizzes at any time in the app.\n'
                '• You can reset all timetable data through the app settings or via Android Settings > Apps > NextClass > Storage > Clear Data.\n'
                '• Uninstalling NextClass permanently erases all saved classes, quizzes, and app preferences from your device.',
          ),
          const SizedBox(height: 14),

          _buildSectionCard(
            context,
            title: '8. CHILDREN\'S PRIVACY',
            content:
                'NextClass is designed for university and college students. We do not knowingly collect personal information from children under 13. Because NextClass does not collect personal identity information from any user, no children\'s personal data is gathered.',
          ),
          const SizedBox(height: 14),

          _buildSectionCard(
            context,
            title: '9. SECURITY',
            content:
                'Your timetable data is protected by the Android operating system\'s application sandbox, which prevents other installed applications from accessing NextClass\'s private app data.',
          ),
          const SizedBox(height: 14),

          _buildSectionCard(
            context,
            title: '10. POLICY UPDATES',
            content:
                'We may update this Privacy Policy from time to time. Any changes will be published directly within the app and on our official release page with an updated effective date.',
          ),
          const SizedBox(height: 14),

          _buildSectionCard(
            context,
            title: '11. CONTACT US',
            content:
                'If you have questions, feedback, or concerns regarding this Privacy Policy or your data, please contact:\n\n'
                'NextClass Support\n'
                'Email: support@nextclass.app\n'
                'Website: https://nextclass.app',
          ),
          const SizedBox(height: 24),

          // Bottom date badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: nc.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: nc.border, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: nc.shadow,
                    offset: const Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                'Effective Date: October 2026 • Version 1.0.0',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: nc.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeroBadge(BuildContext context) {
    final nc = context.ncColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE500), // Vibrant safety yellow
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: nc.border, width: 3.0),
        boxShadow: [
          BoxShadow(
            color: nc.shadow,
            offset: const Offset(4.0, 4.0),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.black, size: 24),
              SizedBox(width: 8),
              Text(
                'PRIVACY FIRST',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.1,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'NextClass operates 100% locally on your phone. No trackers. No advertisements. No accounts required.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final nc = context.ncColors;
    return Container(
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: nc.border, width: 3.0),
        boxShadow: [
          BoxShadow(
            color: nc.shadow,
            offset: const Offset(3.5, 3.5),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.0,
              color: nc.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: nc.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
