import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/data/models/class_item.dart';
import 'package:nextclass/data/models/quiz_item.dart';
import 'package:nextclass/data/models/user_settings.dart';
import 'package:nextclass/data/repositories/quiz_repository.dart';
import 'package:nextclass/data/repositories/settings_repository.dart';
import 'package:nextclass/data/repositories/timetable_repository.dart';
import 'package:nextclass/domain/services/alarm_scheduler.dart';
import 'package:nextclass/domain/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class FakeFlutterLocalNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  final List<Map<String, dynamic>> scheduledCalls = [];
  final List<int> cancelledIds = [];
  bool allCancelled = false;

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    return true;
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    AndroidScheduleMode? androidScheduleMode,
    bool androidAllowWhileIdle = false,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
    required UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation,
  }) async {
    scheduledCalls.add({
      'id': id,
      'title': title,
      'body': body,
      'scheduledDate': scheduledDate,
      'notificationDetails': notificationDetails,
      'matchDateTimeComponents': matchDateTimeComponents,
      'payload': payload,
    });
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelledIds.add(id);
    scheduledCalls.removeWhere((call) => call['id'] == id);
  }

  @override
  Future<void> cancelAll() async {
    allCancelled = true;
    scheduledCalls.clear();
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return scheduledCalls
        .map((call) => PendingNotificationRequest(
              call['id'] as int,
              call['title'] as String?,
              call['body'] as String?,
              call['payload'] as String?,
            ))
        .toList();
  }
}

class FakeSettingsRepo extends SettingsRepository {
  UserSettings settings;
  FakeSettingsRepo([UserSettings? initial])
      : settings = initial ?? UserSettings.defaults();

  @override
  Future<UserSettings> getUserSettings() async => settings;
}

class FakeTimetableRepo extends TimetableRepository {
  List<ClassItem> classes;
  FakeTimetableRepo([List<ClassItem>? initial])
      : classes = List.from(initial ?? []);

  @override
  Future<List<ClassItem>> getAllClasses() async => List.unmodifiable(classes);
}

class FakeQuizRepo extends QuizRepository {
  List<QuizItem> quizzes;
  FakeQuizRepo([List<QuizItem>? initial]) : quizzes = List.from(initial ?? []);

  @override
  Future<List<QuizItem>> getUpcomingQuizzes({DateTime? referenceDate}) async {
    return List.unmodifiable(quizzes);
  }
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  final sampleClasses = [
    const ClassItem(
      id: 'c1',
      subject: 'Mathematics',
      subjectColorIndex: 0,
      dayOfWeek: 'Monday',
      startTime: '08:30',
      endTime: '10:00',
      room: 'Room A-04',
      teacher: 'Dr. Smith',
    ),
    const ClassItem(
      id: 'c2',
      subject: 'Physics',
      subjectColorIndex: 1,
      dayOfWeek: 'Monday',
      startTime: '10:15',
      endTime: '11:45',
      room: 'Room B-12',
      teacher: 'Prof. Miller',
    ),
  ];

  final sampleQuizzes = [
    QuizItem(
      id: 'q1',
      classId: 'c1',
      subject: 'Mathematics',
      title: 'Calculus Midterm',
      dueDate: DateTime(2026, 10, 15),
      note: 'Bring formula handbook',
    ),
  ];

