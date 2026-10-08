import 'package:timezone/timezone.dart' as tz;

import '../../data/models/class_item.dart';
import '../../data/models/quiz_item.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/timetable_repository.dart';
import 'notification_service.dart';

/// Legacy adapter for AlarmScheduler.
///
/// NOTE: The custom AlarmScheduler abstraction has been simplified and folded
/// directly into [NotificationService]. All application calls should use
/// [NotificationService().rescheduleAll()] directly.
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

  static int getClassNotificationId(String classId, [int? index]) =>
      NotificationService.getClassNotificationId(classId, index);

  static int getQuizNotificationId(String quizId, [int? index]) =>
      NotificationService.getQuizNotificationId(quizId, index);

  Future<void> rescheduleAll({DateTime? now}) async {
    await _notificationService.rescheduleAll(
      now: now,
      timetableRepo: _timetableRepo,
      quizRepo: _quizRepo,
      settingsRepo: _settingsRepo,
    );
  }

  Future<ScheduleResult> scheduleClassReminders({
    required List<ClassItem> classes,
    required UserSettings settings,
    DateTime? now,
  }) async {
    await _notificationService.rescheduleAll(
      now: now,
      classes: classes,
      quizzes: [],
      settings: settings,
    );
    return ScheduleResult(
      scheduled: settings.classReminderMinutes != null && settings.classReminderMinutes! > 0 ? classes.length : 0,
      failed: 0,
      errors: [],
    );
  }

  Future<ScheduleResult> scheduleQuizReminders({
    required List<QuizItem> quizzes,
    required UserSettings settings,
    DateTime? now,
  }) async {
    await _notificationService.rescheduleAll(
      now: now,
      classes: [],
      quizzes: quizzes,
      settings: settings,
    );
    return ScheduleResult(
      scheduled: settings.quizReminderEnabled ? quizzes.where((q) => !q.isCompleted).length : 0,
      failed: 0,
      errors: [],
    );
  }

  Future<void> cancelClassReminder(String classId) async {
    await _notificationService.cancelClassReminder(classId);
  }

  Future<void> cancelQuizReminder(String quizId) async {
    await _notificationService.cancelQuizReminder(quizId);
  }

  Future<void> cancelAll() async {
    await _notificationService.cancelAll();
  }

  DateTime calculateQuizReminderDateTime({
    required DateTime dueDate,
    required int reminderHour,
    required int reminderMinute,
    String? reminderType,
  }) =>
      _notificationService.calculateQuizReminderDateTime(
        dueDate: dueDate,
        reminderHour: reminderHour,
        reminderMinute: reminderMinute,
        reminderType: reminderType,
      );

  tz.TZDateTime calculateNextClassReminderTZ({
    required int dayIndex,
    required String startTime,
    required int offsetMinutes,
    DateTime? now,
  }) =>
      _notificationService.calculateNextClassReminderTZ(
        dayIndex: dayIndex,
        startTime: startTime,
        offsetMinutes: offsetMinutes,
        now: now,
      );
}

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
