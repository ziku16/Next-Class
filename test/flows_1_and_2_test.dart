import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nextclass/core/theme/app_theme.dart';
import 'package:nextclass/data/database/app_database.dart';
import 'package:nextclass/data/repositories/settings_repository.dart';
import 'package:nextclass/data/models/scan_quota.dart';
import 'package:nextclass/state/upload_provider.dart';
import 'package:nextclass/services/timetable_parser_service.dart';
import 'package:nextclass/ui/onboarding/notification_explainer_screen.dart';
import 'package:nextclass/ui/onboarding/splash_screen.dart';
import 'package:nextclass/ui/onboarding/welcome_screen.dart';
import 'package:nextclass/ui/upload/parsing_loader_screen.dart';
import 'package:nextclass/ui/upload/source_picker_sheet.dart';
import 'package:nextclass/ui/upload/upload_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: child);
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase dbManager;
  late SettingsRepository settingsRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dbManager = await AppDatabase.createInMemory();
    settingsRepo = SettingsRepository(dbManager: dbManager);
  });

  tearDown(() async {
    await dbManager.close();
  });

  group('Flow 1 (Onboarding) Widget Tests', () {
    testWidgets('SplashScreen renders branding and Forward Calendar icon', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SplashScreen()));

      expect(find.text('NextClass'), findsOneWidget);
      expect(find.text('Never miss a class or a quiz'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2000));
    });

    testWidgets(
      'WelcomeScreen shows concise setup benefits and a direct start button',
      (tester) async {
        await tester.pumpWidget(_wrap(const WelcomeScreen()));

        expect(find.text('Never miss a class\nor a quiz.'), findsOneWidget);
        expect(find.text('Snap your timetable'), findsOneWidget);
        expect(find.text('Review classes before saving.'), findsOneWidget);
        expect(find.text('Class and quiz reminders'), findsOneWidget);
        expect(
          find.text('No manual entry required. Just verify and save.'),
          findsNothing,
        );
        expect(find.text("Chalo, let's get organised."), findsNothing);
        expect(find.text('Get started'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      },
    );

    testWidgets('WelcomeScreen: tapping Get started triggers callback', (
      tester,
    ) async {
      bool started = false;
      await tester.pumpWidget(
        _wrap(WelcomeScreen(onGetStarted: () => started = true)),
      );

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(started, isTrue);
    });

    testWidgets(
      'WelcomeScreen: tapping Get started navigates to NotificationExplainerScreen',
      (tester) async {
        await tester.pumpWidget(_wrap(const WelcomeScreen()));

        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();

        expect(find.byType(NotificationExplainerScreen), findsOneWidget);
      },
    );

    testWidgets(
      'NotificationExplainerScreen renders previews and action buttons',
      (tester) async {
        bool completed = false;

        await tester.pumpWidget(
          _wrap(
            NotificationExplainerScreen(onComplete: () => completed = true),
          ),
        );

        expect(find.text('Step 2 of 3'), findsOneWidget);
        expect(find.text('Want a nudge\nbefore class?'), findsOneWidget);
        expect(find.text('Physics in 15 min · Room B-12'), findsOneWidget);
        expect(find.text('Quiz tomorrow: Chemistry — Ch. 4–5'), findsOneWidget);

        await tester.tap(find.text('Allow reminders'));
        expect(completed, isTrue);
      },
    );
  });

  group('Flow 2 (Upload & AI Extraction) Tests', () {
    testWidgets('UploadScreen displays quota badge and guidelines', (
      tester,
    ) async {
      final provider = UploadProvider(settingsRepository: settingsRepo);

      await tester.pumpWidget(_wrap(UploadScreen(uploadProvider: provider)));

      expect(find.text('Upload timetable'), findsOneWidget);
      expect(find.text('Good light, no shadows'), findsOneWidget);
      expect(find.text('Fit the whole table in the frame'), findsOneWidget);
      expect(find.text('Take or choose a photo'), findsOneWidget);
      expect(find.text('Add classes manually'), findsOneWidget);
    });

    testWidgets('SourcePickerSheet allows choosing Camera or Gallery', (
      tester,
    ) async {
      ImageSource? chosen;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  chosen = await SourcePickerSheet.show(ctx);
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Add a timetable photo'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);

      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();

      expect(chosen, ImageSource.camera);
    });

    testWidgets('ParsingLoaderScreen cycles copy every 3s', (tester) async {
      final provider = UploadProvider(settingsRepository: settingsRepo);
      provider.setSelectedImage(XFile('mock_timetable.jpg'));

      await tester.pumpWidget(
        _wrap(
          ParsingLoaderScreen(
            uploadProvider: provider,
            autoStartExtraction: false,
          ),
        ),
      );

      expect(find.text('PROCESSING TIMETABLE...'), findsOneWidget);

      // Advance by 3 seconds
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('PARSING SCHEDULE...'), findsOneWidget);

      // Advance by another 3 seconds
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('EXTRACTING CLASSES...'), findsOneWidget);

      // Unmount the widget so its periodic timer is cancelled cleanly
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test(
      'UploadProvider enforces quota rules: Failures do NOT deduct quota',
      () async {
        final provider = UploadProvider(settingsRepository: settingsRepo);
        await provider.refreshQuota();

        expect(provider.quota.dailyScansLeft, 2);
        expect(provider.quota.weeklyScansLeft, 3);

        provider.setSelectedImage(XFile('non_existent_mock_file.jpg'));

        // Test: Failed network / file call must NOT deduct quota
        final failResult = await provider.extractClasses();
        expect(failResult, isNull);
        expect(provider.quota.dailyScansLeft, 2); // Quota untouched!
      },
    );

    test(
      'UploadProvider consumes one SQLite quota only after valid extraction',
      () async {
        final provider = UploadProvider(
          settingsRepository: settingsRepo,
          timetableExtractor: (_) async => {
            'entries': [
              {
                'day': 'Monday',
                'subject': 'Physics',
                'group': null,
                'start': '09:00',
                'end': '10:00',
                'room': 'B-12',
                'teacher': null,
              },
            ],
          },
        );
        await provider.refreshQuota();
        provider.setSelectedImage(XFile('mock.jpg'));

        final classes = await provider.extractClasses();

        expect(classes, hasLength(1));
        expect((await settingsRepo.getScanQuota()).dailyScansUsed, 1);
        expect((await settingsRepo.getScanQuota()).weeklyScansUsed, 1);
      },
    );

    test(
      'UploadProvider does not consume quota for an empty extraction',
      () async {
        final provider = UploadProvider(
          settingsRepository: settingsRepo,
          timetableExtractor: (_) async => {
            'entries': <Map<String, Object?>>[],
          },
        );
        await provider.refreshQuota();
        provider.setSelectedImage(XFile('mock.jpg'));

        expect(await provider.extractClasses(), isNull);
        expect((await settingsRepo.getScanQuota()).dailyScansUsed, 0);
        expect(provider.errorCode, TimetableScanErrorCode.emptyResult);
      },
    );

    test('UploadProvider prevents overlapping extraction requests', () async {
      final response = Completer<Map<String, dynamic>>();
      var requests = 0;
      final provider = UploadProvider(
        settingsRepository: settingsRepo,
        timetableExtractor: (_) {
          requests++;
          return response.future;
        },
      );
      await provider.refreshQuota();
      provider.setSelectedImage(XFile('mock.jpg'));

      final first = provider.extractClasses();
      final duplicate = await provider.extractClasses();
      response.complete({
        'entries': [
          {
            'day': 'Monday',
            'subject': 'Physics',
            'group': null,
            'start': '09:00',
            'end': '10:00',
            'room': null,
            'teacher': null,
          },
        ],
      });

      expect(duplicate, isNull);
      expect(await first, hasLength(1));
      expect(requests, 1);
    });

    test(
      'UploadProvider stops before network when SQLite quota is exhausted',
      () async {
        final now = DateTime.now();
        await dbManager.database.then(
          (db) => db.update(
            'quota',
            ScanQuota(
              dailyScansUsed: 2,
              lastDailyReset: now,
              weeklyScansUsed: 2,
              lastWeeklyReset: now,
            ).toMap(),
            where: 'id = 1',
          ),
        );
        var requests = 0;
        final provider = UploadProvider(
          settingsRepository: settingsRepo,
          timetableExtractor: (_) async {
            requests++;
            return {'entries': <Map<String, Object?>>[]};
          },
        );
        await provider.refreshQuota();
        provider.setSelectedImage(XFile('mock.jpg'));

        expect(await provider.extractClasses(), isNull);
        expect(requests, 0);
        expect(provider.errorCode, TimetableScanErrorCode.rateLimitExceeded);
      },
    );

    test('UploadProvider gives an actionable authentication error', () async {
      final provider = UploadProvider(
        settingsRepository: settingsRepo,
        timetableExtractor: (_) async => throw const TimetableScanException(
          TimetableScanFailure.authentication,
          statusCode: 401,
        ),
      );
      await provider.refreshQuota();
      provider.setSelectedImage(XFile('mock.jpg'));

      await provider.extractClasses();

      expect(provider.errorCode, TimetableScanErrorCode.authentication);
      expect(provider.errorMessage, contains('configured correctly'));
    });
  });
}