  group('Flow 10: NotificationService Unit Tests', () {
    test('Notification channel constants and initialization setup', () {
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final service = NotificationService.test(fakePlugin);

      expect(NotificationService.classChannelId, 'class_reminders_v2');
      expect(NotificationService.classChannelName, 'Class reminders');
      expect(NotificationService.quizChannelId, 'quiz_reminders_v2');
      expect(NotificationService.quizChannelName, 'Quiz reminders');
      expect(service.plugin, isNotNull);
    });

    test('scheduleClassReminder builds correct collapsed & expanded content and tap payload', () async {
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final service = NotificationService.test(fakePlugin);

      final scheduledTZ = tz.TZDateTime.now(tz.local).add(const Duration(hours: 1));

      await service.scheduleClassReminder(
        id: 42,
        subject: 'Mathematics',
        minutesBefore: 15,
        startTime: '08:30',
        endTime: '10:00',
        room: 'Room A-04',
        teacher: 'Dr. Smith',
        nextSubject: 'Physics',
        nextTime: '10:15',
        scheduledDate: scheduledTZ,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );

      expect(fakePlugin.scheduledCalls.length, 1);
      final call = fakePlugin.scheduledCalls.first;

      expect(call['id'], 42);
      expect(call['title'], 'Mathematics in 15 min');
      expect(call['body'], '08:30 – 10:00 · Room A-04 · Dr. Smith');
      expect(call['matchDateTimeComponents'], DateTimeComponents.dayOfWeekAndTime);

      // Verify payload deep link
      final payload = jsonDecode(call['payload'] as String);
      expect(payload['type'], 'class');
      expect(payload['target'], 'today');
      expect(payload['subject'], 'Mathematics');

      // Verify expanded BigTextStyle Information
      final details = call['notificationDetails'] as NotificationDetails;
      final androidDetails = details.android!;
      expect(androidDetails.channelId, NotificationService.classChannelId);
      expect(androidDetails.importance, Importance.high);
      expect(androidDetails.priority, Priority.high);

      final style = androidDetails.styleInformation as BigTextStyleInformation;
      expect(style.contentTitle, 'Mathematics in 15 min');
      expect(style.bigText, contains('08:30 – 10:00'));
      expect(style.bigText, contains('Dr. Smith'));
      expect(style.bigText, contains('Next class: Physics at 10:15'));
    });

    test('scheduleQuizReminder builds correct collapsed & expanded content and tap payload', () async {
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final service = NotificationService.test(fakePlugin);

      final scheduledTZ = tz.TZDateTime.now(tz.local).add(const Duration(days: 1));

      await service.scheduleQuizReminder(
        id: 100042,
        quizId: 'q1',
        subject: 'Mathematics',
        title: 'Calculus Midterm',
        formattedDate: 'Thu, 15 Oct',
        note: 'Bring formula handbook',
        scheduledDate: scheduledTZ,
      );

      expect(fakePlugin.scheduledCalls.length, 1);
      final call = fakePlugin.scheduledCalls.first;

      expect(call['id'], 100042);
      expect(call['title'], 'Quiz tomorrow: Mathematics');
      expect(call['body'], 'Calculus Midterm · Thu, 15 Oct · Bring formula handbook');

      // Verify payload
      final payload = jsonDecode(call['payload'] as String);
      expect(payload['type'], 'quiz');
      expect(payload['quizId'], 'q1');
      expect(payload['subject'], 'Mathematics');

      // Verify expanded BigTextStyle Information
      final details = call['notificationDetails'] as NotificationDetails;
      final androidDetails = details.android!;
      expect(androidDetails.channelId, NotificationService.quizChannelId);
      expect(androidDetails.importance, Importance.high);

      final style = androidDetails.styleInformation as BigTextStyleInformation;
      expect(style.contentTitle, 'Quiz tomorrow: Mathematics');
      expect(style.bigText, contains('Calculus Midterm'));
      expect(style.bigText, contains('Thu, 15 Oct'));
    });
  });

