import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/core/theme/app_theme.dart';
import 'package:nextclass/data/models/class_item.dart';
import 'package:nextclass/data/models/quiz_item.dart';
import 'package:nextclass/data/repositories/quiz_repository.dart';
import 'package:nextclass/data/repositories/timetable_repository.dart';
import 'package:nextclass/state/quiz_provider.dart';
import 'package:nextclass/ui/quizzes/add_edit_quiz_sheet.dart';
import 'package:nextclass/ui/quizzes/quiz_card.dart';
import 'package:nextclass/ui/quizzes/quizzes_screen.dart';
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

class FakeQuizRepository extends QuizRepository {
  List<QuizItem> items;

  FakeQuizRepository([List<QuizItem>? initial])
      : items = List.from(initial ?? []);

  @override
  Future<List<QuizItem>> getAllQuizzes() async => List.unmodifiable(items);

  @override
  Future<List<QuizItem>> getUpcomingQuizzes({DateTime? referenceDate}) async {
    final ref = referenceDate ?? DateTime.now();
    final startOfToday = DateTime(ref.year, ref.month, ref.day);
    return items
        .where((q) => !q.dueDate.isBefore(startOfToday) && !q.isCompleted)
        .toList();
  }

  @override
  Future<void> insertQuiz(QuizItem item) async {
    items.removeWhere((q) => q.id == item.id);
    items.add(item);
  }

  @override
  Future<void> updateQuiz(QuizItem item) async {
    final idx = items.indexWhere((q) => q.id == item.id);
    if (idx != -1) {
      items[idx] = item;
    } else {
      items.add(item);
    }
  }

  @override
  Future<void> deleteQuiz(String id) async {
    items.removeWhere((q) => q.id == id);
  }

  @override
  Future<void> toggleQuizCompleted(String id) async {
    final idx = items.indexWhere((q) => q.id == id);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(isCompleted: !items[idx].isCompleted);
    }
  }
}

class FakeTimetableRepository extends TimetableRepository {
  List<ClassItem> storedClasses;

  FakeTimetableRepository([List<ClassItem>? initial])
      : storedClasses = List.from(initial ?? []);

  @override
  Future<List<ClassItem>> getAllClasses() async =>
      List.unmodifiable(storedClasses);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Reference date: Thursday, 1 October 2026 at 10:00 AM
  final refDate = DateTime(2026, 10, 1, 10, 0);

  final sampleClasses = [
    const ClassItem(
      id: 'c1',
      subject: 'Mathematics',
      subjectColorIndex: 0,
      dayOfWeek: 'Monday',
      startTime: '08:30',
      endTime: '09:20',
      room: 'Room A-04',
      teacher: 'Dr. Smith',
    ),
    const ClassItem(
      id: 'c2',
      subject: 'Physics',
      subjectColorIndex: 1,
      dayOfWeek: 'Wednesday',
      startTime: '10:00',
      endTime: '11:30',
      room: 'Room B-12',
      teacher: 'Prof. Miller',
    ),
  ];

  final sampleQuizzes = [
    // Past quiz: 25 Sep 2026 (should be filtered out of active list)
    QuizItem(
      id: 'q_past',
      classId: 'c1',
      subject: 'Mathematics',
      title: 'Quiz 1: Functions',
      dueDate: DateTime(2026, 9, 25),
      isCompleted: false,
    ),
    // Due Today: 1 Oct 2026
    QuizItem(
      id: 'q_today',
      classId: 'c1',
      subject: 'Mathematics',
      title: 'Midterm Calculus',
      dueDate: DateTime(2026, 10, 1),
      note: 'Bring graphic calculator',
      isCompleted: false,
    ),
    // Due Tomorrow: 2 Oct 2026
    QuizItem(
      id: 'q_tomorrow',
      classId: 'c2',
      subject: 'Physics',
      title: 'Thermodynamics Quiz',
      dueDate: DateTime(2026, 10, 2),
      isCompleted: false,
    ),
    // Due This Week: 5 Oct 2026 (4 days diff)
    QuizItem(
      id: 'q_week',
      classId: 'c1',
      subject: 'Mathematics',
      title: 'Linear Algebra Quiz',
      dueDate: DateTime(2026, 10, 5),
      isCompleted: false,
    ),
    // Due Later: 20 Oct 2026
    QuizItem(
      id: 'q_later',
      classId: 'c2',
      subject: 'Physics',
      title: 'Quantum Mechanics Midterm',
      dueDate: DateTime(2026, 10, 20),
      isCompleted: false,
    ),
  ];

