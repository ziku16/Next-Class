import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_init;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/class_item.dart';
import '../../data/models/quiz_item.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/timetable_repository.dart';
import 'notification_service.dart';

/// Central background alarm scheduler for NextClass (Flow 9 / Phase 10).
/// Enforces:
/// - Weekly recurring class reminders with pre-class offset and "Next class" preview
/// - Evening-before quiz alarms scheduled at user's chosen reminder time (default 8:00 PM)
/// - Deterministic notification IDs with zero collision
/// - Complete alarm rebuilding across app lifecycles, edits, and reboots
class AlarmScheduler {
  final NotificationService _notificationService;
  final TimetableRepository _timetableRepo;
  final QuizRepository _quizRepo;
  final SettingsRepository _settingsRepo;

  AlarmScheduler({
    NotificationService? notificationService,
    TimetableRepository? timetableRepository,
    QuizRepository? quizRepository,
    SettingsRepository? settingsRepository,
  })  : _notificationService = notificationService ?? NotificationService(),
        _timetableRepo = timetableRepository ?? TimetableRepository(),
        _quizRepo = quizRepository ?? QuizRepository(),
        _settingsRepo = settingsRepository ?? SettingsRepository();

  /// Deterministic ID generator for class notification (0 - 99,999).
  /// Uses index if provided to guarantee 0 collision, or 32-bit FNV-1a hash of classId.
  static int getClassNotificationId(String classId, [int? index]) {
    if (index != null) {
      return index % 100000;
    }
    int hash = 0x811c9dc5;
    for (int i = 0; i < classId.length; i++) {
      hash ^= classId.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash % 100000;
  }

  /// Deterministic ID generator for quiz notification (100,000 - 199,999).
  /// Uses index if provided to guarantee 0 collision, or 100,000 + 32-bit FNV-1a hash of quizId.
  static int getQuizNotificationId(String quizId, [int? index]) {
    if (index != null) {
      return 100000 + (index % 100000);
    }
    int hash = 0x811c9dc5;
    for (int i = 0; i < quizId.length; i++) {
      hash ^= quizId.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return 100000 + (hash % 100000);
  }

  /// Reschedules all class and quiz reminders according to current database state and settings.
  /// Called on:
  /// - Timetable replacement / review save
  /// - Quiz add / edit / delete
  /// - Reminder preferences changes in Settings
  /// - Device reboot
  Future<void> rescheduleAll({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    try {
      tz.local;
    } catch (_) {
      tz_init.initializeTimeZones();
    }
    debugPrint('[AlarmScheduler] Starting rescheduleAll at $currentTime. Active timezone: ${tz.local.name}');

    try {
      await _notificationService.initialize();

      // Retrieve latest state
      final settings = await _settingsRepo.getUserSettings();
      final classes = await _timetableRepo.getAllClasses();
      final quizzes = await _quizRepo.getUpcomingQuizzes(referenceDate: currentTime);

      // Cancel all existing scheduled notifications first to prevent stale alarms
      await _notificationService.cancelAll();

      int scheduledCount = 0;
      int failedCount = 0;
      final List<String> failures = [];

      // Schedule class reminders with individual error catching
      final classResult = await scheduleClassReminders(
        classes: classes,
        settings: settings,
        now: currentTime,
      );
      scheduledCount += classResult.scheduled;
      failedCount += classResult.failed;
      failures.addAll(classResult.errors);

      // Schedule quiz reminders with individual error catching
      final quizResult = await scheduleQuizReminders(
        quizzes: quizzes,
        settings: settings,
        now: currentTime,
      );
      scheduledCount += quizResult.scheduled;
      failedCount += quizResult.failed;
      failures.addAll(quizResult.errors);

      debugPrint(
        '[AlarmScheduler] rescheduleAll summary: scheduled=$scheduledCount, failed=$failedCount. ${failures.isNotEmpty ? "Errors: $failures" : "All alarms scheduled clean."}',
      );
    } catch (e, stack) {
      debugPrint('[AlarmScheduler] CRITICAL failure in rescheduleAll: $e\n$stack');
    }
  }

  /// Schedules pre-class reminders for all weekly timetable classes
  Future<ScheduleResult> scheduleClassReminders({
    required List<ClassItem> classes,
    required UserSettings settings,
    DateTime? now,
  }) async {
    final offsetMinutes = settings.classReminderMinutes;
    if (offsetMinutes == null || offsetMinutes <= 0) {
      debugPrint('[AlarmScheduler] Class reminders disabled (offset=$offsetMinutes).');
      return ScheduleResult(scheduled: 0, failed: 0, errors: []);
    }

    final ref = now ?? DateTime.now();
    int scheduled = 0;
    int failed = 0;
    final List<String> errors = [];

    // Group classes by day to compute "Next class after this"
    final Map<String, List<ClassItem>> dayGroups = {};
    for (final c in classes) {
      dayGroups.putIfAbsent(c.dayOfWeek, () => []).add(c);
    }
    for (final dayList in dayGroups.values) {
      dayList.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    }

    for (int i = 0; i < classes.length; i++) {
      final classItem = classes[i];
      try {
        // Find the subsequent class on the same day if available
        final sameDayClasses = dayGroups[classItem.dayOfWeek] ?? [];
        final currentIndex =
            sameDayClasses.indexWhere((c) => c.id == classItem.id);
        final ClassItem? nextClass = (currentIndex != -1 &&
                currentIndex + 1 < sameDayClasses.length)
            ? sameDayClasses[currentIndex + 1]
            : null;

        final notificationId = getClassNotificationId(classItem.id, i);

        final scheduledTZ = calculateNextClassReminderTZ(
          dayIndex: classItem.dayIndex,
          startTime: classItem.startTime,
          offsetMinutes: offsetMinutes,
          now: ref,
        );

        debugPrint(
          '[AlarmScheduler] Scheduling class alarm: id=$notificationId, subject="${classItem.subject}", scheduledTZ=$scheduledTZ',
        );

        await _notificationService.scheduleClassReminder(
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
        scheduled++;
      } catch (e) {
        failed++;
        final err = 'Class "${classItem.subject}" (id=${classItem.id}): $e';
        errors.add(err);
        debugPrint('[AlarmScheduler] Error scheduling $err');
      }
    }

    return ScheduleResult(scheduled: scheduled, failed: failed, errors: errors);
  }

  /// Schedules evening-before reminders for upcoming quizzes
  Future<ScheduleResult> scheduleQuizReminders({
    required List<QuizItem> quizzes,
    required UserSettings settings,
    DateTime? now,
  }) async {
    if (!settings.quizReminderEnabled) {
      debugPrint('[AlarmScheduler] Quiz reminders disabled in settings.');
      return ScheduleResult(scheduled: 0, failed: 0, errors: []);
    }

    final ref = now ?? DateTime.now();
    int scheduled = 0;
    int failed = 0;
    final List<String> errors = [];

    final parts = settings.quizReminderTime.split(':');
    final defaultHour = int.tryParse(parts[0]) ?? 20;
    final defaultMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    for (int i = 0; i < quizzes.length; i++) {
      final quiz = quizzes[i];
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

        // Only schedule if reminder is in the future
        if (reminderDateTime.isAfter(ref)) {
          final notificationId = getQuizNotificationId(quiz.id, i);
          final scheduledTZ = _toTZDateTime(reminderDateTime);
          final formattedDue = DateFormat('EEE, d MMM').format(quiz.dueDate);

          debugPrint(
            '[AlarmScheduler] Scheduling quiz alarm: id=$notificationId, subject="${quiz.subject}", scheduledTZ=$scheduledTZ',
          );

          await _notificationService.scheduleQuizReminder(
            id: notificationId,
            quizId: quiz.id,
            subject: quiz.subject,
            title: quiz.title,
            formattedDate: formattedDue,
            note: quiz.note,
            scheduledDate: scheduledTZ,
            isDayOf: quiz.reminderType == 'morning_of' ||
                quiz.reminderType == 'day_of',
          );
          scheduled++;
        }
      } catch (e) {
        failed++;
        final err = 'Quiz "${quiz.title}" (id=${quiz.id}): $e';
        errors.add(err);
        debugPrint('[AlarmScheduler] Error scheduling $err');
      }
    }

    return ScheduleResult(scheduled: scheduled, failed: failed, errors: errors);
  }

  /// Cancels reminder for a specific class
  Future<void> cancelClassReminder(String classId) async {
    final id = getClassNotificationId(classId);
    await _notificationService.cancel(id);
  }

  /// Cancels reminder for a specific quiz
  Future<void> cancelQuizReminder(String quizId) async {
    final id = getQuizNotificationId(quizId);
    await _notificationService.cancel(id);
  }

  /// Cancels all scheduled alarms
  Future<void> cancelAll() async {
    await _notificationService.cancelAll();
  }

  // --- Date / Time Computations ---

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

    // Class start in total minutes from midnight
    final classTotalMinutes = classHour * 60 + classMinute;
    // Reminder time in minutes from midnight
    var reminderTotalMinutes = classTotalMinutes - offsetMinutes;
    var dayOffsetAdjustment = 0;

    if (reminderTotalMinutes < 0) {
      reminderTotalMinutes += 24 * 60;
      dayOffsetAdjustment = -1; // Fires the previous calendar day
    }

    final reminderHour = reminderTotalMinutes ~/ 60;
    final reminderMinute = reminderTotalMinutes % 60;

    // Convert dayIndex (0 = Mon .. 6 = Sun) to DateTime weekday (1 = Mon .. 7 = Sun)
    var targetWeekday = (dayIndex + 1) + dayOffsetAdjustment;
    if (targetWeekday < 1) targetWeekday += 7;
    if (targetWeekday > 7) targetWeekday -= 7;

    final ref = now ?? DateTime.now();
    var scheduled = DateTime(
      ref.year,
      ref.month,
      ref.day,
      reminderHour,
      reminderMinute,
    );

    // Advance to target weekday
    while (scheduled.weekday != targetWeekday || scheduled.isBefore(ref)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return _toTZDateTime(scheduled);
  }

  /// Converts a standard DateTime to tz.TZDateTime using tz.local (no silent UTC fallback).
  tz.TZDateTime _toTZDateTime(DateTime dt) {
    try {
      tz.local;
    } catch (_) {
      tz_init.initializeTimeZones();
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
}

/// Helper class to track scheduling success/failure details
class ScheduleResult {
  final int scheduled;
  final int failed;
  final List<String> errors;

  const ScheduleResult({
    required this.scheduled,
    required this.failed,
    required this.errors,
  });
}