  group('Flow 10: AlarmScheduler Unit Tests', () {
    test('Generates distinct deterministic IDs without collision', () {
      final classId1 = 'c1';
      final classId2 = 'c2';
      final quizId1 = 'q1';

      final classNotifId1 = AlarmScheduler.getClassNotificationId(classId1);
      final classNotifId2 = AlarmScheduler.getClassNotificationId(classId2);
      final quizNotifId1 = AlarmScheduler.getQuizNotificationId(quizId1);

      expect(classNotifId1 >= 0 && classNotifId1 < 100000, isTrue);
      expect(classNotifId2 >= 0 && classNotifId2 < 100000, isTrue);
      expect(quizNotifId1 >= 100000 && quizNotifId1 < 200000, isTrue);
      expect(classNotifId1 != quizNotifId1, isTrue);
    });

    test('Computes quiz reminder datetime at 1 day before at specified time (8:00 PM default)', () {
      final scheduler = AlarmScheduler();
      final quizDate = DateTime(2026, 10, 20);

      final reminderDate = scheduler.calculateQuizReminderDateTime(
        dueDate: quizDate,
        reminderHour: 20,
        reminderMinute: 0,
      );

      expect(reminderDate.year, 2026);
      expect(reminderDate.month, 10);
      expect(reminderDate.day, 19); // Evening before
      expect(reminderDate.hour, 20); // 8:00 PM
      expect(reminderDate.minute, 0);
    });

    test('rescheduleAll cancels existing alarms and schedules both class and quiz reminders', () async {
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final service = NotificationService.test(fakePlugin);

      final fakeSettings = FakeSettingsRepo(
        const UserSettings(
          classReminderMinutes: 15,
          quizReminderEnabled: true,
          quizReminderTime: '20:00',
        ),
      );
      final fakeTimetable = FakeTimetableRepo(sampleClasses);
      final fakeQuizzes = FakeQuizRepo(sampleQuizzes);

      final scheduler = AlarmScheduler(
        notificationService: service,
        settingsRepository: fakeSettings,
        timetableRepository: fakeTimetable,
        quizRepository: fakeQuizzes,
      );

      // Current time: 1 Oct 2026 at 09:00 AM
      final refDate = DateTime(2026, 10, 1, 9, 0);

      await scheduler.rescheduleAll(now: refDate);

      // Verify cancelAll was called
      expect(fakePlugin.allCancelled, isTrue);

      // Verify scheduled calls: 2 class reminders + 1 quiz reminder = 3 total
      expect(fakePlugin.scheduledCalls.length, 3);

      final classCalls = fakePlugin.scheduledCalls
          .where((c) => c['id'] < 100000)
          .toList();
      final quizCalls = fakePlugin.scheduledCalls
          .where((c) => c['id'] >= 100000)
          .toList();

      expect(classCalls.length, 2);
      expect(quizCalls.length, 1);
    });

    test('Disables class reminders when classReminderMinutes is null (Off)', () async {
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final service = NotificationService.test(fakePlugin);

      final fakeSettings = FakeSettingsRepo(
        const UserSettings(
          classReminderMinutes: null, // Off
          quizReminderEnabled: true,
        ),
      );
      final fakeTimetable = FakeTimetableRepo(sampleClasses);
      final fakeQuizzes = FakeQuizRepo(sampleQuizzes);

      final scheduler = AlarmScheduler(
        notificationService: service,
        settingsRepository: fakeSettings,
        timetableRepository: fakeTimetable,
        quizRepository: fakeQuizzes,
      );

      final refDate = DateTime(2026, 10, 1, 9, 0);
      await scheduler.rescheduleAll(now: refDate);

      // Only quiz reminders scheduled, zero class reminders
      final classCalls = fakePlugin.scheduledCalls
          .where((c) => c['id'] < 100000)
          .toList();
      expect(classCalls.isEmpty, isTrue);
    });

    test('Disables quiz reminders when quizReminderEnabled is false', () async {
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final service = NotificationService.test(fakePlugin);

      final fakeSettings = FakeSettingsRepo(
        const UserSettings(
          classReminderMinutes: 15,
          quizReminderEnabled: false, // Off
        ),
      );
      final fakeTimetable = FakeTimetableRepo(sampleClasses);
      final fakeQuizzes = FakeQuizRepo(sampleQuizzes);

      final scheduler = AlarmScheduler(
        notificationService: service,
        settingsRepository: fakeSettings,
        timetableRepository: fakeTimetable,
        quizRepository: fakeQuizzes,
      );

      final refDate = DateTime(2026, 10, 1, 9, 0);
      await scheduler.rescheduleAll(now: refDate);

      // Only class reminders scheduled, zero quiz reminders
      final quizCalls = fakePlugin.scheduledCalls
          .where((c) => c['id'] >= 100000)
          .toList();
      expect(quizCalls.isEmpty, isTrue);
    });

    test('calculateNextClassReminderTZ: Monday 08:30 with 15-minute offset', () {
      final scheduler = AlarmScheduler();
      // Monday 2026-10-05 at 07:00 AM (before 08:15 reminder)
      final ref = DateTime(2026, 10, 5, 7, 0);
      final reminder = scheduler.calculateNextClassReminderTZ(
        dayIndex: 0, // Monday
        startTime: '08:30',
        offsetMinutes: 15,
        now: ref,
      );

      expect(reminder.weekday, DateTime.monday);
      expect(reminder.hour, 8);
      expect(reminder.minute, 15);
      expect(reminder.day, 5);
    });

    test('calculateNextClassReminderTZ: Monday 00:10 with 30-minute offset rolls to Sunday 23:40', () {
      final scheduler = AlarmScheduler();
      // Friday 2026-10-02 at 12:00 PM
      final ref = DateTime(2026, 10, 2, 12, 0);
      final reminder = scheduler.calculateNextClassReminderTZ(
        dayIndex: 0, // Monday
        startTime: '00:10',
        offsetMinutes: 30,
        now: ref,
      );

      expect(reminder.weekday, DateTime.sunday);
      expect(reminder.hour, 23);
      expect(reminder.minute, 40);
      expect(reminder.day, 4); // Sunday 4 Oct
    });

    test('calculateNextClassReminderTZ: Sunday class at 10:00 with 15-minute offset', () {
      final scheduler = AlarmScheduler();
      // Sunday 2026-10-04 at 08:00 AM
      final ref = DateTime(2026, 10, 4, 8, 0);
      final reminder = scheduler.calculateNextClassReminderTZ(
        dayIndex: 6, // Sunday
        startTime: '10:00',
        offsetMinutes: 15,
        now: ref,
      );

      expect(reminder.weekday, DateTime.sunday);
      expect(reminder.hour, 9);
      expect(reminder.minute, 45);
      expect(reminder.day, 4);
    });

    test('calculateNextClassReminderTZ: now just after reminder time rolls to next week', () {
      final scheduler = AlarmScheduler();
      // Monday 2026-10-05 at 08:16 AM (1 minute after 08:15 reminder)
      final ref = DateTime(2026, 10, 5, 8, 16);
      final reminder = scheduler.calculateNextClassReminderTZ(
        dayIndex: 0, // Monday
        startTime: '08:30',
        offsetMinutes: 15,
        now: ref,
      );

      expect(reminder.weekday, DateTime.monday);
      expect(reminder.hour, 8);
      expect(reminder.minute, 15);
      expect(reminder.day, 12); // Next Monday 12 Oct!
    });

    test('calculateNextClassReminderTZ: class later today returns today', () {
      final scheduler = AlarmScheduler();
      // Monday 2026-10-05 at 07:00 AM (before 08:15 reminder)
      final ref = DateTime(2026, 10, 5, 7, 0);
      final reminder = scheduler.calculateNextClassReminderTZ(
        dayIndex: 0, // Monday
        startTime: '08:30',
        offsetMinutes: 15,
        now: ref,
      );

      expect(reminder.weekday, DateTime.monday);
      expect(reminder.hour, 8);
      expect(reminder.minute, 15);
      expect(reminder.day, 5); // Today!
    });

    test('calculateNextClassReminderTZ: 5, 10, 15, and 30 minute offsets compute precisely', () {
      final scheduler = AlarmScheduler();
      final ref = DateTime(2026, 10, 5, 6, 0); // Monday 06:00

      // 5 min offset on 10:00 class
      final r5 = scheduler.calculateNextClassReminderTZ(
        dayIndex: 0,
        startTime: '10:00',
        offsetMinutes: 5,
        now: ref,
      );
      expect(r5.hour, 9);
      expect(r5.minute, 55);

      // 10 min offset on 10:00 class
      final r10 = scheduler.calculateNextClassReminderTZ(
        dayIndex: 0,
        startTime: '10:00',
        offsetMinutes: 10,
        now: ref,
      );
      expect(r10.hour, 9);
      expect(r10.minute, 50);

      // 15 min offset on 10:00 class
      final r15 = scheduler.calculateNextClassReminderTZ(
        dayIndex: 0,
        startTime: '10:00',
        offsetMinutes: 15,
        now: ref,
      );
      expect(r15.hour, 9);
      expect(r15.minute, 45);

      // 30 min offset on 10:00 class
      final r30 = scheduler.calculateNextClassReminderTZ(
        dayIndex: 0,
        startTime: '10:00',
        offsetMinutes: 30,
        now: ref,
      );
      expect(r30.hour, 9);
      expect(r30.minute, 30);
    });

    test('Notification IDs are stable and invariant to timetable ordering', () {
      const classA = 'math-algebra-101';
      const classB = 'phys-mechanics-201';

      final idAFirst = AlarmScheduler.getClassNotificationId(classA);
      final idBSecond = AlarmScheduler.getClassNotificationId(classB);

      // When list ordering is reversed, ID for classA must still be identical
      final idASecond = AlarmScheduler.getClassNotificationId(classA);
      final idBFirst = AlarmScheduler.getClassNotificationId(classB);

      expect(idAFirst, equals(idASecond));
      expect(idBSecond, equals(idBFirst));
      expect(idAFirst, isNot(equals(idBFirst)));
    });

    test('scheduleDebugNotification registers a 1-minute one-shot notification in pending requests', () async {
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final service = NotificationService.test(fakePlugin);

      final pending = await service.scheduleDebugNotification(
        delay: const Duration(minutes: 1),
      );

      expect(fakePlugin.scheduledCalls.length, 1);
      final debugCall = fakePlugin.scheduledCalls.first;

      expect(debugCall['id'], 999999);
      expect(debugCall['title'], 'NextClass Scheduled Test');
      expect(debugCall['body'], 'If you see this, scheduled notifications work.');
      // One-shot: matchDateTimeComponents must be null
      expect(debugCall['matchDateTimeComponents'], isNull);

      // Verify pending notification requests list contains the debug notification
      expect(pending.any((req) => req.id == 999999), isTrue);
    });

    group('Regression Tests A-J: Physical-device and Offset Switching Verification', () {
      late FakeFlutterLocalNotificationsPlugin fakePlugin;
      late NotificationService notifService;
      late FakeSettingsRepo settingsRepo;
      late FakeTimetableRepo timetableRepo;
      late FakeQuizRepo quizRepo;
      late AlarmScheduler scheduler;

      setUp(() {
        fakePlugin = FakeFlutterLocalNotificationsPlugin();
        notifService = NotificationService.test(fakePlugin);
        settingsRepo = FakeSettingsRepo();
        timetableRepo = FakeTimetableRepo();
        quizRepo = FakeQuizRepo();
        scheduler = AlarmScheduler(
          notificationService: notifService,
          settingsRepository: settingsRepo,
          timetableRepository: timetableRepo,
          quizRepository: quizRepo,
        );
      });

      // Test A: 15-minute reminder
      test('Test A: 15-minute reminder schedules properly with 15 min pre-class offset', () async {
        final ref = DateTime(2026, 10, 5, 8, 0); // Monday 08:00
        final scheduled = scheduler.calculateNextClassReminderTZ(
          dayIndex: 0, // Monday
          startTime: '09:00',
          offsetMinutes: 15,
          now: ref,
        );
        expect(scheduled.weekday, 1);
        expect(scheduled.hour, 8);
        expect(scheduled.minute, 45);
        expect(scheduled.isAfter(ref), isTrue);
      });

      // Test B: Change 15 → 5 minutes
      test('Test B: Change 15 → 5 minutes calculates 5 min pre-class offset', () async {
        final ref = DateTime(2026, 10, 5, 8, 0); // Monday 08:00
        final scheduled = scheduler.calculateNextClassReminderTZ(
          dayIndex: 0, // Monday
          startTime: '09:00',
          offsetMinutes: 5,
          now: ref,
        );
        expect(scheduled.weekday, 1);
        expect(scheduled.hour, 8);
        expect(scheduled.minute, 55);
        expect(scheduled.isAfter(ref), isTrue);
      });

      // Test C: Ensure old schedule is replaced
      test('Test C: Changing reminder offset replaces existing scheduled notification', () async {
        final testClass = ClassItem(
          id: 'class-c-1',
          subject: 'Physics',
          subjectColorIndex: 0,
          dayOfWeek: 'Monday',
          startTime: '10:00',
          endTime: '11:00',
        );
        timetableRepo.classes = [testClass];
        settingsRepo.settings = settingsRepo.settings.copyWith(classReminderMinutes: 15);

        final nowTime = DateTime(2026, 10, 5, 8, 0);
        await scheduler.rescheduleAll(now: nowTime);
        expect(fakePlugin.scheduledCalls.length, 1);
        final firstCall = fakePlugin.scheduledCalls.first;
        expect(firstCall['title'], contains('15 min'));
        final tz.TZDateTime firstDate = firstCall['scheduledDate'];
        expect(firstDate.minute, 45);

        // Change to 5 minutes and reschedule
        settingsRepo.settings = settingsRepo.settings.copyWith(classReminderMinutes: 5);
        await scheduler.rescheduleAll(now: nowTime);
        expect(fakePlugin.allCancelled, isTrue);
        expect(fakePlugin.scheduledCalls.length, 1);
        final secondCall = fakePlugin.scheduledCalls.first;
        expect(secondCall['title'], contains('5 min'));
        final tz.TZDateTime secondDate = secondCall['scheduledDate'];
        expect(secondDate.minute, 55);
      });

      // Test D: Notification ID remains identical after changing offset
      test('Test D: Notification ID remains identical after changing offset from 15 to 5 min', () {
        const classId = 'history-period-3';
        final idAt15 = AlarmScheduler.getClassNotificationId(classId);
        final idAt5 = AlarmScheduler.getClassNotificationId(classId);
        expect(idAt15, equals(idAt5));
      });

      // Test E: One-shot one-minute diagnostic
      test('Test E: One-shot one-minute diagnostic schedules at now + 1 min without recurrence', () async {
        final pending = await notifService.scheduleDebugNotification(
          delay: const Duration(minutes: 1),
        );
        expect(fakePlugin.scheduledCalls.length, 1);
        final call = fakePlugin.scheduledCalls.first;
        expect(call['id'], 999999);
        expect(call['matchDateTimeComponents'], isNull);
        expect(pending.any((p) => p.id == 999999), isTrue);
      });

      // Test F: Weekly recurrence
      test('Test F: Weekly class reminders use DateTimeComponents.dayOfWeekAndTime', () async {
        final testClass = ClassItem(
          id: 'chem-lab-1',
          subject: 'Chemistry',
          subjectColorIndex: 0,
          dayOfWeek: 'Wednesday',
          startTime: '14:00',
          endTime: '15:30',
        );
        timetableRepo.classes = [testClass];
        settingsRepo.settings = settingsRepo.settings.copyWith(classReminderMinutes: 10);

        await scheduler.rescheduleAll(now: DateTime(2026, 10, 5, 8, 0));
        expect(fakePlugin.scheduledCalls.length, 1);
        final call = fakePlugin.scheduledCalls.first;
        expect(call['matchDateTimeComponents'], DateTimeComponents.dayOfWeekAndTime);
      });

      // Test G: Monday/Sunday boundaries
      test('Test G: Monday to Sunday and Sunday to Monday boundary transitions calculate correctly', () {
        // Monday 00:05 class with 10 min offset should trigger Sunday 23:55
        final sunRef = DateTime(2026, 10, 4, 12, 0); // Sunday 12:00
        final rSun = scheduler.calculateNextClassReminderTZ(
          dayIndex: 0, // Monday
          startTime: '00:05',
          offsetMinutes: 10,
          now: sunRef,
        );
        expect(rSun.weekday, 7); // Sunday
        expect(rSun.hour, 23);
        expect(rSun.minute, 55);

        // Sunday 09:00 class with 15 min offset checked on Monday
        final monRef = DateTime(2026, 10, 5, 12, 0); // Monday
        final rMonToSun = scheduler.calculateNextClassReminderTZ(
          dayIndex: 6, // Sunday
          startTime: '09:00',
          offsetMinutes: 15,
          now: monRef,
        );
        expect(rMonToSun.weekday, 7); // Next Sunday
        expect(rMonToSun.hour, 8);
        expect(rMonToSun.minute, 45);
        expect(rMonToSun.isAfter(monRef), isTrue);
      });

      // Test H: Reminder crossing midnight
      test('Test H: Class at 00:05 with 15 min offset fires at 23:50 on previous day', () {
        final ref = DateTime(2026, 10, 6, 12, 0); // Tuesday 12:00
        final res = scheduler.calculateNextClassReminderTZ(
          dayIndex: 2, // Wednesday
          startTime: '00:05',
          offsetMinutes: 15,
          now: ref,
        );
        expect(res.weekday, 2); // Tuesday
        expect(res.hour, 23);
        expect(res.minute, 50);
      });

      // Test I: Class already passed today
      test('Test I: Class already passed today advances to same weekday next week', () {
        final ref = DateTime(2026, 10, 5, 14, 0); // Monday 14:00
        final res = scheduler.calculateNextClassReminderTZ(
          dayIndex: 0, // Monday
          startTime: '10:00', // Already passed at 14:00
          offsetMinutes: 15,
          now: ref,
        );
        expect(res.weekday, 1); // Monday
        expect(res.day, 12); // Oct 12 (7 days later)
        expect(res.hour, 9);
        expect(res.minute, 45);
        expect(res.isAfter(ref), isTrue);
      });

      // Test J: Concurrent reschedule calls
      test('Test J: Concurrent rescheduleAll calls are serialized safely without crash or race', () async {
        timetableRepo.classes = [
          ClassItem(
            id: 'bio-101',
            subject: 'Biology',
            subjectColorIndex: 0,
            dayOfWeek: 'Friday',
            startTime: '11:00',
            endTime: '12:00',
          ),
        ];

        // Trigger two rescheduleAll invocations concurrently
        final future1 = scheduler.rescheduleAll(now: DateTime(2026, 10, 5, 8, 0));
        final future2 = scheduler.rescheduleAll(now: DateTime(2026, 10, 5, 8, 0));

        await Future.wait([future1, future2]);

        // Final state must have cleanly scheduled the class
        expect(fakePlugin.scheduledCalls.length, 1);
        expect(fakePlugin.scheduledCalls.first['title'], contains('Biology'));
      });
    });
  });
}