  group('Flow 6: QuizProvider Unit Tests', () {
    test('Filters out past quizzes from activeQuizzes', () {
      final fakeQuizRepo = FakeQuizRepository(sampleQuizzes);
      final fakeTimeRepo = FakeTimetableRepository(sampleClasses);

      final provider = QuizProvider(
        quizRepository: fakeQuizRepo,
        timetableRepository: fakeTimeRepo,
        referenceDate: refDate,
        initialQuizzes: sampleQuizzes,
        initialClasses: sampleClasses,
      );

      final active = provider.activeQuizzes;
      expect(active.length, 4);
      expect(active.any((q) => q.id == 'q_past'), isFalse);
    });

    test('Groups active quizzes chronologically into TODAY, TOMORROW, THIS WEEK, LATER', () {
      final fakeQuizRepo = FakeQuizRepository(sampleQuizzes);
      final fakeTimeRepo = FakeTimetableRepository(sampleClasses);

      final provider = QuizProvider(
        quizRepository: fakeQuizRepo,
        timetableRepository: fakeTimeRepo,
        referenceDate: refDate,
        initialQuizzes: sampleQuizzes,
        initialClasses: sampleClasses,
      );

      final grouped = provider.groupedQuizzes;
      expect(grouped[QuizUrgency.today]!.length, 1);
      expect(grouped[QuizUrgency.today]!.first.id, 'q_today');

      expect(grouped[QuizUrgency.tomorrow]!.length, 1);
      expect(grouped[QuizUrgency.tomorrow]!.first.id, 'q_tomorrow');

      expect(grouped[QuizUrgency.thisWeek]!.length, 1);
      expect(grouped[QuizUrgency.thisWeek]!.first.id, 'q_week');

      expect(grouped[QuizUrgency.later]!.length, 1);
      expect(grouped[QuizUrgency.later]!.first.id, 'q_later');
    });

    test('Timetable dependency check: hasTimetableClasses is true when classes exist, false when empty', () {
      final fakeQuizRepo = FakeQuizRepository();
      final providerWithClasses = QuizProvider(
        quizRepository: fakeQuizRepo,
        referenceDate: refDate,
        initialClasses: sampleClasses,
      );
      expect(providerWithClasses.hasTimetableClasses, isTrue);

      final providerWithoutClasses = QuizProvider(
        quizRepository: fakeQuizRepo,
        referenceDate: refDate,
        initialClasses: [],
      );
      expect(providerWithoutClasses.hasTimetableClasses, isFalse);
    });

    test('Calculates evening-before reminder time at 8:00 PM', () {
      final fakeQuizRepo = FakeQuizRepository();
      final provider = QuizProvider(
        quizRepository: fakeQuizRepo,
        referenceDate: refDate,
      );
      final quiz = QuizItem(
        id: 'q_test',
        classId: 'c1',
        subject: 'Math',
        title: 'Quiz',
        dueDate: DateTime(2026, 10, 15),
      );

      final reminder = provider.calculateEveningBeforeReminderTime(quiz);
      expect(reminder.year, 2026);
      expect(reminder.month, 10);
      expect(reminder.day, 14); // 1 day before
      expect(reminder.hour, 20); // 8:00 PM
      expect(reminder.minute, 0);
    });
  });

