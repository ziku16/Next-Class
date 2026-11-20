import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/core/theme/app_theme.dart';
import 'package:nextclass/data/models/class_item.dart';
import 'package:nextclass/data/models/exam_item.dart';
import 'package:nextclass/data/models/exam_schedule.dart';
import 'package:nextclass/data/models/quiz_item.dart';
import 'package:nextclass/domain/services/academic_schedule_service.dart';
import 'package:nextclass/state/exam_provider.dart';
import 'package:nextclass/state/quiz_provider.dart';
import 'package:nextclass/ui/exams/exam_management_screen.dart';
import 'package:nextclass/ui/home/today_screen.dart';
import 'package:nextclass/ui/quizzes/quizzes_screen.dart';
import 'package:nextclass/ui/week/week_screen.dart';

const _viewport = Size(1080, 2400);
const _pixelRatio = 3.0;
final _referenceDate = DateTime(2026, 11, 23, 7, 15);
const _rootKey = Key('screenshot-root');

const _classes = <ClassItem>[
  ClassItem(
    id: 'demo-algorithms',
    subject: 'Algorithms',
    subjectColorIndex: 0,
    dayOfWeek: 'Monday',
    startTime: '08:30',
    endTime: '09:45',
    room: 'CS Lab 2',
    teacher: 'Dr. Ayesha Khan',
  ),
  ClassItem(
    id: 'demo-databases',
    subject: 'Database Systems',
    subjectColorIndex: 1,
    dayOfWeek: 'Monday',
    startTime: '10:00',
    endTime: '11:15',
    room: 'Block B · 204',
    teacher: 'Mr. Hamza Ali',
  ),
  ClassItem(
    id: 'demo-networks',
    subject: 'Computer Networks',
    subjectColorIndex: 2,
    dayOfWeek: 'Tuesday',
    startTime: '09:00',
    endTime: '10:15',
    room: 'Engineering 108',
    teacher: 'Dr. Sana Malik',
  ),
  ClassItem(
    id: 'demo-ai',
    subject: 'Artificial Intelligence',
    subjectColorIndex: 3,
    dayOfWeek: 'Wednesday',
    startTime: '11:00',
    endTime: '12:15',
    room: 'CS Lab 1',
    teacher: 'Dr. Bilal Ahmed',
  ),
  ClassItem(
    id: 'demo-design',
    subject: 'Software Design',
    subjectColorIndex: 4,
    dayOfWeek: 'Thursday',
    startTime: '13:00',
    endTime: '14:15',
    room: 'Block A · 301',
    teacher: 'Ms. Noor Fatima',
  ),
  ClassItem(
    id: 'demo-math',
    subject: 'Discrete Mathematics',
    subjectColorIndex: 5,
    dayOfWeek: 'Friday',
    startTime: '10:30',
    endTime: '11:45',
    room: 'Science 12',
    teacher: 'Dr. Usman Raza',
  ),
];

final _quizzes = <QuizItem>[
  QuizItem(
    id: 'demo-quiz-algorithms',
    classId: 'demo-algorithms',
    subject: 'Algorithms',
    title: 'Graph Theory Quiz',
    dueDate: DateTime(2026, 11, 23),
    note: 'Shortest paths and spanning trees',
  ),
  QuizItem(
    id: 'demo-quiz-database',
    classId: 'demo-databases',
    subject: 'Database Systems',
    title: 'SQL Practice',
    dueDate: DateTime(2026, 11, 25),
    note: 'Joins, grouping, and subqueries',
  ),
  QuizItem(
    id: 'demo-quiz-networks',
    classId: 'demo-networks',
    subject: 'Computer Networks',
    title: 'Network Layers',
    dueDate: DateTime(2026, 11, 30),
  ),
];

final _schedule = ExamSchedule(
  id: 'demo-exams',
  program: 'BS Computer Science',
  semester: 'Semester 5',
  section: 'BCS-5A',
  isActive: true,
  createdAt: DateTime(2026, 11, 1),
);

final _exams = <ExamItem>[
  ExamItem(
    id: 'demo-exam-algorithms',
    scheduleId: 'demo-exams',
    subject: 'Algorithms',
    examDate: DateTime(2026, 11, 23),
    startTime: '09:00',
    endTime: '12:00',
    venue: 'Main Hall · 2',
    examType: 'Final',
  ),
  ExamItem(
    id: 'demo-exam-database',
    scheduleId: 'demo-exams',
    subject: 'Database Systems',
    examDate: DateTime(2026, 11, 25),
    startTime: '13:00',
    endTime: '16:00',
    venue: 'Block B · 204',
    examType: 'Final',
  ),
];

class _DemoExamProvider extends ExamProvider {
  _DemoExamProvider({this.includeSchedule = true}) : super();

  final bool includeSchedule;

  @override
  Future<void> loadData() async {}

  @override
  List<ExamSchedule> get schedules => includeSchedule ? [_schedule] : [];

  @override
  ExamSchedule? get activeSchedule => includeSchedule ? _schedule : null;

  @override
  List<ExamItem> get activeExams => includeSchedule ? _exams : [];

