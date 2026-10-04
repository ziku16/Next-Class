import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nextclass/data/database/app_database.dart';
import 'package:nextclass/data/models/class_item.dart';
import 'package:nextclass/data/models/quiz_item.dart';
import 'package:nextclass/data/models/scan_quota.dart';
import 'package:nextclass/data/models/user_settings.dart';
import 'package:nextclass/data/repositories/timetable_repository.dart';
import 'package:nextclass/data/repositories/quiz_repository.dart';
import 'package:nextclass/data/repositories/settings_repository.dart';

void main() {
  // Initialize ffi for sqlite on desktop/linux unit tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('ClassItem Model Tests', () {
    test('Calculates start and end minutes properly', () {
      const item = ClassItem(
        id: '1',
        subject: 'Mathematics',
        subjectColorIndex: 0,
        dayOfWeek: 'Monday',
        startTime: '09:30',
        endTime: '10:20',
        room: 'B-12',
      );

      expect(item.startMinutes, 9 * 60 + 30); // 570
      expect(item.endMinutes, 10 * 60 + 20); // 620
      expect(item.durationInMinutes, 50);
      expect(item.isValidTime, isTrue);
      expect(item.dayIndex, 0); // Monday
    });

    test('Detects invalid time (end before start)', () {
      const item = ClassItem(
        id: '1',
        subject: 'Physics',
        subjectColorIndex: 1,
        dayOfWeek: 'Tuesday',
        startTime: '10:30',
        endTime: '09:30',
      );

      expect(item.isValidTime, isFalse);
    });

    test('Serialization to/from Map preserves all attributes', () {
      const item = ClassItem(
        id: 'c1',
        subject: 'Chemistry Lab',
        subjectColorIndex: 2,
        dayOfWeek: 'Thursday',
        startTime: '11:00',
        endTime: '12:40',
        room: 'Lab 2',
        teacher: 'Ms. Sara',
        isAiUnsure: true,
      );

      final map = item.toMap();
      final reconstructed = ClassItem.fromMap(map);

      expect(reconstructed, equals(item));
      expect(reconstructed.isAiUnsure, isTrue);
    });
  });

  group('QuizItem Model Tests', () {
    final refDate = DateTime(2026, 10, 2);

    test('Correctly computes daysUntilDue and urgencyCategory', () {
      final quizToday = QuizItem(
        id: 'q1',
        classId: 'c1',
        subject: 'Physics',
        title: 'Unit 3',
        dueDate: DateTime(2026, 10, 2, 11, 0),
      );

      final quizTomorrow = QuizItem(
        id: 'q2',
        classId: 'c1',
        subject: 'Chemistry',
        title: 'Ch. 4–5',
        dueDate: DateTime(2026, 10, 3, 9, 30),
      );

      final quizThisWeek = QuizItem(
        id: 'q3',
        classId: 'c1',
        subject: 'Mathematics',
        title: 'Integration Test',
        dueDate: DateTime(2026, 10, 7, 10, 0),
      );

      final quizLater = QuizItem(
        id: 'q4',
        classId: 'c1',
        subject: 'English',
        title: 'Essay Outline',
        dueDate: DateTime(2026, 10, 17, 8, 30),
      );

      expect(quizToday.urgencyCategory(refDate), QuizUrgency.today);
      expect(quizToday.urgencyBadgeText(refDate), 'Today');

      expect(quizTomorrow.urgencyCategory(refDate), QuizUrgency.tomorrow);
      expect(quizTomorrow.urgencyBadgeText(refDate), 'Tomorrow');

      expect(quizThisWeek.urgencyCategory(refDate), QuizUrgency.thisWeek);
      expect(quizThisWeek.urgencyBadgeText(refDate), '5 days left');

      expect(quizLater.urgencyCategory(refDate), QuizUrgency.later);
      expect(quizLater.urgencyBadgeText(refDate), '15 days left');
    });
  });

  group('ScanQuota Model Tests', () {
    test('Tracks quota properly and enforces daily/weekly limits', () {
      final baseDate = DateTime(2026, 10, 6, 10, 0); // Tuesday
      var quota = ScanQuota(
        dailyScansUsed: 0,
        lastDailyReset: baseDate,
        weeklyScansUsed: 0,
        lastWeeklyReset: DateTime(2026, 10, 5), // Monday
      );

      expect(quota.canScan(now: baseDate), isTrue);
      expect(quota.dailyScansLeft, 2);
      expect(quota.weeklyScansLeft, 3);
      expect(quota.quotaLabel, '2 of 2 left today · 3 of 3 this week');

      // Consume first scan
      quota = quota.consumeScan(now: baseDate);
      expect(quota.dailyScansLeft, 1);
      expect(quota.weeklyScansLeft, 2);
      expect(quota.canScan(now: baseDate), isTrue);
      expect(quota.quotaLabel, '1 of 2 left today · 2 of 3 this week');

      // Consume second scan
      quota = quota.consumeScan(now: baseDate);
      expect(quota.dailyScansLeft, 0);
      expect(quota.weeklyScansLeft, 1);
      expect(quota.isDailyLimitReached, isTrue);
      expect(quota.canScan(now: baseDate), isFalse); // Blocked because daily limit is reached

      // Simulate next day rollover (Wednesday, same week)
      final wednesday = DateTime(2026, 10, 7, 9, 0);
      final nextDayQuota = quota.resetIfExpired(now: wednesday);
      expect(nextDayQuota.dailyScansLeft, 2);
      expect(nextDayQuota.weeklyScansLeft, 1); // Weekly still consumed
      expect(nextDayQuota.canScan(now: wednesday), isTrue);

      // Simulate next week rollover (Next Monday)
      final nextMonday = DateTime(2026, 10, 12, 8, 0);
      final nextWeekQuota = quota.resetIfExpired(now: nextMonday);
      expect(nextWeekQuota.dailyScansLeft, 2);
      expect(nextWeekQuota.weeklyScansLeft, 3); // Weekly reset to full
      expect(nextWeekQuota.canScan(now: nextMonday), isTrue);
    });
  });

  group('UserSettings Model Tests', () {
    test('Default values match design specifications', () {
      final settings = UserSettings.defaults();
      expect(settings.classReminderMinutes, 15);
      expect(settings.quizReminderEnabled, isTrue);
      expect(settings.quizReminderTime, '20:00');
      expect(settings.formattedQuizReminderTime, '8:00 pm');
      expect(settings.exactAlarmsGranted, isFalse);
      expect(settings.hideEmptyDays, isFalse);
    });

    test('Correctly clears classReminderMinutes when set to null (Off)', () {
      final settings = UserSettings.defaults().copyWith(clearClassReminderMinutes: true);
      expect(settings.classReminderMinutes, isNull);
      expect(UserSettings.classReminderLabel(settings.classReminderMinutes), 'Off');
    });
  });

  group('AppDatabase & Cascade Delete Integration Tests', () {
    late AppDatabase dbManager;
    late TimetableRepository timetableRepo;
    late QuizRepository quizRepo;
    late SettingsRepository settingsRepo;

    setUp(() async {
      dbManager = await AppDatabase.createInMemory();
      timetableRepo = TimetableRepository(dbManager: dbManager);
      quizRepo = QuizRepository(dbManager: dbManager);
      settingsRepo = SettingsRepository(dbManager: dbManager);
    });

    tearDown(() async {
      await dbManager.close();
    });

    test('Inserts, retrieves and cascades delete from Class to Quiz', () async {
      const class1 = ClassItem(
        id: 'class_physics',
        subject: 'Physics',
        subjectColorIndex: 0,
        dayOfWeek: 'Thursday',
        startTime: '09:30',
        endTime: '10:20',
      );

      final quiz1 = QuizItem(
        id: 'quiz_physics_1',
        classId: 'class_physics',
        subject: 'Physics',
        title: 'Ch. 1-2',
        dueDate: DateTime(2026, 10, 8),
      );

      // Insert class and quiz
      await timetableRepo.insertClass(class1);
      await quizRepo.insertQuiz(quiz1);

      // Verify both exist
      final classes = await timetableRepo.getAllClasses();
      final quizzes = await quizRepo.getAllQuizzes();
      expect(classes.length, 1);
      expect(quizzes.length, 1);

      // Delete the class
      await timetableRepo.deleteClass('class_physics');

      // Verify that class is gone
      final remainingClasses = await timetableRepo.getAllClasses();
      expect(remainingClasses, isEmpty);

      // VERIFY CASCADE DELETE: Quiz linked to deleted class must be purged automatically by SQLite
      final remainingQuizzes = await quizRepo.getAllQuizzes();
      expect(remainingQuizzes, isEmpty);
    });

    test('Settings and ScanQuota persist and update in SQLite', () async {
      final settings = await settingsRepo.getSettings();
      expect(settings.classReminderMinutes, 15);

      await settingsRepo.updateSettings(settings.copyWith(classReminderMinutes: 30));
      final updatedSettings = await settingsRepo.getSettings();
      expect(updatedSettings.classReminderMinutes, 30);

      final quota = await settingsRepo.getScanQuota();
      expect(quota.dailyScansLeft, 2);

      final consumedQuota = await settingsRepo.consumeScan();
      expect(consumedQuota.dailyScansLeft, 1);
    });
  });
}
