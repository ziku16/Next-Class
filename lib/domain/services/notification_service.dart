import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Notification management service for NextClass (Flow 9 / Phase 10).
/// Handles:
/// - Plugin initialization for Android & iOS
/// - Channel 1: `class_reminders` (High importance, collapsed & expanded BigTextStyle)
/// - Channel 2: `quiz_reminders` (High importance, evening-before alert)
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

  // --- Notification Channel Constants ---

  static const String classChannelId = 'class_reminders';
  static const String classChannelName = 'Class reminders';
  static const String classChannelDescription =
      'Notifications sent before each class';

  static const String quizChannelId = 'quiz_reminders';
  static const String quizChannelName = 'Quiz reminders';
  static const String quizChannelDescription =
      'Notifications sent the evening before upcoming quizzes';

  /// Initializes timezone data and local notifications plugin
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
    } catch (_) {
      // Timezone data already initialized
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

      // Create Android Notification Channels
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

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService initialization skipped/failed: $e');
      }
    }
  }

  /// Requests notification permissions on Android 13+ and iOS
  Future<bool> requestPermissions() async {
    final androidPlatform = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlatform != null) {
      final granted = await androidPlatform.requestNotificationsPermission();
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

  /// Checks if exact alarms are permitted (Android 12+)
  Future<bool> checkExactAlarmPermission() async {
    final androidPlatform = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlatform != null) {
      final canSchedule = await androidPlatform.canScheduleExactNotifications();
      return canSchedule ?? true;
    }
    return true;
  }

  /// Schedules or displays a Class Reminder on the `class_reminders` channel
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
    // Collapsed Content
    final roomSuffix = (room != null && room.isNotEmpty) ? ' · Room $room' : '';
    final collapsedBody = '$subject in $minutesBefore min$roomSuffix';

    // Expanded Content (BigTextStyle)
    final teacherSuffix =
        (teacher != null && teacher.isNotEmpty) ? ' · $teacher' : '';
    final nextClassSuffix = (nextSubject != null && nextTime != null)
        ? '\nNext after this: $nextSubject at $nextTime'
        : '';
    final bigText =
        '$startTime – $endTime$teacherSuffix$nextClassSuffix';

    final bigTextStyle = BigTextStyleInformation(
      bigText,
      htmlFormatBigText: false,
      contentTitle: '$subject in $minutesBefore min$roomSuffix',
      htmlFormatContentTitle: false,
      summaryText: 'Class in $minutesBefore min',
      htmlFormatSummaryText: false,
    );

    final androidDetails = AndroidNotificationDetails(
      classChannelId,
      classChannelName,
      channelDescription: classChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
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

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        'Next Class: $subject',
        collapsedBody,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to schedule class notification ($id): $e');
      }
    }
  }

  /// Schedules a Quiz Reminder on the `quiz_reminders` channel
  Future<void> scheduleQuizReminder({
    required int id,
    required String quizId,
    required String subject,
    required String title,
    required String formattedDate,
    String? note,
    required tz.TZDateTime scheduledDate,
  }) async {
    // Collapsed Content
    final collapsedTitle = 'Quiz tomorrow: $subject';
    final collapsedBody = 'Quiz tomorrow: $subject — $title';

    // Expanded Content
    final noteSuffix = (note != null && note.isNotEmpty) ? ' · $note' : '';
    final bigText = '$formattedDate$noteSuffix | Chalo, revise tonight!';

    final bigTextStyle = BigTextStyleInformation(
      bigText,
      htmlFormatBigText: false,
      contentTitle: 'Quiz tomorrow: $subject — $title',
      htmlFormatContentTitle: false,
      summaryText: 'Quiz Tomorrow',
      htmlFormatSummaryText: false,
    );

    final androidDetails = AndroidNotificationDetails(
      quizChannelId,
      quizChannelName,
      channelDescription: quizChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
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

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        collapsedTitle,
        collapsedBody,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to schedule quiz notification ($id): $e');
      }
    }
  }

  /// Cancels an individual notification by ID
  Future<void> cancel(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (_) {}
  }

  /// Cancels all scheduled notifications
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }

  void dispose() {
    _payloadStreamController.close();
  }
}
