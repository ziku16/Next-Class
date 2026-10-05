import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/theme/next_class_colors.dart';
import '../../domain/services/ai_extraction_service.dart';
import '../../domain/services/notification_service.dart';

/// Hidden Diagnostics Screen for inspecting system state and testing notifications/AI.
/// Accessible in debug builds or via 5-tap gesture on the Version tile in Settings.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final NotificationService _notificationService = NotificationService();
  final AiExtractionService _aiService = const AiExtractionService();

  bool _isLoading = true;
  String _apiKeyStatus = 'Checking...';
  String _tzLocalName = '';
  String _currentTzTime = '';
  bool _exactAlarmsPermitted = false;
  List<PendingNotificationRequest> _pendingRequests = [];
  String? _pingResult;
  bool _isPinging = false;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() => _isLoading = true);

    try {
      // 1. API key status (never leak the key itself)
      final key = await _aiService.getApiKey();
      if (key == null || key.trim().isEmpty) {
        _apiKeyStatus = 'Missing / Empty';
      } else {
        final trimmed = key.trim();
        final len = trimmed.length;
        final preview = len > 4 ? '...${trimmed.substring(len - 4)}' : '...';
        _apiKeyStatus = 'Configured (len: $len, ends with: $preview)';
      }

      // 2. Timezone
      _tzLocalName = tz.local.name;
      _currentTzTime = tz.TZDateTime.now(tz.local).toString();

      // 3. Exact alarms permission
      _exactAlarmsPermitted =
          await _notificationService.checkExactAlarmPermission();

      // 4. Pending notifications
      _pendingRequests =
          await _notificationService.getPendingNotificationRequests();
    } catch (e) {
      debugPrint('[DiagnosticsScreen] Error loading diagnostics: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showNotificationNow() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        NotificationService.classChannelId,
        NotificationService.classChannelName,
        channelDescription: NotificationService.classChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      await _notificationService.plugin.show(
        99999,
        'NextClass Test Alert',
        'Immediate test notification received successfully! 🎉',
        const NotificationDetails(android: androidDetails),
        payload: jsonEncode({'type': 'test', 'target': 'diagnostics'}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Immediate test notification fired!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to show notification: $e')),
        );
      }
    }
  }

  Future<void> _scheduleTestIn10Seconds() async {
    try {
      final scheduledDate =
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));

      const androidDetails = AndroidNotificationDetails(
        NotificationService.classChannelId,
        NotificationService.classChannelName,
        channelDescription: NotificationService.classChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      final exactPermitted =
          await _notificationService.checkExactAlarmPermission();
      final scheduleMode = exactPermitted
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _notificationService.plugin.zonedSchedule(
        99998,
        'NextClass 10s Test',
        '10-second test alarm fired right on schedule! ⏱️',
        scheduledDate,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({'type': 'test_10s'}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Scheduled for ${scheduledDate.toIso8601String().substring(11, 19)} (in 10s)',
            ),
          ),
        );
      }
      await _loadDiagnostics();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule 10s test: $e')),
        );
      }
    }
  }

  Future<void> _runGeminiPing() async {
    setState(() {
      _isPinging = true;
      _pingResult = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _aiService.pingGemini();
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _pingResult = 'SUCCESS (${stopwatch.elapsedMilliseconds}ms):\n$response';
        });
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _pingResult = 'FAILED (${stopwatch.elapsedMilliseconds}ms):\n$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPinging = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nc = context.ncColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDiagnostics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader(theme, 'ENVIRONMENT & API'),
                _buildInfoCard(theme, [
                  _buildRow('Model Constant', AiExtractionService.geminiModel),
                  _buildRow('API Key Status', _apiKeyStatus),
                  _buildRow('Timezone Location', _tzLocalName),
                  _buildRow('Current TZ Time', _currentTzTime),
                  _buildRow(
                    'Exact Alarms Permitted',
                    _exactAlarmsPermitted ? 'YES (Exact)' : 'NO (Falling back to Inexact)',
                    highlightColor: _exactAlarmsPermitted ? nc.emerald : nc.amber,
                  ),
                ]),
                const SizedBox(height: 20),

                _buildSectionHeader(theme, 'DIAGNOSTIC ACTIONS'),
                _buildCardGroup(theme, [
                  ListTile(
                    leading: const Icon(Icons.notifications_active_rounded),
                    title: const Text('Show notification now'),
                    subtitle: const Text('Fires immediate test alert on class channel'),
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: _showNotificationNow,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_rounded),
                    title: const Text('Schedule test in 10 seconds'),
                    subtitle: const Text('Uses zonedSchedule with active schedule mode'),
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: _scheduleTestIn10Seconds,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: _isPinging
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_sync_rounded),
                    title: const Text('Run Gemini ping test'),
                    subtitle: const Text('Sends a tiny request to verify API connectivity'),
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: _isPinging ? null : _runGeminiPing,
                  ),
                ]),

                if (_pingResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.Border.all(
                        color: _pingResult!.startsWith('SUCCESS')
                            ? nc.emerald
                            : theme.colorScheme.error,
                      ),
                    ),
                    child: Text(
                      _pingResult!,
                      style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                _buildSectionHeader(
                  theme,
                  'PENDING ALARMS (${_pendingRequests.length})',
                ),
                if (_pendingRequests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No alarms currently scheduled in the notification plugin.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ..._pendingRequests.map(
                    (req) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${req.id}'),
                        ),
                        title: Text(req.title ?? 'No title'),
                        subtitle: Text(
                          '${req.body ?? ""}\nPayload: ${req.payload ?? "none"}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
              ],
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

  Widget _buildInfoCard(ThemeData theme, List<Widget> children) {
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildCardGroup(ThemeData theme, List<Widget> children) {
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildRow(String label, String value, {Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: highlightColor,
                fontWeight: highlightColor != null ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
