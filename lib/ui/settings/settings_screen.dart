import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/next_class_colors.dart';
import '../../data/models/scan_quota.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/services/alarm_scheduler.dart';
import '../../domain/services/notification_service.dart';
import '../../state/settings_provider.dart';
import '../debug/diagnostics_screen.dart';
import '../shared/confirmation_dialogs.dart';
import 'reminder_picker_dialog.dart';
import 'replace_timetable_dialog.dart';

/// App Settings & Reminders Configuration Screen (Flow 7 & 8).
/// Features:
/// - REMINDERS: Segmented class reminder picker, quiz reminder switch, quiz time picker
/// - NOTIFICATIONS: Notification permission switch, exact alarms warning tile with [Fix]
/// - TIMETABLE: Edit timetable navigation, Upload new timetable with scan quota & replace dialog
/// - ABOUT: Support, Privacy Policy, App Version, Sign out confirmation dialog
class SettingsScreen extends StatefulWidget {
  final SettingsProvider? settingsProvider;
  final SettingsRepository? settingsRepository;
  final UserSettings? initialSettings;
  final ScanQuota? initialQuota;

  final VoidCallback? onEditTimetable;
  final VoidCallback? onUploadTimetable;
  final VoidCallback? onContactSupport;
  final VoidCallback? onPrivacyPolicy;
  final VoidCallback? onSignOut;

  const SettingsScreen({
    super.key,
    this.settingsProvider,
    this.settingsRepository,
    this.initialSettings,
    this.initialQuota,
    this.onEditTimetable,
    this.onUploadTimetable,
    this.onContactSupport,
    this.onPrivacyPolicy,
    this.onSignOut,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsProvider _provider;
  bool _ownsProvider = false;
  int _versionTapCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.settingsProvider != null) {
      _provider = widget.settingsProvider!;
    } else {
      _ownsProvider = true;
      _provider = SettingsProvider(
        settingsRepository: widget.settingsRepository,
        initialSettings: widget.initialSettings,
        initialQuota: widget.initialQuota,
      );
      _provider.loadSettings();
    }

    _provider.addListener(_onProviderUpdate);
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    if (_ownsProvider) {
      _provider.dispose();
    }
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleQuizTimePicker() async {
    final current = _provider.quizReminderTime.split(':');
    final initialHour = int.tryParse(current[0]) ?? 20;
    final initialMinute = current.length > 1 ? (int.tryParse(current[1]) ?? 0) : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      await _provider.updateQuizReminderTime('$hourStr:$minuteStr');
    }
  }

