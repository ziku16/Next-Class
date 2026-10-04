import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nextclass/core/theme/app_theme.dart';
import 'package:nextclass/data/database/app_database.dart';
import 'package:nextclass/data/repositories/settings_repository.dart';
import 'package:nextclass/domain/services/ai_extraction_service.dart';
import 'package:nextclass/state/upload_provider.dart';
import 'package:nextclass/ui/onboarding/notification_explainer_screen.dart';
import 'package:nextclass/ui/onboarding/splash_screen.dart';
import 'package:nextclass/ui/onboarding/welcome_screen.dart';
import 'package:nextclass/ui/upload/parsing_loader_screen.dart';
import 'package:nextclass/ui/upload/source_picker_sheet.dart';
import 'package:nextclass/ui/upload/upload_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: child,
  );
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
    testWidgets('SplashScreen renders branding and Forward Calendar icon', (tester) async {
      await tester.pumpWidget(_wrap(const SplashScreen()));

      expect(find.text('NextClass'), findsOneWidget);
      expect(find.text('Never miss a class or a quiz'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2000));
    });

    testWidgets('WelcomeScreen renders 3 value rows and direct Get started button', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));

      expect(find.text('Never miss a class\nor a quiz.'), findsOneWidget);
      expect(find.text('Snap a photo of your timetable'), findsOneWidget);
      expect(find.text('We find every class for you'), findsOneWidget);
      expect(find.text('Get reminded right on time'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });

    testWidgets('WelcomeScreen: tapping Get started triggers callback', (tester) async {
      bool started = false;
      await tester.pumpWidget(_wrap(WelcomeScreen(onGetStarted: () => started = true)));

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(started, isTrue);
    });

    testWidgets('WelcomeScreen: tapping Get started navigates to NotificationExplainerScreen', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationExplainerScreen), findsOneWidget);
    });

    testWidgets('NotificationExplainerScreen renders previews and action buttons', (tester) async {
      bool completed = false;

      await tester.pumpWidget(_wrap(
        NotificationExplainerScreen(onComplete: () => completed = true),
      ));

      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('Want a nudge\nbefore class?'), findsOneWidget);
      expect(find.text('Physics in 15 min · Room B-12'), findsOneWidget);
      expect(find.text('Quiz tomorrow: Chemistry — Ch. 4–5'), findsOneWidget);

      await tester.tap(find.text('Allow reminders'));
      expect(completed, isTrue);
    });
  });

  group('Flow 2 (Upload & AI Extraction) Tests', () {
    testWidgets('UploadScreen displays quota badge and guidelines', (tester) async {
      final provider = UploadProvider(settingsRepository: settingsRepo);

      await tester.pumpWidget(_wrap(
        UploadScreen(uploadProvider: provider),
      ));

      expect(find.text('Upload timetable'), findsOneWidget);
      expect(find.text('Good light, no shadows'), findsOneWidget);
      expect(find.text('Fit the whole table in the frame'), findsOneWidget);
      expect(find.text('Take or choose a photo'), findsOneWidget);
      expect(find.text('Add classes manually'), findsOneWidget);
    });

    testWidgets('SourcePickerSheet allows choosing Camera or Gallery', (tester) async {
      ImageSource? chosen;

      await tester.pumpWidget(MaterialApp(
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
      ));

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

      await tester.pumpWidget(_wrap(
        ParsingLoaderScreen(
          uploadProvider: provider,
          autoStartExtraction: false,
        ),
      ));

      expect(find.text('Reading your timetable…'), findsOneWidget);

      // Advance by 3 seconds
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Finding your classes…'), findsOneWidget);

      // Advance by another 3 seconds
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Almost there!'), findsOneWidget);

      // Unmount the widget so its periodic timer is cancelled cleanly
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('UploadProvider enforces quota rules: Failures do NOT deduct quota; Successes do', () async {
      final provider = UploadProvider(settingsRepository: settingsRepo);
      await provider.refreshQuota();

      expect(provider.quota.dailyScansLeft, 2);
      expect(provider.quota.weeklyScansLeft, 3);

      provider.setSelectedImage(XFile('mock_file.jpg'));

      // Test 1: Simulated failure must NOT deduct quota
      final failResult = await provider.extractClasses(simulateError: true);
      expect(failResult, isNull);
      expect(provider.errorCode, AiExtractionErrorCode.parsingFailed);
      expect(provider.quota.dailyScansLeft, 2); // Quota untouched!

      // Test 2: Successful extraction DOES deduct quota
      final successResult = await provider.extractClasses(simulateError: false);
      expect(successResult, isNotNull);
      expect(successResult!.length, greaterThan(0));
      expect(provider.quota.dailyScansLeft, 1); // Quota decremented by 1!
      expect(provider.quota.weeklyScansLeft, 2);
    });
  });
}