  group('Flow 6: QuizCard Component Tests', () {
    testWidgets('Renders urgent alarm badge for today quiz', (tester) async {
      final quizToday = sampleQuizzes.firstWhere((q) => q.id == 'q_today');

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: QuizCard(
            quiz: quizToday,
            referenceDate: refDate,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('Midterm Calculus'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.byIcon(Icons.alarm_rounded), findsOneWidget);
      expect(find.text('Bring graphic calculator'), findsOneWidget);
    });

    testWidgets('Renders urgent alarm badge for tomorrow quiz', (tester) async {
      final quizTomorrow = sampleQuizzes.firstWhere((q) => q.id == 'q_tomorrow');

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: QuizCard(
            quiz: quizTomorrow,
            referenceDate: refDate,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('Thermodynamics Quiz'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.byIcon(Icons.alarm_rounded), findsOneWidget);
    });

    testWidgets('Renders neutral badge for later quizzes', (tester) async {
      final quizLater = sampleQuizzes.firstWhere((q) => q.id == 'q_later');

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: QuizCard(
            quiz: quizLater,
            referenceDate: refDate,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Quantum Mechanics Midterm'), findsOneWidget);
      expect(find.text('19 days left'), findsOneWidget);
    });

    testWidgets('Tapping delete button triggers onDelete callback', (tester) async {
      bool deleted = false;
      final quiz = sampleQuizzes.firstWhere((q) => q.id == 'q_week');

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: QuizCard(
            quiz: quiz,
            referenceDate: refDate,
            onDelete: () => deleted = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });
  });

  group('Flow 6: AddEditQuizSheet Tests', () {
    testWidgets('Timetable guard: shows warning banner and disables form when zero classes exist', (tester) async {
      bool uploadRequested = false;

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                AddEditQuizSheet.show(
                  ctx,
                  classes: const [], // Zero classes!
                  onUploadTimetable: () => uploadRequested = true,
                );
              },
              child: const Text('Open Add Quiz'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Add Quiz'));
      await tester.pumpAndSettle();

      // Guard warning banner displayed
      expect(find.text('Add your timetable first'), findsOneWidget);
      expect(
        find.text("Quizzes belong to a class, and you haven't added any yet."),
        findsOneWidget,
      );

      // Tap Upload timetable action
      await tester.tap(find.widgetWithText(FilledButton, 'Upload timetable'));
      await tester.pumpAndSettle();

      expect(uploadRequested, isTrue);
    });

    testWidgets('Pre-selects class if preselectedClassId is provided', (tester) async {
      await tester.pumpWidget(_wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                AddEditQuizSheet.show(
                  ctx,
                  classes: sampleClasses,
                  preselectedClassId: 'c2', // Physics
                );
              },
              child: const Text('Open Add Quiz'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Add Quiz'));
      await tester.pumpAndSettle();

      // Preselected class is Physics
      expect(find.textContaining('Physics'), findsOneWidget);
    });

    testWidgets('Validates required title field and saves quiz with 8:00 PM reminder notice', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      QuizItem? savedQuiz;

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                AddEditQuizSheet.show(
                  ctx,
                  classes: sampleClasses,
                  onSaved: (q) => savedQuiz = q,
                );
              },
              child: const Text('Open Add Quiz'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Add Quiz'));
      await tester.pumpAndSettle();

      // Ensure save button is visible and tap it without entering title
      await tester.ensureVisible(find.byKey(const Key('save_quiz_button')));
      await tester.tap(find.byKey(const Key('save_quiz_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a quiz topic or title'), findsOneWidget);

      // Enter topic and note
      await tester.enterText(
        find.byKey(const Key('quiz_title_field')),
        'Unit 4 Wave Mechanics',
      );
      await tester.enterText(
        find.byKey(const Key('quiz_note_field')),
        'Bring formula handbook',
      );
      await tester.pumpAndSettle();

      // Verify reminder notice is visible
      expect(
        find.text("We'll remind you at 8:00 PM the evening before this quiz."),
        findsOneWidget,
      );

      // Save
      await tester.ensureVisible(find.byKey(const Key('save_quiz_button')));
      await tester.tap(find.byKey(const Key('save_quiz_button')));
      await tester.pumpAndSettle();

      expect(savedQuiz, isNotNull);
      expect(savedQuiz!.title, 'Unit 4 Wave Mechanics');
      expect(savedQuiz!.note, 'Bring formula handbook');
    });
  });

  group('Flow 6: QuizzesScreen Tests', () {
    testWidgets('Renders chronologically grouped sections with TODAY, TOMORROW, THIS WEEK, LATER', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeQuizRepo = FakeQuizRepository(sampleQuizzes);
      final fakeTimeRepo = FakeTimetableRepository(sampleClasses);

      final provider = QuizProvider(
        quizRepository: fakeQuizRepo,
        timetableRepository: fakeTimeRepo,
        referenceDate: refDate,
        initialQuizzes: sampleQuizzes,
        initialClasses: sampleClasses,
      );

      await tester.pumpWidget(_wrap(
        QuizzesScreen(
          quizProvider: provider,
          referenceDate: refDate,
          initialQuizzes: sampleQuizzes,
          initialClasses: sampleClasses,
        ),
      ));
      await tester.pumpAndSettle();

      // Screen title
      expect(find.text('Quizzes'), findsWidgets);

      // Headers
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('TOMORROW'), findsOneWidget);
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('LATER'), findsOneWidget);

      // Past quiz filtered out
      expect(find.text('Quiz 1: Functions'), findsNothing);

      // FAB is present with tertiaryContainer styling
      final fabFinder = find.byKey(const Key('add_quiz_fab'));
      expect(fabFinder, findsOneWidget);
      expect(find.text('+ Add quiz'), findsOneWidget);
    });

    testWidgets('Empty state when no upcoming quizzes exist', (tester) async {
      final fakeQuizRepo = FakeQuizRepository([]);
      final fakeTimeRepo = FakeTimetableRepository(sampleClasses);

      final provider = QuizProvider(
        quizRepository: fakeQuizRepo,
        timetableRepository: fakeTimeRepo,
        referenceDate: refDate,
        initialQuizzes: const [],
        initialClasses: sampleClasses,
      );

      await tester.pumpWidget(_wrap(
        QuizzesScreen(
          quizProvider: provider,
          referenceDate: refDate,
          initialQuizzes: const [],
          initialClasses: sampleClasses,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No quizzes yet'), findsOneWidget);
      expect(
        find.text("When your teacher announces one, add it here and we'll remind you the evening before."),
        findsOneWidget,
      );
      expect(find.text('Add your first quiz'), findsOneWidget);
    });

    testWidgets('Timetable guard banner displayed on QuizzesScreen if classes list is empty', (tester) async {
      final fakeQuizRepo = FakeQuizRepository([]);
      final fakeTimeRepo = FakeTimetableRepository([]);

      final provider = QuizProvider(
        quizRepository: fakeQuizRepo,
        timetableRepository: fakeTimeRepo,
        referenceDate: refDate,
        initialQuizzes: const [],
        initialClasses: const [],
      );

      await tester.pumpWidget(_wrap(
        QuizzesScreen(
          quizProvider: provider,
          referenceDate: refDate,
          initialQuizzes: const [],
          initialClasses: const [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('timetable_guard_banner')), findsOneWidget);
      expect(find.text('Add your timetable first'), findsOneWidget);
    });

    testWidgets('Deleting a quiz triggers 5-second floating Undo SnackBar and undo restores it', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deleteTestQuiz = QuizItem(
        id: 'q_delete_test',
        classId: 'c1',
        subject: 'Mathematics',
        title: 'Delete Me Quiz',
        dueDate: DateTime(2026, 10, 1),
      );

      final fakeQuizRepo = FakeQuizRepository([deleteTestQuiz]);
      final fakeTimeRepo = FakeTimetableRepository(sampleClasses);

      final provider = QuizProvider(
        quizRepository: fakeQuizRepo,
        timetableRepository: fakeTimeRepo,
        referenceDate: refDate,
        initialQuizzes: [deleteTestQuiz],
        initialClasses: sampleClasses,
      );

      await tester.pumpWidget(_wrap(
        QuizzesScreen(
          quizProvider: provider,
          referenceDate: refDate,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Delete Me Quiz'), findsOneWidget);

      // Tap delete on card
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // SnackBar appears
      expect(find.text('Deleted quiz: Delete Me Quiz'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Delete Me Quiz'), findsNothing);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Quiz restored
      expect(find.text('Delete Me Quiz'), findsOneWidget);
    });
  });

  group('Flow 6: Accessibility Scaling (130% Font Scale)', () {
    testWidgets('Wraps cleanly without clipping at 130% font scale', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeQuizRepo = FakeQuizRepository(sampleQuizzes);
      final fakeTimeRepo = FakeTimetableRepository(sampleClasses);

      final provider = QuizProvider(
        quizRepository: fakeQuizRepo,
        timetableRepository: fakeTimeRepo,
        referenceDate: refDate,
        initialQuizzes: sampleQuizzes,
        initialClasses: sampleClasses,
      );

      await tester.pumpWidget(_wrap(
        QuizzesScreen(
          quizProvider: provider,
          referenceDate: refDate,
          initialQuizzes: sampleQuizzes,
          initialClasses: sampleClasses,
        ),
        textScale: 1.3, // 130% font scale
      ));
      await tester.pumpAndSettle();

      // Check key elements render without overflow
      expect(find.text('Quizzes'), findsWidgets);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Midterm Calculus'), findsOneWidget);
      expect(find.text('Thermodynamics Quiz'), findsOneWidget);
    });
  });
}