  Future<void> _handleUploadNewTimetable() async {
    final confirmed = await ReplaceTimetableDialog.show(context);
    if (confirmed == true && mounted) {
      widget.onUploadTimetable?.call();
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await ConfirmationDialogs.showSignOutDialog(context);
    if (confirmed == true && mounted) {
      widget.onSignOut?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ncColors = context.ncColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ================= REMINDERS =================
            _buildSectionHeader(theme, 'REMINDERS'),
            _buildCardGroup(
              theme,
              children: [
                // Class Reminder Segmented Setting
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 22,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Class reminder',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  UserSettings.classReminderLabel(
                                    _provider.classReminderMinutes,
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.tune_rounded, size: 20),
                            tooltip: 'Select reminder time',
                            onPressed: () async {
                              final res = await ReminderPickerDialog.show(
                                context,
                                currentMinutes: _provider.classReminderMinutes,
                              );
                              if (res != null || res == null) {
                                _provider.updateClassReminderMinutes(res);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Segmented Button with 6 options: Off, 5m, 10m, 15m, 30m, 60m
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: SegmentedButton<int?>(
                            key: const Key('class_reminder_segmented'),
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment<int?>(
                                value: null,
                                label: Text('Off'),
                              ),
                              ButtonSegment<int?>(
                                value: 5,
                                label: Text('5 min'),
                              ),
                              ButtonSegment<int?>(
                                value: 10,
                                label: Text('10 min'),
                              ),
                              ButtonSegment<int?>(
                                value: 15,
                                label: Text('15 min'),
                              ),
                              ButtonSegment<int?>(
                                value: 30,
                                label: Text('30 min'),
                              ),
                              ButtonSegment<int?>(
                                value: 60,
                                label: Text('60 min'),
                              ),
                            ],
                            selected: {_provider.classReminderMinutes},
                            onSelectionChanged: (Set<int?> newSelection) {
                              _provider.updateClassReminderMinutes(
                                newSelection.first,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Quiz Reminder Toggle
                SwitchListTile(
                  key: const Key('quiz_reminder_switch'),
                  secondary: Icon(
                    Icons.quiz_outlined,
                    color: theme.colorScheme.tertiary,
                  ),
                  title: Text(
                    'Quiz reminder',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'The evening before',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: _provider.quizReminderEnabled,
                  onChanged: (val) => _provider.toggleQuizReminder(val),
                ),
                const Divider(height: 1),

                // Quiz Reminder Time Picker Tile
                ListTile(
                  key: const Key('quiz_reminder_time_tile'),
                  enabled: _provider.quizReminderEnabled,
                  leading: Icon(
                    Icons.schedule_outlined,
                    color: _provider.quizReminderEnabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  title: Text(
                    'Quiz reminder time',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _provider.quizReminderEnabled
                          ? theme.colorScheme.secondaryContainer
                          : theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _provider.formattedQuizReminderTime,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _provider.quizReminderEnabled
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  onTap: _provider.quizReminderEnabled
                      ? _handleQuizTimePicker
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ================= NOTIFICATIONS =================
            _buildSectionHeader(theme, 'NOTIFICATIONS'),
            _buildCardGroup(
              theme,
              children: [
                // Notification Permission Switch
                SwitchListTile(
                  key: const Key('notifications_permission_switch'),
                  secondary: Icon(
                    Icons.notifications_active_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Allow notifications',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Required for class and quiz reminders',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: _provider.notificationsEnabled,
                  onChanged: (val) async {
                    if (val) {
                      final granted =
                          await NotificationService().requestPermissions();
                      _provider.toggleNotifications(granted);
                      if (granted) {
                        await AlarmScheduler().rescheduleAll();
                      }
                    } else {
                      _provider.toggleNotifications(false);
                      await NotificationService().cancelAll();
                    }
                  },
                ),

                // Exact Alarms Warning Tile (shown if permission missing)
                if (!_provider.exactAlarmsGranted) ...[
                  const Divider(height: 1),
                  Material(
                    color: ncColors.warningContainer.withValues(alpha: 0.35),
                    child: ListTile(
                      key: const Key('exact_alarms_warning_tile'),
                      leading: Icon(
                        Icons.alarm_off_rounded,
                        color: ncColors.warning,
                      ),
                      title: Text(
                        'Exact alarms are off',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: ncColors.onWarningContainer,
                        ),
                      ),
                      subtitle: Text(
                        'Reminders may arrive late.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ncColors.onWarningContainer,
                        ),
                      ),
                      trailing: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () {
                          _provider.setExactAlarmsGranted(true);
                          NotificationService().requestExactAlarmsPermission();
                        },
                        child: const Text('Fix'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // ================= TIMETABLE =================
            _buildSectionHeader(theme, 'TIMETABLE'),
            _buildCardGroup(
              theme,
              children: [
                // Edit Timetable Tile
                ListTile(
                  key: const Key('edit_timetable_tile'),
                  leading: Icon(
                    Icons.calendar_month_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Edit timetable',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Add, modify, or remove classes',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onEditTimetable,
                ),
                const Divider(height: 1),

                // Upload New Timetable Tile with Quota
                ListTile(
                  key: const Key('upload_timetable_tile'),
                  leading: Icon(
                    Icons.upload_file_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Upload new timetable',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _provider.quotaDisplayText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _handleUploadNewTimetable,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ================= ABOUT =================
            _buildSectionHeader(theme, 'ABOUT'),
            _buildCardGroup(
              theme,
              children: [
                ListTile(
                  leading: const Icon(Icons.mail_outline_rounded),
                  title: const Text('Contact support'),
                  subtitle: const Text('support@nextclass.app'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: widget.onContactSupport ??
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Support contact: support@nextclass.app',
                            ),
                          ),
                        );
                      },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: widget.onPrivacyPolicy,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Version'),
                  trailing: const Text('1.0.0'),
                  onTap: () {
                    _versionTapCount++;
                    if (_versionTapCount >= 5 || kDebugMode) {
                      _versionTapCount = 0;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DiagnosticsScreen(),
                        ),
                      );
                    }
                  },
                ),
                if (widget.onSignOut != null) ...[
                  const Divider(height: 1),
                  // Sign Out Button (shown only if sign out callback is provided)
                  ListTile(
                    key: const Key('sign_out_tile'),
                    leading: Icon(
                      Icons.logout_rounded,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      'Sign out',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: _handleSignOut,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildCardGroup(ThemeData theme, {required List<Widget> children}) {
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }
}
