import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/core/theme/app_theme.dart';
import 'package:nextclass/data/models/scan_quota.dart';
import 'package:nextclass/data/models/user_settings.dart';
import 'package:nextclass/data/repositories/settings_repository.dart';
import 'package:nextclass/state/settings_provider.dart';
import 'package:nextclass/ui/settings/reminder_picker_dialog.dart';
import 'package:nextclass/ui/settings/replace_timetable_dialog.dart';
import 'package:nextclass/ui/settings/settings_screen.dart';
import 'package:nextclass/ui/shared/confirmation_dialogs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child, {double textScale = 1.0}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: AppTheme.light.colorScheme,
      extensions: AppTheme.light.extensions.values,
    ),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

class FakeSettingsRepository extends SettingsRepository {
  UserSettings currentSettings;
  ScanQuota currentQuota;

  FakeSettingsRepository({
    UserSettings? settings,
    ScanQuota? quota,
  })  : currentSettings = settings ?? UserSettings.defaults(),
        currentQuota = quota ?? ScanQuota.initial();

  @override
  Future<UserSettings> getUserSettings() async => currentSettings;

  @override
  Future<void> updateUserSettings(UserSettings settings) async {
    currentSettings = settings;
  }

  @override
  Future<ScanQuota> getScanQuota({DateTime? now}) async => currentQuota;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Flow 7 & 8: SettingsProvider Unit Tests', () {
    test('Default settings initialize correctly', () {
      final fakeRepo = FakeSettingsRepository();
      final provider = SettingsProvider(settingsRepository: fakeRepo);

      expect(provider.classReminderMinutes, 15);
      expect(provider.quizReminderEnabled, isTrue);
      expect(provider.quizReminderTime, '20:00');
      expect(provider.formattedQuizReminderTime, '8:00 pm');
      expect(provider.exactAlarmsGranted, isFalse);
    });

    test('Updates class reminder minutes and supports null (Off)', () async {
      final fakeRepo = FakeSettingsRepository();
      final provider = SettingsProvider(settingsRepository: fakeRepo);

      await provider.updateClassReminderMinutes(30);
      expect(provider.classReminderMinutes, 30);
      expect(fakeRepo.currentSettings.classReminderMinutes, 30);

      await provider.updateClassReminderMinutes(null);
      expect(provider.classReminderMinutes, isNull);
      expect(fakeRepo.currentSettings.classReminderMinutes, isNull);
    });

    test('Toggles quiz reminder and updates reminder time', () async {
      final fakeRepo = FakeSettingsRepository();
      final provider = SettingsProvider(settingsRepository: fakeRepo);

      await provider.toggleQuizReminder(false);
      expect(provider.quizReminderEnabled, isFalse);
      expect(fakeRepo.currentSettings.quizReminderEnabled, isFalse);

      await provider.updateQuizReminderTime('19:30');
      expect(provider.quizReminderTime, '19:30');
      expect(provider.formattedQuizReminderTime, '7:30 pm');
    });

