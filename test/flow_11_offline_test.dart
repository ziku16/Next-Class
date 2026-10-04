import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/core/theme/app_theme.dart';
import 'package:nextclass/data/models/class_item.dart';
import 'package:nextclass/data/models/quiz_item.dart';
import 'package:nextclass/domain/services/connectivity_service.dart';
import 'package:nextclass/ui/home/today_screen.dart';
import 'package:nextclass/ui/quizzes/quizzes_screen.dart';
import 'package:nextclass/ui/shared/offline_banner.dart';
import 'package:nextclass/ui/upload/upload_screen.dart';
import 'package:nextclass/ui/week/week_screen.dart';
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final sampleClasses = [
    const ClassItem(
      id: 'c1',
      subject: 'Mathematics',
      subjectColorIndex: 0,
      dayOfWeek: 'Monday',
      startTime: '08:30',
      endTime: '09:20',
    ),
  ];

  final sampleQuizzes = [
    QuizItem(
      id: 'q1',
      classId: 'c1',
      subject: 'Mathematics',
      title: 'Algebra Quiz',
      dueDate: DateTime.now().add(const Duration(days: 2)),
    ),
  ];

  group('Flow 11: ConnectivityService Unit Tests', () {
    test('Reactively updates offline status and stream', () async {
      final service = ConnectivityService.test(initialOffline: false);
      expect(service.isOffline, isFalse);
      expect(service.isOnline, isTrue);

      bool? streamEmitted;
      final sub = service.onConnectivityChanged.listen((offline) {
        streamEmitted = offline;
      });

      service.setOffline(true);
      expect(service.isOffline, isTrue);
      expect(service.isOnline, isFalse);
      expect(streamEmitted, isTrue);

      service.setOffline(false);
      expect(service.isOffline, isFalse);
      expect(service.isOnline, isTrue);
      expect(streamEmitted, isFalse);

      await sub.cancel();
    });
  });

  group('Flow 11: OfflineBanner Component Tests', () {
    testWidgets('Renders inverse surface banner when isOffline is true', (tester) async {
      await tester.pumpWidget(_wrap(
        const Scaffold(
          body: OfflineBanner(isOffline: true),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offline_banner_container')), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(
        find.text("You're offline. Showing your saved timetable."),
        findsOneWidget,
      );
    });

    testWidgets('Collapses to empty space when isOffline is false', (tester) async {
      await tester.pumpWidget(_wrap(
        const Scaffold(
          body: OfflineBanner(isOffline: false),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offline_banner_container')), findsNothing);
      expect(
        find.text("You're offline. Showing your saved timetable."),
        findsNothing,
      );
    });

    testWidgets('Renders retry action button and triggers onRetry', (tester) async {
      bool retryPressed = false;

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: OfflineBanner(
            isOffline: true,
            onRetry: () => retryPressed = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retryPressed, isTrue);
    });
  });

  group('Flow 11: UploadScreen Offline Behavior Tests', () {
    testWidgets('Disables AI extraction when offline and shows OfflineBanner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(
        const UploadScreen(
          isOffline: true, // Offline mode
        ),
      ));
      await tester.pumpAndSettle();

      // OfflineBanner displayed
      expect(
        find.text("You're offline. Showing your saved timetable."),
        findsOneWidget,
      );

      // Extract classes button shows offline status
      expect(find.text('Offline — Extraction unavailable'), findsOneWidget);

      // Manual fallback button is present and clickable
      expect(find.text('Add classes manually'), findsOneWidget);
    });
  });

  group('Flow 11: Screen OfflineBanner Integration Tests', () {
    testWidgets('TodayScreen displays OfflineBanner when isOffline is true', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(
        TodayScreen(
          isOffline: true,
          initialClasses: sampleClasses,
          initialQuizzes: sampleQuizzes,
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text("You're offline. Showing your saved timetable."),
        findsOneWidget,
      );
    });

    testWidgets('WeekScreen displays OfflineBanner when isOffline is true', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(
        WeekScreen(
          isOffline: true,
          initialClasses: sampleClasses,
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text("You're offline. Showing your saved timetable."),
        findsOneWidget,
      );
    });

    testWidgets('QuizzesScreen displays OfflineBanner when isOffline is true', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(
        QuizzesScreen(
          isOffline: true,
          initialClasses: sampleClasses,
          initialQuizzes: sampleQuizzes,
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text("You're offline. Showing your saved timetable."),
        findsOneWidget,
      );
    });
  });

  group('Flow 11: Accessibility Scale (130% Font Scale)', () {
    testWidgets('OfflineBanner wraps cleanly at 130% font scale', (tester) async {
      await tester.pumpWidget(_wrap(
        const Scaffold(
          body: OfflineBanner(isOffline: true),
        ),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offline_banner_container')), findsOneWidget);
      expect(
        find.text("You're offline. Showing your saved timetable."),
        findsOneWidget,
      );
    });
  });
}