  @override
  bool isExamMode(DateTime date) =>
      includeSchedule && AcademicScheduleService.isExamMode(_exams, date);

  @override
  List<ExamItem> examsForDate(DateTime date) {
    if (!includeSchedule) return [];
    final target = AcademicScheduleService.calendarDate(date);
    return _exams
        .where(
          (exam) =>
              AcademicScheduleService.calendarDate(exam.examDate) == target,
        )
        .toList();
  }
}

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = _viewport;
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: screen,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _captureCurrent(WidgetTester tester, String fileName) async {
  await expectLater(
    find.byKey(_rootKey),
    matchesGoldenFile('../webapp/public/images/screenshots/$fileName'),
  );
}

QuizProvider _demoQuizProvider() => QuizProvider(
  referenceDate: _referenceDate,
  initialQuizzes: _quizzes,
  initialClasses: _classes,
);

void main() {
  setUpAll(() async {
    final fontLoader = FontLoader('SpaceGrotesk')
      ..addFont(rootBundle.load('assets/fonts/SpaceGrotesk.ttf'));
    await fontLoader.load();
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null || flutterRoot.isEmpty) {
      throw StateError('FLUTTER_ROOT is required for screenshot goldens.');
    }
    final iconBytes = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytesSync();
    final iconFontLoader = FontLoader('MaterialIcons')
      ..addFont(Future<ByteData>.value(ByteData.sublistView(iconBytes)));
    await iconFontLoader.load();
  });
  testWidgets('captures the Today Dashboard from the Flutter widget tree', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      TodayScreen(
        currentTime: _referenceDate,
        initialClasses: _classes,
        initialQuizzes: _quizzes,
        isOffline: false,
        remindersEnabled: true,
      ),
    );
    expect(find.text('Upcoming quizzes'), findsOneWidget);
    expect(find.text('Graph Theory Quiz'), findsOneWidget);
    expect(find.text('Good morning'), findsNothing);
    expect(find.text('OCT0221 / CLASSIFY'), findsNothing);
    await _captureCurrent(tester, 'today.png');
  });

  testWidgets('captures the Weekly Timetable from the Flutter widget tree', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      WeekScreen(
        referenceDate: _referenceDate,
        initialClasses: _classes,
        isOffline: false,
      ),
    );
    await _captureCurrent(tester, 'week.png');
  });

  testWidgets('captures Quiz Management from the Flutter widget tree', (
    tester,
  ) async {
    final provider = _demoQuizProvider();
    addTearDown(provider.dispose);
    await _pumpScreen(
      tester,
      QuizzesScreen(
        quizProvider: provider,
        referenceDate: _referenceDate,
        initialClasses: _classes,
        isOffline: false,
      ),
    );
    expect(find.text('3 UPCOMING'), findsNothing);
    await _captureCurrent(tester, 'quizzes.png');
  });

  testWidgets('captures the Add Quiz sheet from the Flutter widget tree', (
    tester,
  ) async {
    final provider = _demoQuizProvider();
    addTearDown(provider.dispose);
    await _pumpScreen(
      tester,
      QuizzesScreen(
        quizProvider: provider,
        referenceDate: _referenceDate,
        initialClasses: _classes,
        isOffline: false,
      ),
    );
    await tester.tap(find.byType(FilledButton).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await _captureCurrent(tester, 'add-quiz.png');
  });

  testWidgets(
    'captures the Examination Schedule from the Flutter widget tree',
    (tester) async {
      final provider = _DemoExamProvider();
      addTearDown(provider.dispose);
      await _pumpScreen(tester, ExamManagementScreen(provider: provider));
      expect(find.text('Upcoming exams'), findsOneWidget);
      expect(find.text('ACTIVE SCHEDULE'), findsNothing);
      await _captureCurrent(tester, 'exams.png');
    },
  );

  testWidgets('captures Automatic Exam Mode from the Flutter widget tree', (
    tester,
  ) async {
    final provider = _DemoExamProvider();
    expect(provider.isExamMode(_referenceDate), isTrue);
    addTearDown(provider.dispose);
    await _pumpScreen(
      tester,
      TodayScreen(
        currentTime: _referenceDate,
        initialClasses: _classes,
        initialQuizzes: _quizzes,
        isOffline: false,
        remindersEnabled: true,
        examProvider: provider,
      ),
    );
    expect(find.text('EXAM MODE'), findsOneWidget);
    await _captureCurrent(tester, 'exam-mode.png');
  });

  testWidgets(
    'captures the exam date-sheet import identity step from the Flutter widget tree',
    (tester) async {
      const channel = MethodChannel('com.nextclass.app/device_info');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => <String, Object?>{
              'name': 'Finals.xlsx',
              'bytes': Uint8List.fromList([0]),
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final provider = _DemoExamProvider(includeSchedule: false);
      addTearDown(provider.dispose);
      await _pumpScreen(tester, ExamManagementScreen(provider: provider));
      await tester.tap(find.text('Import exam date sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Your student group'), findsOneWidget);
      await _captureCurrent(tester, 'exam-import.png');
    },
  );
}