    test('Computes quota display text correctly', () {
      final quota = ScanQuota(
        dailyScansUsed: 1,
        weeklyScansUsed: 1,
        lastDailyReset: DateTime.now(),
        lastWeeklyReset: DateTime.now(),
      );
      final provider = SettingsProvider(initialQuota: quota);

      expect(
        provider.quotaDisplayText,
        '1 of 2 left today · 2 of 3 this week',
      );
    });
  });

  group('Flow 8: ConfirmationDialogs Tests', () {
    testWidgets('Sign Out Dialog displays correct copy and handles actions', (tester) async {
      bool? result;

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await ConfirmationDialogs.showSignOutDialog(ctx);
              },
              child: const Text('Open Sign Out'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sign Out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsOneWidget);
      expect(
        find.text(
          'Reminders stop until you sign in again. Your timetable stays saved to your account.',
        ),
        findsOneWidget,
      );

      // Tap Stay signed in
      await tester.tap(find.text('Stay signed in'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      // Open again and tap Sign out
      await tester.tap(find.text('Open Sign Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('Delete Class Dialog displays subject and day and cascades warning', (tester) async {
      bool? result;

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await ConfirmationDialogs.showDeleteClassDialog(
                  ctx,
                  subject: 'Calculus II',
                  dayOfWeek: 'Monday',
                );
              },
              child: const Text('Delete Class'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Class'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Calculus II?'), findsOneWidget);
      expect(
        find.text(
          'This removes it from Monday and cancels its reminders. Any quiz linked to this class will go too.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('Delete Quiz Dialog displays subject and date with reminder cancellation copy', (tester) async {
      bool? result;

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await ConfirmationDialogs.showDeleteQuizDialog(
                  ctx,
                  subject: 'Physics',
                  formattedDate: 'Thu, 2 Oct',
                );
              },
              child: const Text('Delete Quiz'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Quiz'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this quiz?'), findsOneWidget);
      expect(
        find.text('Physics · Thu, 2 Oct. Its reminder will be cancelled.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('Flow 7: ReplaceTimetableDialog & ReminderPickerDialog Tests', () {
    testWidgets('ReplaceTimetableDialog shows re-align copy and handles confirmation', (tester) async {
      bool? confirmed;

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                confirmed = await ReplaceTimetableDialog.show(ctx);
              },
              child: const Text('Open Replace'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Replace'));
      await tester.pumpAndSettle();

      expect(find.text('Replace timetable?'), findsOneWidget);
      expect(
        find.text(
          'Replacing your timetable will re-align all recurring classes. Continue?',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Replace timetable'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });

    testWidgets('ReminderPickerDialog selects options: 30 min before', (tester) async {
      int? selected;

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                selected = await ReminderPickerDialog.show(
                  ctx,
                  currentMinutes: 15,
                );
              },
              child: const Text('Open Picker'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Class reminder'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('15 min before'), findsOneWidget);
      expect(find.text('30 min before'), findsOneWidget);

      await tester.tap(find.text('30 min before'));
      await tester.pumpAndSettle();

      expect(selected, 30);
    });
  });

  group('Flow 7 & 8: SettingsScreen Integration Tests', () {
    testWidgets('Renders all sections: REMINDERS, NOTIFICATIONS, TIMETABLE, ABOUT', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeSettingsRepository();
      final provider = SettingsProvider(settingsRepository: fakeRepo);

      await tester.pumpWidget(_wrap(
        SettingsScreen(settingsProvider: provider),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('REMINDERS'), findsOneWidget);
      expect(find.text('NOTIFICATIONS'), findsOneWidget);
      expect(find.text('TIMETABLE'), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);

      // Class reminder segmented button
      expect(find.byKey(const Key('class_reminder_segmented')), findsOneWidget);
      expect(find.text('5 min'), findsOneWidget);
      expect(find.text('15 min'), findsOneWidget);

      // Quiz reminder toggle & time
      expect(find.byKey(const Key('quiz_reminder_switch')), findsOneWidget);
      expect(find.text('Quiz reminder'), findsOneWidget);
      expect(find.text('8:00 pm'), findsOneWidget);

      // Notifications permission switch is present and exact alarms warning tile is absent
      expect(find.byKey(const Key('notifications_permission_switch')), findsOneWidget);
      expect(find.byKey(const Key('exact_alarms_warning_tile')), findsNothing);
    });

    testWidgets('Interacting with segmented button updates reminder minutes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeSettingsRepository();
      final provider = SettingsProvider(settingsRepository: fakeRepo);

      await tester.pumpWidget(_wrap(
        SettingsScreen(settingsProvider: provider),
      ));
      await tester.pumpAndSettle();

      // Tap 30 min in segmented button
      await tester.tap(find.text('30 min'));
      await tester.pump();

      expect(provider.classReminderMinutes, 30);
    });

    testWidgets('Toggling notifications permission switch updates state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeSettingsRepository();
      final provider = SettingsProvider(settingsRepository: fakeRepo);

      await tester.pumpWidget(_wrap(
        SettingsScreen(settingsProvider: provider),
      ));
      await tester.pumpAndSettle();

      // Tap notifications switch to toggle off
      await tester.tap(find.byKey(const Key('notifications_permission_switch')));
      await tester.pump();

      expect(provider.notificationsEnabled, isFalse);
    });

    testWidgets('Tapping Upload new timetable tile triggers ReplaceTimetableDialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool uploadTriggered = false;
      final fakeRepo = FakeSettingsRepository();
      final provider = SettingsProvider(settingsRepository: fakeRepo);

      await tester.pumpWidget(_wrap(
        SettingsScreen(
          settingsProvider: provider,
          onUploadTimetable: () => uploadTriggered = true,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap Upload new timetable tile
      await tester.tap(find.byKey(const Key('upload_timetable_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Replace timetable?'), findsOneWidget);

      // Confirm replace
      await tester.tap(find.text('Replace timetable'));
      await tester.pumpAndSettle();

      expect(uploadTriggered, isTrue);
    });

    testWidgets('Tapping Sign out triggers Sign Out ConfirmationDialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool signedOut = false;
      final fakeRepo = FakeSettingsRepository();
      final provider = SettingsProvider(settingsRepository: fakeRepo);

      await tester.pumpWidget(_wrap(
        SettingsScreen(
          settingsProvider: provider,
          onSignOut: () => signedOut = true,
        ),
      ));
      await tester.pumpAndSettle();

      // Scroll and tap sign out
      await tester.ensureVisible(find.byKey(const Key('sign_out_tile')));
      await tester.tap(find.byKey(const Key('sign_out_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsOneWidget);

      // Confirm sign out
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(signedOut, isTrue);
    });
  });

  group('Flow 7: Accessibility Scaling (130% Font Scale)', () {
    testWidgets('Wraps cleanly without clipping at 130% font scale', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeSettingsRepository();
      final provider = SettingsProvider(settingsRepository: fakeRepo);

      await tester.pumpWidget(_wrap(
        SettingsScreen(settingsProvider: provider),
        textScale: 1.3, // 130% font scale
      ));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('REMINDERS'), findsOneWidget);
      expect(find.text('Class reminder'), findsOneWidget);
      expect(find.text('Quiz reminder'), findsOneWidget);
      expect(find.text('NOTIFICATIONS'), findsOneWidget);
      expect(find.text('TIMETABLE'), findsOneWidget);
      // ABOUT is below the lazy ListView viewport at 130% text scaling.
      await tester.scrollUntilVisible(
        find.text('ABOUT'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('ABOUT'), findsOneWidget);
    });
  });
}
