import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/core/theme/app_theme.dart';
import 'package:nextclass/data/database/app_database.dart';
import 'package:nextclass/data/models/class_item.dart';
import 'package:nextclass/data/repositories/timetable_repository.dart';
import 'package:nextclass/state/timetable_provider.dart';
import 'package:nextclass/ui/review/discard_dialog.dart';
import 'package:nextclass/ui/review/edit_class_sheet.dart';
import 'package:nextclass/ui/review/review_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

class FakeTimetableRepository extends TimetableRepository {
  List<ClassItem> storedClasses = [];

  @override
  Future<List<ClassItem>> getAllClasses() async => List.unmodifiable(storedClasses);

  @override
  Future<void> replaceAllClasses(List<ClassItem> classes) async {
    storedClasses = List.from(classes);
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final testClasses = [
    const ClassItem(
      id: 'c1',
      subject: 'Mathematics',
      subjectColorIndex: 0,
      dayOfWeek: 'Monday',
      startTime: '08:30',
      endTime: '09:20',
      room: 'Room A-04',
      teacher: 'Dr. Smith',
      isAiUnsure: false,
    ),
    const ClassItem(
      id: 'c2',
      subject: 'Physics',
      subjectColorIndex: 1,
      dayOfWeek: 'Monday',
      startTime: '09:30',
      endTime: '10:20',
      room: 'Room B-12',
      isAiUnsure: true,
    ),
    const ClassItem(
      id: 'c3',
      subject: 'English',
      subjectColorIndex: 2,
      dayOfWeek: 'Tuesday',
      startTime: '08:30',
      endTime: '09:20',
      isAiUnsure: false,
    ),
  ];

  group('Flow 3 (Review & Edit Timetable) Widget Tests', () {
    testWidgets('ReviewScreen renders header, banners, day groups, and save buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = TimetableProvider(
        initialClasses: testClasses,
      );

      await tester.pumpWidget(_wrap(ReviewScreen(timetableProvider: provider)));
      await tester.pumpAndSettle();

      // Top App Bar
      expect(find.text('Check your classes'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);

      // Bottom sticky bar
      expect(find.widgetWithText(FilledButton, 'Save timetable'), findsOneWidget);

      // AI confidence warning banner should appear because c2.isAiUnsure == true
      expect(find.text("We weren't sure about a few classes."), findsOneWidget);
      expect(find.text('Please double-check the highlighted ones.'), findsOneWidget);

      // Check badge on the unsure card
      expect(find.text('Check'), findsOneWidget);

      // Day headers
      expect(find.text('Monday · 2 classes'), findsOneWidget);
      expect(find.text('Tuesday · 1 class'), findsOneWidget);
      expect(find.text('Wednesday · 0 classes'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Hide empty days switch collapses days without classes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = TimetableProvider(
        initialClasses: testClasses,
      );

      await tester.pumpWidget(_wrap(ReviewScreen(timetableProvider: provider)));
      await tester.pumpAndSettle();

      expect(find.text('Wednesday · 0 classes'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsWidgets);

      // Toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(provider.hideEmptyDays, isTrue);
      // Empty days must now be collapsed
      expect(find.text('Wednesday · 0 classes'), findsNothing);
      expect(find.text('Thursday · 0 classes'), findsNothing);
      expect(find.text('Nothing here yet'), findsNothing);

      // Non-empty days remain visible
      expect(find.text('Monday · 2 classes'), findsOneWidget);
      expect(find.text('Tuesday · 1 class'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('EditClassSheet validates subject and end-after-start time', (tester) async {
      ClassItem? savedItem;

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: AppTheme.light.colorScheme,
          extensions: AppTheme.light.extensions.values,
        ),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                savedItem = await EditClassSheet.show(ctx, defaultDay: 'Wednesday');
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

      expect(find.text('Add class'), findsOneWidget);
      expect(find.text('Save class'), findsOneWidget);

      // Initially Subject is empty, so Save button should be disabled
      final saveBtn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save class'));
      expect(saveBtn.onPressed, isNull);

      // Enter Subject name into first TextField
      await tester.enterText(find.byType(TextField).first, 'Discrete Math');
      await tester.pump();

      // Now with valid subject and default times (08:30 - 09:20), Save button is enabled
      final saveBtnEnabled = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save class'));
      expect(saveBtnEnabled.onPressed, isNotNull);

      // Tap Save class
      await tester.tap(find.widgetWithText(FilledButton, 'Save class'));
      await tester.pumpAndSettle();

      expect(savedItem, isNotNull);
      expect(savedItem!.subject, 'Discrete Math');
      expect(savedItem!.dayOfWeek, 'Wednesday');
      expect(savedItem!.startTime, '08:30');
      expect(savedItem!.endTime, '09:20');

      // Now test validation when End time is before Start time
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Close and open with an initialClass having invalid time: 10:30 - 09:30
      Navigator.of(tester.element(find.text('Add class'))).pop();
      await tester.pumpAndSettle();

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: AppTheme.light.colorScheme,
          extensions: AppTheme.light.extensions.values,
        ),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                savedItem = await EditClassSheet.show(
                  ctx,
                  initialClass: const ClassItem(
                    id: 'invalid_time',
                    subject: 'Physics Lab',
                    subjectColorIndex: 1,
                    dayOfWeek: 'Friday',
                    startTime: '10:30',
                    endTime: '09:30',
                  ),
                );
              },
              child: const Text('Open Invalid Sheet'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Invalid Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Edit class'), findsOneWidget);
      expect(find.text('Must be after start'), findsOneWidget);
      final saveBtnInvalid = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save class'));
      expect(saveBtnInvalid.onPressed, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('DiscardDialog confirms discarding edits', (tester) async {
      bool? result;

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: AppTheme.light.colorScheme,
          extensions: AppTheme.light.extensions.values,
        ),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await DiscardDialog.show(ctx);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text("You've edited your classes but haven't saved. If you leave now, those changes will be lost."), findsOneWidget);

      // Tap Keep editing -> returns false
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      // Open again and tap Discard -> returns true
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(result, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Deleting class shows 5s UndoSnackBar and restores on undo', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = TimetableProvider(
        initialClasses: testClasses,
      );

      await tester.pumpWidget(_wrap(ReviewScreen(timetableProvider: provider)));
      await tester.pumpAndSettle();

      expect(provider.classes.length, 3);

      // Tap delete on first class
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(provider.classes.length, 2);
      expect(find.text('Class deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(provider.classes.length, 3);

      // Wait out SnackBar timer
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Navigation safety: Back with unsaved changes shows DiscardDialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = TimetableProvider(
        initialClasses: testClasses,
      );

      bool discardTriggered = false;

      await tester.pumpWidget(_wrap(ReviewScreen(
        timetableProvider: provider,
        onDiscard: () => discardTriggered = true,
      )));
      await tester.pumpAndSettle();

      // Modify timetable by deleting one class
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();
      expect(provider.hasUnsavedChanges, isTrue);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Discard dialog must be displayed
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text("You've edited your classes but haven't saved. If you leave now, those changes will be lost."), findsOneWidget);

      // Tap Keep editing
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(discardTriggered, isFalse);

      // Tap back again and choose Discard
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(discardTriggered, isTrue);

      // Wait out SnackBar timer
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('ReviewScreen saves timetable and triggers Chalo SnackBar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeTimetableRepository();
      final provider = TimetableProvider(
        timetableRepository: fakeRepo,
        initialClasses: testClasses,
      );

      bool savedCallbackTriggered = false;

      await tester.pumpWidget(_wrap(ReviewScreen(
        timetableProvider: provider,
        onSaved: () => savedCallbackTriggered = true,
      )));
      await tester.pumpAndSettle();

      // Tap Save timetable button
      await tester.tap(find.widgetWithText(FilledButton, 'Save timetable'));
      await tester.pumpAndSettle();

      expect(savedCallbackTriggered, isTrue);
      expect(find.text('Timetable saved. Chalo!'), findsOneWidget);
      expect(fakeRepo.storedClasses.length, 3);
      expect(fakeRepo.storedClasses.first.subject, 'Mathematics');

      // Wait out SnackBar timer
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('Flow 3 SQLite Database Integration Tests', () {
    test('TimetableProvider.saveTimetable() persists classes to SQLite and clears unsaved changes', () async {
      final dbManager = await AppDatabase.createInMemory();
      final repo = TimetableRepository(dbManager: dbManager);
      final provider = TimetableProvider(
        timetableRepository: repo,
        initialClasses: testClasses,
      );

      expect(provider.hasUnsavedChanges, isFalse);

      // Add a class
      provider.addClass(const ClassItem(
        id: 'c4',
        subject: 'Database Systems',
        subjectColorIndex: 3,
        dayOfWeek: 'Wednesday',
        startTime: '11:00',
        endTime: '12:00',
      ));
      expect(provider.hasUnsavedChanges, isTrue);
      expect(provider.classes.length, 4);

      // Save to SQLite
      final success = await provider.saveTimetable();
      expect(success, isTrue);
      expect(provider.hasUnsavedChanges, isFalse);

      // Verify records are stored in SQLite
      final classesInDb = await repo.getAllClasses();
      expect(classesInDb.length, 4);
      expect(classesInDb.any((c) => c.subject == 'Database Systems'), isTrue);

      await dbManager.close();
    });
  });
}
