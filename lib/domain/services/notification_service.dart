import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Notification management service for NextClass (Flow 9 / Phase 10).
/// Handles:
/// - Plugin initialization for Android & iOS
/// - Channel 1: `class_reminders_v2` (High importance, collapsed & expanded BigTextStyle)
/// - Channel 2: `quiz_reminders_v2` (High importance, evening-before alert)
/// - Tap payload dispatching for deep linking
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final StreamController<String> _payloadStreamController =
      StreamController<String>.broadcast();

  bool _isInitialized = false;

  NotificationService._internal({FlutterLocalNotificationsPlugin? plugin})
      : _notificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Visible for testing constructor allowing injected mock/fake plugin
  @visibleForTesting
  NotificationService.test(this._notificationsPlugin);

  /// Stream of notification tap payloads for deep linking
  Stream<String> get onPayloadTap => _payloadStreamController.stream;

  FlutterLocalNotificationsPlugin get plugin => _notificationsPlugin;
  bool get isInitialized => _isInitialized;

  // --- Notification Channel Constants (v2 to avoid cached system channel settings) ---

  static const String classChannelId = 'class_reminders_v2';
  static const String classChannelName = 'Class reminders';
  static const String classChannelDescription =
      'Notifications sent before each class';

  static const String quizChannelId = 'quiz_reminders_v2';
  static const String quizChannelName = 'Quiz reminders';
  static const String quizChannelDescription =
      'Notifications sent the evening before upcoming quizzes';

  /// Initializes timezone data and local notifications plugin
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Timezone setup
    try {
      tz.initializeTimeZones();
      const channel = MethodChannel('com.nextclass.app/device_info');
      final String? timeZoneName =
          await channel.invokeMethod<String>('getTimeZone');
      if (timeZoneName != null && timeZoneName.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint('[NotificationService] Timezone initialized to: ${tz.local.name} (device returned: $timeZoneName)');
      } else {
        debugPrint('[NotificationService] WARNING: Native getTimeZone returned null or empty. Fallback tz.local: ${tz.local.name}');
      }
    } catch (e) {
      debugPrint('[NotificationService] Timezone native resolution note: $e (tz.local: ${tz.local.name})');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _payloadStreamController.add(payload);
          }
        },
      );

      // Create Android Notification Channels with Importance.high
      try {
        final androidPlatform = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlatform != null) {
          await androidPlatform.createNotificationChannel(
            const AndroidNotificationChannel(
              classChannelId,
              classChannelName,
              description: classChannelDescription,
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );

          await androidPlatform.createNotificationChannel(
            const AndroidNotificationChannel(
              quizChannelId,
              quizChannelName,
              description: quizChannelDescription,
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );
        }
      } catch (e) {
        debugPrint('[NotificationService] Android platform channels skipped/unavailable: $e');
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Plugin and channels initialized successfully');
    } catch (e, stack) {
      debugPrint('[NotificationService] CRITICAL: NotificationService initialization failed: $e\n$stack');
    }
  }

  /// Requests notification permissions on Android 13+ and iOS
  Future<bool> requestPermissions() async {
    final androidPlatform = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlatform != null) {
      final granted = await androidPlatform.requestNotificationsPermission();
      debugPrint('[NotificationService] requestNotificationsPermission result: $granted');
      return granted ?? false;
    }

    final iOSPlatform = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iOSPlatform != null) {
      final granted = await iOSPlatform.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Requests exact alarms permission on Android 12+ (API 31+)
  Future<bool> requestExactAlarmsPermission() async {
    try {
      final androidPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final granted = await androidPlatform.requestExactAlarmsPermission();
        debugPrint('[NotificationService] requestExactAlarmsPermission result: $granted');
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error requesting exact alarms permission: $e');
    }
    return true;
  }

  /// Checks if exact alarms are permitted (Android 12+)
  Future<bool> checkExactAlarmPermission() async {
    try {
      final androidPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final canSchedule =
            await androidPlatform.canScheduleExactNotifications();
        return canSchedule ?? true;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error checking exact alarm permission: $e');
    }
    return true;
  }

  /// Retrieves list of all currently scheduled pending notification requests
  Future<List<PendingNotificationRequest>> getPendingNotificationRequests() async {
    try {
      return await _notificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('[NotificationService] Error querying pendingNotificationRequests: $e');
      return [];
    }
  }

  /// Schedules or displays a Class Reminder on the `class_reminders_v2` channel
  Future<void> scheduleClassReminder({
    required int id,
    required String subject,
    required int minutesBefore,
    required String startTime,
    required String endTime,
    String? room,
    String? teacher,
    String? nextSubject,
    String? nextTime,
    required tz.TZDateTime scheduledDate,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    // Sleek, clean Notification Content: Title shows class & countdown; body shows time, room & teacher
    final notificationTitle = minutesBefore > 0
        ? '$subject in $minutesBefore min'
        : 'Class now: $subject';

    final roomDisplay = (room != null && room.isNotEmpty)
        ? (room.toLowerCase().startsWith('room') ? room : 'Room $room')
        : null;

    final detailsList = <String>['$startTime – $endTime'];
    if (roomDisplay != null) detailsList.add(roomDisplay);
    if (teacher != null && teacher.isNotEmpty) detailsList.add(teacher);
    final collapsedBody = detailsList.join(' · ');

    final bigTextLines = <String>[
      'Time: $startTime – $endTime',
      if (roomDisplay != null) roomDisplay,
      if (teacher != null && teacher.isNotEmpty) 'Teacher: $teacher',
      if (nextSubject != null && nextTime != null)
        'Next class: $nextSubject at $nextTime',
    ];
    final bigText = bigTextLines.join('\n');

    final bigTextStyle = BigTextStyleInformation(
      bigText,
      htmlFormatBigText: false,
      contentTitle: notificationTitle,
      htmlFormatContentTitle: false,
      summaryText: 'Class Reminder',
      htmlFormatSummaryText: false,
    );

    final androidDetails = AndroidNotificationDetails(
      classChannelId,
      classChannelName,
      channelDescription: classChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      color: const Color(0xFF0E8A7D), // NextClass brand teal
      showWhen: true,
      styleInformation: bigTextStyle,
      playSound: true,
      enableVibration: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final payload = jsonEncode({
      'type': 'class',
      'target': 'today',
      'subject': subject,
    });

    // Standard notification scheduling: prefer exactAllowWhileIdle, gracefully fall back to inexactAllowWhileIdle
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    try {
      final canExact = await checkExactAlarmPermission();
      if (!canExact) {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    } catch (_) {
      scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        notificationTitle,
        collapsedBody,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
      debugPrint('[NotificationService] Scheduled class reminder: id=$id, subject="$subject", time=$scheduledDate, mode=$scheduleMode');
    } catch (e) {
      if (scheduleMode != AndroidScheduleMode.inexactAllowWhileIdle) {
        debugPrint('[NotificationService] Exact alarm failed ($e), falling back to inexactAllowWhileIdle for class $id');
        await _notificationsPlugin.zonedSchedule(
          id,
          notificationTitle,
          collapsedBody,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchDateTimeComponents,
          payload: payload,
        );
      } else {
        debugPrint('[NotificationService] CRITICAL: zonedSchedule failed for class ($id - "$subject"): $e');
        rethrow;
      }
    }
  }

  /// Schedules a Quiz Reminder on the `quiz_reminders_v2` channel
  Future<void> scheduleQuizReminder({
    required int id,
    required String quizId,
    required String subject,
    required String title,
    required String formattedDate,
    String? note,
    required tz.TZDateTime scheduledDate,
    bool isDayOf = false,
  }) async {
    // Collapsed Content
    final collapsedTitle =
        isDayOf ? 'Quiz today: $subject' : 'Quiz tomorrow: $subject';
    final collapsedBody = '$title · $formattedDate${note != null && note.isNotEmpty ? " · $note" : ""}';

    // Expanded Content
    final bigTextLines = <String>[
      isDayOf ? 'Good luck on your $subject quiz today!' : 'Quiz tomorrow: $subject',
      'Topic: $title',
      'Date: $formattedDate',
      if (note != null && note.isNotEmpty) 'Note: $note',
    ];
    final bigText = bigTextLines.join('\n');

    final bigTextStyle = BigTextStyleInformation(
      bigText,
      htmlFormatBigText: false,
      contentTitle: collapsedTitle,
      htmlFormatContentTitle: false,
      summaryText: isDayOf ? 'Quiz Today' : 'Quiz Tomorrow',
      htmlFormatSummaryText: false,
    );

    final androidDetails = AndroidNotificationDetails(
      quizChannelId,
      quizChannelName,
      channelDescription: quizChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      color: const Color(0xFF5B6BD6), // NextClass quiz indigo
      showWhen: true,
      styleInformation: bigTextStyle,
      playSound: true,
      enableVibration: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final payload = jsonEncode({
      'type': 'quiz',
      'quizId': quizId,
      'subject': subject,
    });

    // Standard notification scheduling: prefer exactAllowWhileIdle, gracefully fall back to inexactAllowWhileIdle
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    try {
      final canExact = await checkExactAlarmPermission();
      if (!canExact) {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    } catch (_) {
      scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        collapsedTitle,
        collapsedBody,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('[NotificationService] Scheduled quiz reminder: id=$id, subject="$subject", time=$scheduledDate, mode=$scheduleMode');
    } catch (e) {
      if (scheduleMode != AndroidScheduleMode.inexactAllowWhileIdle) {
        debugPrint('[NotificationService] Exact alarm failed ($e), falling back to inexactAllowWhileIdle for quiz $id');
        await _notificationsPlugin.zonedSchedule(
          id,
          collapsedTitle,
          collapsedBody,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } else {
        debugPrint('[NotificationService] CRITICAL: zonedSchedule failed for quiz ($id - "$subject"): $e');
        rethrow;
      }
    }
  }

  /// Cancels an individual notification by ID
  Future<void> cancel(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      debugPrint('[NotificationService] Cancelled notification id: $id');
    } catch (e) {
      debugPrint('[NotificationService] Error cancelling notification id $id: $e');
    }
  }

  /// Cancels all scheduled notifications
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('[NotificationService] Cancelled all notifications');
    } catch (e) {
      debugPrint('[NotificationService] Error cancelling all notifications: $e');
    }
  }

  void dispose() {
    _payloadStreamController.close();
  }
}
