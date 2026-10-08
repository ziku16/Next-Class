import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/class_item.dart';
import '../../data/models/quiz_item.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/timetable_repository.dart';

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
        try {
          tz.setLocalLocation(tz.getLocation(timeZoneName));
          debugPrint('[NotificationService] Timezone initialized to: ${tz.local.name} (device returned: $timeZoneName)');
        } catch (tzErr) {
          debugPrint('[NotificationService] Location not found for $timeZoneName ($tzErr). Attempting offset match...');
          final offset = DateTime.now().timeZoneOffset;
          tz.Location? matched;
          for (final loc in tz.timeZoneDatabase.locations.values) {
            if (loc.currentTimeZone.offset == offset.inMilliseconds) {
              matched = loc;
              break;
            }
          }
          if (matched != null) {
            tz.setLocalLocation(matched);
            debugPrint('[NotificationService] Fallback matched timezone: ${tz.local.name} (offset ${offset.inHours}h)');
          }
        }
      } else {
        debugPrint('[NotificationService] WARNING: Native getTimeZone returned null or empty. Fallback tz.local: ${tz.local.name}');
      }
    } catch (e) {
      debugPrint('[NotificationService] Timezone native resolution note: $e (tz.local: ${tz.local.name})');
    }

    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
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
      ?roomDisplay,
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
      icon: 'ic_notification',
      color: const Color(0xFFFF5500), // NextClass brand vivid orange
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
    bool canExact = true;
    try {
      canExact = await checkExactAlarmPermission();
      if (!canExact) {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    } catch (_) {
      scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    }

    debugPrint('''
[NotificationService] Scheduling class reminder:
  ID: $id
  Subject: "$subject"
  Time: $scheduledDate (weekday: ${scheduledDate.weekday})
  Mode: $scheduleMode (canExact: $canExact)
  Recurrence: ${matchDateTimeComponents?.name ?? 'one-shot'}
''');

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
      debugPrint('[NotificationService] Successfully scheduled class reminder: id=$id, subject="$subject", time=$scheduledDate, mode=$scheduleMode');
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
      icon: 'ic_notification',
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

  /// Deterministic ID generator for class notification (0 - 99,999).
  static int getClassNotificationId(String classId, [int? index]) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < classId.length; i++) {
      hash ^= classId.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash % 100000;
  }

  /// Deterministic ID generator for quiz notification (100,000 - 199,999).
  static int getQuizNotificationId(String quizId, [int? index]) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < quizId.length; i++) {
      hash ^= quizId.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return 100000 + (hash % 100000);
  }

  /// Cancels reminder for a specific class
  Future<void> cancelClassReminder(String classId) async {
    final id = getClassNotificationId(classId);
    await cancel(id);
  }

  /// Cancels reminder for a specific quiz
  Future<void> cancelQuizReminder(String quizId) async {
    final id = getQuizNotificationId(quizId);
    await cancel(id);
  }

  /// Alias for cancelling a notification by ID
  Future<void> cancelNotification(int id) async => cancel(id);

  /// Alias for cancelling all scheduled notifications
  Future<void> cancelAllNotifications() async => cancelAll();

  static bool _isRescheduling = false;
  static bool _rescheduleQueued = false;

  /// Reschedules all class and quiz reminders according to current database state and settings.
  Future<void> rescheduleAll({
    DateTime? now,
    List<ClassItem>? classes,
    List<QuizItem>? quizzes,
    UserSettings? settings,
    TimetableRepository? timetableRepo,
    QuizRepository? quizRepo,
    SettingsRepository? settingsRepo,
  }) async {
    if (_isRescheduling) {
      _rescheduleQueued = true;
      debugPrint('[NotificationService] Reschedule already in progress. Queued next run.');
      return;
    }
    _isRescheduling = true;

    final currentTime = now ?? DateTime.now();
    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
    }
    debugPrint('[NotificationService] Starting rescheduleAll at $currentTime. Active timezone: ${tz.local.name}');

    try {
      await initialize();

      // Retrieve latest state if not provided
      final userSettings = settings ?? await (settingsRepo ?? SettingsRepository()).getUserSettings();
      final classList = classes ?? await (timetableRepo ?? TimetableRepository()).getAllClasses();
      final quizList = quizzes ?? await (quizRepo ?? QuizRepository()).getUpcomingQuizzes(referenceDate: currentTime);

      // Cancel all existing scheduled notifications first to prevent stale alarms
      await cancelAll();

      int scheduledCount = 0;
      int failedCount = 0;

      // 1. Schedule class reminders
      final offsetMinutes = userSettings.classReminderMinutes;
      if (offsetMinutes != null && offsetMinutes > 0) {
        // Group classes by day to compute "Next class after this"
        final Map<String, List<ClassItem>> dayGroups = {};
        for (final c in classList) {
          dayGroups.putIfAbsent(c.dayOfWeek, () => []).add(c);
        }
        for (final dayList in dayGroups.values) {
          dayList.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
        }

        for (final classItem in classList) {
          try {
            final sameDayClasses = dayGroups[classItem.dayOfWeek] ?? [];
            final currentIndex = sameDayClasses.indexWhere((c) => c.id == classItem.id);
            final ClassItem? nextClass = (currentIndex != -1 && currentIndex + 1 < sameDayClasses.length)
                ? sameDayClasses[currentIndex + 1]
                : null;

            final notificationId = getClassNotificationId(classItem.id);
            final scheduledTZ = calculateNextClassReminderTZ(
              dayIndex: classItem.dayIndex,
              startTime: classItem.startTime,
              offsetMinutes: offsetMinutes,
              now: currentTime,
            );

            await scheduleClassReminder(
              id: notificationId,
              subject: classItem.subject,
              minutesBefore: offsetMinutes,
              startTime: classItem.startTime,
              endTime: classItem.endTime,
              room: classItem.room,
              teacher: classItem.teacher,
              nextSubject: nextClass?.subject,
              nextTime: nextClass?.startTime,
              scheduledDate: scheduledTZ,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            );
            scheduledCount++;
          } catch (e) {
            failedCount++;
            debugPrint('[NotificationService] Error scheduling class "${classItem.subject}": $e');
          }
        }
      }

      // 2. Schedule quiz reminders
      if (userSettings.quizReminderEnabled) {
        final parts = userSettings.quizReminderTime.split(':');
        final defaultHour = int.tryParse(parts[0]) ?? 20;
        final defaultMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

        for (final quiz in quizList) {
          if (quiz.isCompleted) continue;
          try {
            int targetHour = defaultHour;
            int targetMinute = defaultMinute;
            if (quiz.reminderTime != null && quiz.reminderTime!.isNotEmpty) {
              final p = quiz.reminderTime!.split(':');
              targetHour = int.tryParse(p[0]) ?? defaultHour;
              targetMinute = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
            } else if (quiz.reminderType == 'morning_of') {
              targetHour = 8;
              targetMinute = 0;
            }

            final reminderDateTime = calculateQuizReminderDateTime(
              dueDate: quiz.dueDate,
              reminderHour: targetHour,
              reminderMinute: targetMinute,
              reminderType: quiz.reminderType,
            );

            if (reminderDateTime.isAfter(currentTime)) {
              final notificationId = getQuizNotificationId(quiz.id);
              final scheduledTZ = _toTZDateTime(reminderDateTime);
              final formattedDue = DateFormat('EEE, d MMM').format(quiz.dueDate);

              await scheduleQuizReminder(
                id: notificationId,
                quizId: quiz.id,
                subject: quiz.subject,
                title: quiz.title,
                formattedDate: formattedDue,
                note: quiz.note,
                scheduledDate: scheduledTZ,
                isDayOf: quiz.reminderType == 'morning_of' || quiz.reminderType == 'day_of',
              );
              scheduledCount++;
            }
          } catch (e) {
            failedCount++;
            debugPrint('[NotificationService] Error scheduling quiz "${quiz.title}": $e');
          }
        }
      }

      debugPrint('[NotificationService] rescheduleAll completed: scheduled=$scheduledCount, failed=$failedCount');
    } catch (e, stack) {
      debugPrint('[NotificationService] Error during rescheduleAll: $e\n$stack');
    } finally {
      _isRescheduling = false;
      if (_rescheduleQueued) {
        _rescheduleQueued = false;
        await rescheduleAll(now: now);
      }
    }
  }

  /// Computes reminder date and time for a quiz (morning-of or evening-before)
  DateTime calculateQuizReminderDateTime({
    required DateTime dueDate,
    required int reminderHour,
    required int reminderMinute,
    String? reminderType,
  }) {
    if (reminderType == 'morning_of' || reminderType == 'day_of') {
      return DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        reminderHour,
        reminderMinute,
      );
    }
    // Default to 1 day before due date (evening-before)
    return DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day - 1,
      reminderHour,
      reminderMinute,
    );
  }

  /// Computes the next occurrence of a class reminder as a TZDateTime
  tz.TZDateTime calculateNextClassReminderTZ({
    required int dayIndex, // 0 = Mon, 6 = Sun
    required String startTime, // 'HH:mm'
    required int offsetMinutes,
    DateTime? now,
  }) {
    final parts = startTime.split(':');
    final classHour = int.tryParse(parts[0]) ?? 8;
    final classMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final classTotalMinutes = classHour * 60 + classMinute;
    var reminderTotalMinutes = classTotalMinutes - offsetMinutes;
    var dayOffsetAdjustment = 0;

    if (reminderTotalMinutes < 0) {
      reminderTotalMinutes += 24 * 60;
      dayOffsetAdjustment = -1;
    }

    final reminderHour = reminderTotalMinutes ~/ 60;
    final reminderMinute = reminderTotalMinutes % 60;

    var targetWeekday = (dayIndex + 1) + dayOffsetAdjustment;
    if (targetWeekday < 1) targetWeekday += 7;
    if (targetWeekday > 7) targetWeekday -= 7;

    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
    }

    final ref = now != null
        ? (now is tz.TZDateTime
            ? now
            : tz.TZDateTime(
                tz.local,
                now.year,
                now.month,
                now.day,
                now.hour,
                now.minute,
                now.second,
                now.millisecond,
              ))
        : tz.TZDateTime.now(tz.local);

    var scheduled = tz.TZDateTime(
      tz.local,
      ref.year,
      ref.month,
      ref.day,
      reminderHour,
      reminderMinute,
      0,
    );

    while (scheduled.weekday != targetWeekday || !scheduled.isAfter(ref)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  tz.TZDateTime _toTZDateTime(DateTime dt) {
    if (dt is tz.TZDateTime) return dt;
    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
    }
    return tz.TZDateTime(
      tz.local,
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
    );
  }

  void dispose() {
    _payloadStreamController.close();
  }
}
