import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/core/theme/app_theme.dart';
import 'package:nextclass/data/models/class_item.dart';
import 'package:nextclass/ui/shared/class_card.dart';
import 'package:nextclass/ui/shared/day_chips.dart';
import 'package:nextclass/ui/shared/google_button.dart';
import 'package:nextclass/ui/shared/live_progress_bar.dart';
import 'package:nextclass/ui/shared/nc_banner.dart';
import 'package:nextclass/ui/shared/undo_snackbar.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  const sampleClass = ClassItem(
    id: 'class_1',
    subject: 'Computer Science',
    subjectColorIndex: 0,
    dayOfWeek: 'Monday',
    startTime: '09:30',
    endTime: '10:20',
    room: 'Lab 2',
    teacher: 'Ms. Sara',
  );

  group('ClassCard Widget Tests', () {
    testWidgets('Renders default state with subject and room', (tester) async {
      await tester.pumpWidget(_wrap(
        const ClassCard(
          classItem: sampleClass,
          state: ClassCardState.defaultState,
        ),
      ));

      expect(find.text('Computer Science'), findsOneWidget);
      expect(find.text('09:30 – 10:20'), findsOneWidget);
      expect(find.text('Lab 2'), findsOneWidget);
      expect(find.text('Ms. Sara'), findsOneWidget);
    });

    testWidgets('Renders current state with "Now" badge and LiveProgressBar', (tester) async {
      await tester.pumpWidget(_wrap(
        const ClassCard(
          classItem: sampleClass,
          state: ClassCardState.current,
        ),
      ));

      expect(find.text('Now'), findsOneWidget);
      expect(find.byType(LiveProgressBar), findsOneWidget);
    });

    testWidgets('Renders next state with "in 25 min" pill', (tester) async {
      await tester.pumpWidget(_wrap(
        const ClassCard(
          classItem: sampleClass,
          state: ClassCardState.next,
          minutesUntilNext: 20,
        ),
      ));

      expect(find.text('in 20 min'), findsOneWidget);
    });

    testWidgets('Renders past state with "Done" badge', (tester) async {
      await tester.pumpWidget(_wrap(
        const ClassCard(
          classItem: sampleClass,
          state: ClassCardState.past,
        ),
      ));

      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Renders editable state with "Check" pill when AI unsure', (tester) async {
      final unsureClass = sampleClass.copyWith(isAiUnsure: true);

      await tester.pumpWidget(_wrap(
        ClassCard(
          classItem: unsureClass,
          state: ClassCardState.editable,
          onEdit: () {},
          onDelete: () {},
        ),
      ));

      expect(find.text('Check'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('Renders compact mode for week view', (tester) async {
      await tester.pumpWidget(_wrap(
        const ClassCard(
          classItem: sampleClass,
          state: ClassCardState.compact,
        ),
      ));

      expect(find.text('Computer Science'), findsOneWidget);
      expect(find.text('09:30 – 10:20 · Lab 2'), findsOneWidget);
    });

    testWidgets('Swipe to delete triggers dismiss callback', (tester) async {
      bool deleted = false;

      await tester.pumpWidget(_wrap(
        ClassCard(
          classItem: sampleClass,
          state: ClassCardState.defaultState,
          enableSwipeToDelete: true,
          onDelete: () => deleted = true,
        ),
      ));

      // Drag left to dismiss
      await tester.drag(find.byType(ClassCard), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });
  });

  group('LiveProgressBar Tests', () {
    testWidgets('Renders bar with given start/end time', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(
        LiveProgressBar(
          startTime: now.subtract(const Duration(minutes: 15)),
          endTime: now.add(const Duration(minutes: 15)),
        ),
      ));

      expect(find.byType(LiveProgressBar), findsOneWidget);
    });
  });

  group('NcBanner Tests', () {
    testWidgets('Renders warning, permission, and offline banners', (tester) async {
      await tester.pumpWidget(_wrap(
        Column(
          children: [
            NcBanner.aiWarning(),
            NcBanner.permission(onTurnOn: () {}),
            NcBanner.offline(),
          ],
        ),
      ));

      expect(find.text("We weren't sure about a few classes."), findsOneWidget);
      expect(find.text('Reminders are off'), findsOneWidget);
      expect(find.text("You're offline. Showing your saved timetable."), findsOneWidget);
    });
  });

  group('GoogleButton Tests', () {
    testWidgets('Renders standard label and handles click', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_wrap(
        GoogleButton(onPressed: () => tapped = true),
      ));

      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.tap(find.byType(GoogleButton));
      expect(tapped, isTrue);
    });

    testWidgets('Renders loading state', (tester) async {
      await tester.pumpWidget(_wrap(
        GoogleButton(onPressed: () {}, isLoading: true),
      ));

      expect(find.text('Signing in…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('DayChips Tests', () {
    testWidgets('Renders Mon through Sun and triggers selection', (tester) async {
      int selected = 0;
      await tester.pumpWidget(_wrap(
        DayChips(
          selectedDayIndex: 1,
          todayIndex: 3,
          dayNumbers: const [29, 30, 1, 2, 3, 4, 5],
          onDaySelected: (idx) => selected = idx,
        ),
      ));

      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.text('Fri'));
      expect(selected, 4); // Friday index is 4
    });
  });

  group('UndoSnackBar Tests', () {
    testWidgets('Displays floating snackbar and triggers undo', (tester) async {
      bool undone = false;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                UndoSnackBar.show(
                  ctx,
                  message: 'Physics deleted',
                  onUndo: () => undone = true,
                );
              },
              child: const Text('Show SnackBar'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show SnackBar'));
      await tester.pumpAndSettle();

      expect(find.text('Physics deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      expect(undone, isTrue);
    });
  });
}
