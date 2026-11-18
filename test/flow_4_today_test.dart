import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/core/theme/app_theme.dart';
import 'package:nextclass/data/models/class_item.dart';
import 'package:nextclass/data/models/quiz_item.dart';
import 'package:nextclass/ui/home/app_bottom_nav.dart';
import 'package:nextclass/ui/home/quizzes_preview_row.dart';
import 'package:nextclass/ui/home/today_header.dart';
import 'package:nextclass/ui/home/today_screen.dart';
import 'package:nextclass/ui/shared/live_progress_bar.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: AppTheme.light.colorScheme,
      extensions: AppTheme.light.extensions.values,
    ),
    home: child,
  );
}

void main() {
  final sampleClasses = [
    const ClassItem(
      id: 'c1',
      subject: 'Mathematics',
      subjectColorIndex: 0,
      dayOfWeek: 'Thursday',
      startTime: '08:30',
      endTime: '09:20',
      room: 'Room A-04',
      teacher: 'Dr. Smith',
    ),
    const ClassItem(
      id: 'c2',
      subject: 'Physics',
      subjectColorIndex: 1,
      dayOfWeek: 'Thursday',
      startTime: '09:30',
      endTime: '10:20',
      room: 'Room B-12',
      teacher: 'Prof. Miller',
    ),
    const ClassItem(
      id: 'c3',
      subject: 'Chemistry Lab',
      subjectColorIndex: 2,
      dayOfWeek: 'Thursday',
      startTime: '11:00',
      endTime: '12:40',
      room: 'Lab 2',
    ),
  ];

  final sampleQuizzes = [
    QuizItem(
      id: 'q1',
      classId: 'c2',
      subject: 'Physics',
      title: 'Thermodynamics Quiz',
      dueDate: DateTime(2026, 10, 2, 9, 30), // Today
    ),
    QuizItem(
      id: 'q2',
      classId: 'c3',
      subject: 'Chemistry',
      title: 'Ch. 4–5',
      dueDate: DateTime(2026, 10, 3, 11, 00), // Tomorrow
    ),
    QuizItem(
      id: 'q3',
      classId: 'c1',
      subject: 'Mathematics',
      title: 'Integration test',
      dueDate: DateTime(2026, 10, 7, 8, 30), // 5 days left
    ),
  ];

  group('Flow 4: TodayHeader Dynamic Schedule Pill Tests', () {
    testWidgets('Header computes greeting and date correctly', (tester) async {
      // 08:00 AM on Thursday, 2 October 2026
      final morningTime = DateTime(2026, 10, 2, 8, 0);

      await tester.pumpWidget(_wrap(
        TodayHeader(
          currentTime: morningTime,
          userName: 'Ali',
          classesToday: sampleClasses,
          hasTimetable: true,
        ),
      ));

      expect(find.text('Good morning, Ali'), findsOneWidget);
      expect(find.text('Friday, 2 October'), findsOneWidget); // 2026-10-02 is Friday
    });

    testWidgets('Pill: Before first class (08:00)', (tester) async {
      final morningTime = DateTime(2026, 10, 2, 8, 0);

      await tester.pumpWidget(_wrap(
        TodayHeader(
          currentTime: morningTime,
          userName: 'Ali',
          classesToday: sampleClasses,
          hasTimetable: true,
        ),
      ));

      expect(find.text('3 classes today · next at 08:30'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('Pill: During active class (09:45 Physics)', (tester) async {
      final duringTime = DateTime(2026, 10, 2, 9, 45);

      await tester.pumpWidget(_wrap(
        TodayHeader(
          currentTime: duringTime,
          userName: 'Ali',
          classesToday: sampleClasses,
          hasTimetable: true,
        ),
      ));

      expect(find.text('3 classes today · Physics ends at 10:20'), findsOneWidget);
    });

    testWidgets('Pill: Between classes (10:30 before Chemistry Lab)', (tester) async {
      final betweenTime = DateTime(2026, 10, 2, 10, 30);

      await tester.pumpWidget(_wrap(
        TodayHeader(
          currentTime: betweenTime,
          userName: 'Ali',
          classesToday: sampleClasses,
          hasTimetable: true,
        ),
      ));

      expect(find.text('1 class left · next at 11:00'), findsOneWidget);
    });

    testWidgets('Pill: All classes completed (13:00)', (tester) async {
      final doneTime = DateTime(2026, 10, 2, 13, 0);

      await tester.pumpWidget(_wrap(
        TodayHeader(
          currentTime: doneTime,
          userName: 'Ali',
          classesToday: sampleClasses,
          hasTimetable: true,
        ),
      ));

      expect(find.text("That's a wrap for today. Shabash!"), findsOneWidget);
      expect(find.byIcon(Icons.celebration_rounded), findsOneWidget);
    });

    testWidgets('Pill: Weekend / No classes scheduled today', (tester) async {
      final weekendTime = DateTime(2026, 10, 4, 10, 0); // Sunday

      await tester.pumpWidget(_wrap(
        TodayHeader(
          currentTime: weekendTime,
          userName: 'Ali',
          classesToday: const [],
          hasTimetable: true,
        ),
      ));

      expect(find.text('Nothing on the timetable'), findsOneWidget);
      expect(find.byIcon(Icons.weekend_rounded), findsOneWidget);
    });

    testWidgets('Pill: First launch without timetable', (tester) async {
      final firstLaunchTime = DateTime(2026, 10, 2, 10, 0);

      await tester.pumpWidget(_wrap(
        TodayHeader(
          currentTime: firstLaunchTime,
          userName: 'Ali',
          classesToday: const [],
          hasTimetable: false,
        ),
      ));

      expect(find.text('Welcome, Ali'), findsOneWidget);
      expect(find.text('Nothing scheduled yet'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  });

  group('Flow 4: Class Feed and Active/Upcoming/Done States', () {
    testWidgets('Renders in-progress card with teal Now pill, border & live progress bar', (tester) async {
      // 09:45 is during Physics (09:30 - 10:20, Thursday)
      // Reference date: Thursday, 1 Oct 2026
      final thursdayNow = DateTime(2026, 10, 1, 9, 45);

      await tester.pumpWidget(_wrap(
        TodayScreen(
          currentTime: thursdayNow,
          userName: 'Ali',
          initialClasses: sampleClasses,
          initialQuizzes: sampleQuizzes,
          remindersEnabled: true,
          isOffline: false,
        ),
      ));
      await tester.pumpAndSettle();

      // "Today" text appears in section header and bottom navigation
      expect(find.text('Today'), findsWidgets);

      // In-progress card (Physics)
      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(find.byType(LiveProgressBar), findsOneWidget);

      // Completed card (Mathematics, ended at 09:20)
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Upcoming card (Chemistry Lab, starts at 11:00)
      expect(find.text('Chemistry Lab'), findsOneWidget);
      expect(find.text('in 1h 15m'), findsOneWidget);
    });
  });

  group('Flow 4: QuizzesPreviewRow Tests', () {
    testWidgets('Renders upcoming quizzes with urgency pills and See all button', (tester) async {
      final refDate = DateTime(2026, 10, 2, 9, 0);
      bool seeAllTapped = false;

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: QuizzesPreviewRow(
            quizzes: sampleQuizzes,
            referenceDate: refDate,
            onSeeAll: () => seeAllTapped = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Upcoming quizzes'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);

      // Check quiz titles and badges
      expect(find.text('Thermodynamics Quiz'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      expect(find.text('Ch. 4–5'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);

      expect(find.text('Integration test'), findsOneWidget);
      expect(find.text('5 days left'), findsOneWidget);

      // Tap See all
      await tester.tap(find.text('See all'));
      await tester.pump();
      expect(seeAllTapped, isTrue);
    });

    testWidgets('Renders empty state when quizzes list is empty', (tester) async {
      await tester.pumpWidget(_wrap(
        Scaffold(
          body: QuizzesPreviewRow(
            quizzes: const [],
            referenceDate: DateTime(2026, 10, 2),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No quizzes coming up.'), findsOneWidget);
      expect(find.text('Add one when your teacher announces it.'), findsOneWidget);
    });
  });

  group('Flow 4: Edge States & Warning Banners', () {
    testWidgets('Weekend / No classes today stays uncluttered without the oversized quiz prompt', (tester) async {
      // Sunday, 4 Oct 2026
      final sundayNow = DateTime(2026, 10, 4, 11, 0);

      await tester.pumpWidget(_wrap(
        TodayScreen(
          currentTime: sundayNow,
          userName: 'Ali',
          initialClasses: sampleClasses, // Classes exist on Thursday, not Sunday
          initialQuizzes: sampleQuizzes,
          remindersEnabled: true,
          isOffline: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No classes today. Enjoy the break!'), findsOneWidget);
      expect(find.text('Take a breather or get ahead on upcoming quizzes.'), findsOneWidget);
      expect(find.byIcon(Icons.weekend_rounded), findsWidgets);

      expect(find.text('Upcoming quizzes'), findsNothing);
      expect(find.text('Ch. 4–5'), findsNothing);
    });

    testWidgets('First launch / No timetable renders welcome empty state and Upload button', (tester) async {
      final now = DateTime(2026, 10, 1, 10, 0);
      bool uploadTapped = false;

      await tester.pumpWidget(_wrap(
        TodayScreen(
          currentTime: now,
          userName: 'Ali',
          initialClasses: const [], // Empty timetable
          initialQuizzes: const [],
          remindersEnabled: true,
          isOffline: false,
          onUploadTimetable: () => uploadTapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Ali. Nothing scheduled yet.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Upload timetable'), findsOneWidget);
      expect(find.byKey(const Key('bottom_nav_add_button')), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Upload timetable'));
      await tester.pump();
      expect(uploadTapped, isTrue);
    });

    testWidgets('Offline banner displays when isOffline is true', (tester) async {
      final now = DateTime(2026, 10, 1, 10, 0);

      await tester.pumpWidget(_wrap(
        TodayScreen(
          currentTime: now,
          initialClasses: sampleClasses,
          initialQuizzes: sampleQuizzes,
          isOffline: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text("You're offline. Showing your saved timetable."), findsOneWidget);
    });

    testWidgets('Reminders off warning banner displays and allows turning on', (tester) async {
      final now = DateTime(2026, 10, 1, 10, 0);

      await tester.pumpWidget(_wrap(
        TodayScreen(
          currentTime: now,
          initialClasses: sampleClasses,
          initialQuizzes: sampleQuizzes,
          remindersEnabled: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Reminders are off'), findsOneWidget);
      expect(find.text('Turn on notifications so we can nudge you before class.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Turn on'), findsOneWidget);
    });
  });

  group('Flow 4: AppBottomNav & Contextual FAB Tests', () {
    testWidgets('AppBottomNav renders 3 tabs and handles tab switching', (tester) async {
      int selectedTab = 0;

      await tester.pumpWidget(_wrap(
        Scaffold(
          bottomNavigationBar: AppBottomNav(
            currentIndex: selectedTab,
            onDestinationSelected: (idx) => selectedTab = idx,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Quizzes'), findsOneWidget);

      // Tap Quizzes tab
      await tester.tap(find.text('Quizzes'));
      await tester.pumpAndSettle();
      expect(selectedTab, 2);
    });

    testWidgets('Center plus menu offers Add Quiz and Add Exam actions', (tester) async {
      var quizOpened = false;
      var examOpened = false;
      await tester.pumpWidget(_wrap(Scaffold(
        bottomNavigationBar: AppBottomNav(
          currentIndex: 0,
          onDestinationSelected: (_) {},
          onAddQuiz: () => quizOpened = true,
          onAddExam: () => examOpened = true,
        ),
      )));

      await tester.tap(find.byKey(const Key('bottom_nav_add_button')));
      await tester.pumpAndSettle();
      expect(find.text('Add Quiz'), findsOneWidget);
      expect(find.text('Add Exam'), findsOneWidget);

      await tester.tap(find.text('Add Exam'));
      await tester.pumpAndSettle();
      expect(examOpened, isTrue);
      expect(quizOpened, isFalse);
    });

    testWidgets('AppBottomNav.buildFab builds Add quiz when timetable exists', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => AppBottomNav.buildFab(
            context: ctx,
            hasTimetable: true,
            onPressed: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FloatingActionButton, 'Add quiz'), findsOneWidget);
    });

    testWidgets('AppBottomNav.buildFab builds Upload timetable when no timetable exists', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => AppBottomNav.buildFab(
            context: ctx,
            hasTimetable: false,
            onPressed: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FloatingActionButton, 'Upload timetable'), findsOneWidget);
    });
  });
}
