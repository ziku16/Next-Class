import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/core/theme/app_theme.dart';
import 'package:nextclass/data/models/class_item.dart';
import 'package:nextclass/ui/week/class_detail_sheet.dart';
import 'package:nextclass/ui/week/day_selector_strip.dart';
import 'package:nextclass/ui/week/week_screen.dart';

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
  // Reference week: Monday 28 Sep 2026 to Sunday 4 Oct 2026
  // Wednesday is 30 Sep, Thursday is 1 Oct, Friday is 2 Oct, Saturday is 3 Oct, Sunday is 4 Oct.
  // Let's use Thursday 1 Oct 2026 as reference date
  final refDate = DateTime(2026, 10, 1, 10, 0); // Thursday

  final sampleClasses = [
    const ClassItem(
      id: 'c1',
      subject: 'Mathematics',
      subjectColorIndex: 0,
      dayOfWeek: 'Wednesday',
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
      startTime: '09:30',
      endTime: '10:20',
      room: 'Room B-12',
      teacher: 'Prof. Miller',
    ),
    const ClassItem(
      id: 'c3',
      subject: 'Computer Science',
      subjectColorIndex: 3,
      dayOfWeek: 'Thursday',
      startTime: '10:45',
      endTime: '11:30',
      room: 'Lab 2',
      teacher: 'Ms. Sara',
    ),
  ];

  group('Flow 5: DaySelectorStrip Tests', () {
    testWidgets('Renders 7 day chips with abbreviations and numbers', (tester) async {
      int selected = 3; // Thursday

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: DaySelectorStrip(
            referenceDate: refDate,
            selectedDayIndex: selected,
            onDaySelected: (idx) => selected = idx,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Check day abbreviations
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);

      // Tap Wednesday chip (index 2)
      await tester.tap(find.byKey(const Key('day_chip_2')));
      await tester.pumpAndSettle();

      expect(selected, 2);
    });
  });

  group('Flow 5: ClassDetailSheet Tests', () {
    testWidgets('Renders full metadata, Add Quiz action, and Edit Class action', (tester) async {
      bool addQuizTriggered = false;
      bool editClassTriggered = false;

      const testClass = ClassItem(
        id: 'c_detail',
        subject: 'Artificial Intelligence',
        subjectColorIndex: 2,
        dayOfWeek: 'Friday',
        startTime: '14:00',
        endTime: '15:30',
        room: 'Auditorium 1',
        teacher: 'Dr. Alan Turing',
      );

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                ClassDetailSheet.show(
                  ctx,
                  classItem: testClass,
                  onAddQuiz: () => addQuizTriggered = true,
                  onEditClass: () => editClassTriggered = true,
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Subject and interval
      expect(find.text('Artificial Intelligence'), findsOneWidget);
      expect(find.text('Friday · 14:00 – 15:30'), findsOneWidget);

      // Room and Teacher
      expect(find.text('Auditorium 1'), findsOneWidget);
      expect(find.byIcon(Icons.meeting_room_outlined), findsOneWidget);
      expect(find.text('Dr. Alan Turing'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);

      // Primary and Secondary Action Buttons
      expect(find.widgetWithText(FilledButton, 'Add quiz for this class'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Edit class'), findsOneWidget);

      // Tap Add quiz
      await tester.tap(find.widgetWithText(FilledButton, 'Add quiz for this class'));
      await tester.pumpAndSettle();
      expect(addQuizTriggered, isTrue);

      // Open again and tap Edit class
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Edit class'));
      await tester.pumpAndSettle();
      expect(editClassTriggered, isTrue);
    });
  });

  group('Flow 5: WeekScreen Grouped Day Stream & Empty State Tests', () {
    testWidgets('keeps the week date and classes visible without broken week arrows', (tester) async {
      await tester.pumpWidget(_wrap(
        WeekScreen(
          referenceDate: refDate,
          initialClasses: sampleClasses,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Previous week'), findsNothing);
      expect(find.byTooltip('Next week'), findsNothing);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.text('01'), findsOneWidget);
      expect(find.text('OCTOBER'), findsOneWidget);
      expect(find.text('2026'), findsWidgets);
      expect(find.text('Computer Science'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders all 7 days with section headers, compact cards, and empty day states', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(
        WeekScreen(
          referenceDate: refDate,
          initialClasses: sampleClasses,
        ),
      ));
      await tester.pumpAndSettle();

      // Week title
      expect(find.text('Week'), findsWidgets);

      // Wednesday has 2 classes
      expect(find.textContaining('Wednesday'), findsWidgets);
      expect(find.textContaining('2 classes'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('Physics'), findsOneWidget);

      // Thursday has 1 class
      expect(find.textContaining('Thursday'), findsWidgets);
      expect(find.textContaining('1 class'), findsOneWidget);
      expect(find.text('Computer Science'), findsOneWidget);

      // Empty day state for days with 0 classes
      expect(find.text('No classes scheduled for Monday'), findsOneWidget);
      expect(find.text('No classes scheduled for Tuesday'), findsOneWidget);
    });

    testWidgets('Tapping compact class card in Week view opens ClassDetailSheet', (tester) async {
      ClassItem? quizClassTapped;

      await tester.pumpWidget(_wrap(
        WeekScreen(
          referenceDate: refDate,
          initialClasses: sampleClasses,
          onAddQuizForClass: (item) => quizClassTapped = item,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap on Mathematics card
      await tester.tap(find.text('Mathematics'));
      await tester.pumpAndSettle();

      // ClassDetailSheet is open
      expect(find.widgetWithText(FilledButton, 'Add quiz for this class'), findsOneWidget);
      expect(find.text('Dr. Smith'), findsOneWidget);

      // Tap Add quiz
      await tester.tap(find.widgetWithText(FilledButton, 'Add quiz for this class'));
      await tester.pumpAndSettle();

      expect(quizClassTapped, isNotNull);
      expect(quizClassTapped!.subject, 'Mathematics');
    });

    testWidgets('Smooth scrolling: tapping day in DaySelectorStrip scrolls to that section', (tester) async {
      await tester.pumpWidget(_wrap(
        WeekScreen(
          referenceDate: refDate,
          initialClasses: sampleClasses,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap Friday chip (index 4)
      await tester.tap(find.byKey(const Key('day_chip_4')));
      await tester.pumpAndSettle();

      // Friday section is in view
      expect(find.textContaining('Friday'), findsWidgets);
      expect(find.text('No classes scheduled for Friday'), findsOneWidget);
    });
  });

  group('Flow 5: Accessibility Scale (130% Font Scale)', () {
    testWidgets('Wraps cleanly without clipping at 130% font scale', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(
        WeekScreen(
          referenceDate: refDate,
          initialClasses: sampleClasses,
        ),
        textScale: 1.3, // 130% font scale
      ));
      await tester.pumpAndSettle();

      // Check key text elements render without error
      expect(find.text('Week'), findsWidgets);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('Computer Science'), findsOneWidget);

      // Open detail sheet at 130% font scale
      await tester.tap(find.text('Computer Science'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Add quiz for this class'), findsOneWidget);
      expect(find.text('Ms. Sara'), findsOneWidget);
    });
  });
}
