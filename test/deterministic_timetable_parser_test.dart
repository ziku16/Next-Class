import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/data/database/app_database.dart';
import 'package:nextclass/data/repositories/timetable_repository.dart';
import 'package:nextclass/domain/parser/day_detector.dart';
import 'package:nextclass/domain/parser/deterministic_class_parser.dart';
import 'package:nextclass/domain/parser/grid_cell_assigner.dart';
import 'package:nextclass/domain/parser/local_ocr_engine.dart';
import 'package:nextclass/domain/parser/ocr_models.dart';
import 'package:nextclass/domain/parser/time_detector.dart';
import 'package:nextclass/domain/parser/timetable_grid_detector.dart';
import 'package:nextclass/domain/services/timetable_scanner_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('1. TimeDetector Tests', () {
    const detector = TimeDetector();

    test('Parses explicit time ranges in various formats', () {
      // Hyphen range
      final r1 = detector.parseTimeRange('08:00 - 09:20');
      expect(r1, isNotNull);
      expect(r1!.startTime, '08:00');
      expect(r1.endTime, '09:20');
      expect(r1.hasExplicitEndTime, isTrue);

      // En-dash range
      final r2 = detector.parseTimeRange('09:30 – 10:20');
      expect(r2, isNotNull);
      expect(r2!.startTime, '09:30');
      expect(r2.endTime, '10:20');

      // Compact range without spaces
      final r3 = detector.parseTimeRange('11:00-12:40');
      expect(r3, isNotNull);
      expect(r3!.startTime, '11:00');
      expect(r3.endTime, '12:40');

      // 'to' word separator
      final r4 = detector.parseTimeRange('8:30 to 9:20');
      expect(r4, isNotNull);
      expect(r4!.startTime, '08:30');
      expect(r4.endTime, '09:20');

      // 12-hour AM/PM format
      final r5 = detector.parseTimeRange('1:00 PM - 2:30 PM');
      expect(r5, isNotNull);
      expect(r5!.startTime, '13:00');
      expect(r5.endTime, '14:30');
    });

    test('Parses single time headers and normalizes afternoon hours', () {
      // Single time 8:00
      final s1 = detector.parseTimeRange('8:00 AM');
      expect(s1, isNotNull);
      expect(s1!.startTime, '08:00');

      // Single afternoon hour 2:00 without explicit PM
      final s2 = detector.parseTimeRange('2:00');
      expect(s2, isNotNull);
      expect(s2!.startTime, '14:00'); // 2 + 12 = 14:00
    });

    test('Filters out non-time strings and noise', () {
      expect(detector.parseTimeRange('Physics Room B-12'), isNull);
      expect(detector.parseTimeRange('Prof. Miller'), isNull);
      expect(detector.parseTimeRange('---'), isNull);
    });
  });

  group('2. DayDetector Tests', () {
    const detector = DayDetector();

    test('Matches weekday names and common abbreviations', () {
      expect(DayDetector.matchDay('Monday'), 'Monday');
      expect(DayDetector.matchDay('MON'), 'Monday');
      expect(DayDetector.matchDay('mon'), 'Monday');
      expect(DayDetector.matchDay('Tuesday'), 'Tuesday');
      expect(DayDetector.matchDay('TUE'), 'Tuesday');
      expect(DayDetector.matchDay('Wed'), 'Wednesday');
      expect(DayDetector.matchDay('WED'), 'Wednesday');
      expect(DayDetector.matchDay('Thursday'), 'Thursday');
      expect(DayDetector.matchDay('THU'), 'Thursday');
      expect(DayDetector.matchDay('Friday'), 'Friday');
      expect(DayDetector.matchDay('FRI'), 'Friday');
    });

    test('Finds day headers from spatial OCR lines and sorts left-to-right', () {
      final lines = [
        const OcrTextLine(text: 'FRI', boundingBox: Rect.fromLTWH(800, 50, 100, 30)),
        const OcrTextLine(text: 'MON', boundingBox: Rect.fromLTWH(200, 50, 100, 30)),
        const OcrTextLine(text: 'WED', boundingBox: Rect.fromLTWH(500, 50, 100, 30)),
        const OcrTextLine(text: 'TUE', boundingBox: Rect.fromLTWH(350, 50, 100, 30)),
        const OcrTextLine(text: 'THU', boundingBox: Rect.fromLTWH(650, 50, 100, 30)),
      ];

      final candidates = detector.findDayCandidates(lines);
      expect(candidates.length, 5);
      expect(candidates[0].dayName, 'Monday');
      expect(candidates[1].dayName, 'Tuesday');
      expect(candidates[2].dayName, 'Wednesday');
      expect(candidates[3].dayName, 'Thursday');
      expect(candidates[4].dayName, 'Friday');
    });
  });

  group('3. TimetableGridDetector Tests', () {
    const gridDetector = TimetableGridDetector();

    test('Reconstructs 5 columns and 3 rows from OCR coordinates', () {
      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          // Day Headers at y=50
          const OcrTextLine(text: 'MON', boundingBox: Rect.fromLTWH(200, 50, 120, 30)),
          const OcrTextLine(text: 'TUE', boundingBox: Rect.fromLTWH(350, 50, 120, 30)),
          const OcrTextLine(text: 'WED', boundingBox: Rect.fromLTWH(500, 50, 120, 30)),
          const OcrTextLine(text: 'THU', boundingBox: Rect.fromLTWH(650, 50, 120, 30)),
          const OcrTextLine(text: 'FRI', boundingBox: Rect.fromLTWH(800, 50, 120, 30)),

          // Time Column at x=50
          const OcrTextLine(text: '08:30 - 09:20', boundingBox: Rect.fromLTWH(50, 120, 110, 30)),
          const OcrTextLine(text: '09:30 - 10:20', boundingBox: Rect.fromLTWH(50, 220, 110, 30)),
          const OcrTextLine(text: '11:00 - 12:40', boundingBox: Rect.fromLTWH(50, 320, 110, 30)),
        ],
        fullText: '',
        imageSize: const Size(1000, 600),
      );

      final grid = gridDetector.detectGrid(ocrResult);
      expect(grid.isValid, isTrue);
      expect(grid.columns.length, 5);
      expect(grid.rows.length, 3);

      // Verify coordinate matching
      final colMon = grid.findColumn(250);
      expect(colMon, isNotNull);
      expect(colMon!.dayName, 'Monday');

      final colFri = grid.findColumn(850);
      expect(colFri, isNotNull);
      expect(colFri!.dayName, 'Friday');

      final row1 = grid.findRow(130);
      expect(row1, isNotNull);
      expect(row1!.startTime, '08:30');

      final row2 = grid.findRow(230);
      expect(row2, isNotNull);
      expect(row2!.startTime, '09:30');
    });
  });

  group('4. DeterministicClassParser & GridCellAssigner Tests', () {
    const assigner = GridCellAssigner();
    const parser = DeterministicClassParser();

    test('Assigns lines to cells and extracts Subject, Teacher, Room correctly', () {
      const grid = TimetableGrid(
        columns: [
          GridColumn(dayName: 'Monday', left: 200, right: 350),
          GridColumn(dayName: 'Tuesday', left: 350, right: 500),
        ],
        rows: [
          GridRow(startTime: '08:30', endTime: '09:20', top: 100, bottom: 200),
          GridRow(startTime: '09:30', endTime: '10:20', top: 200, bottom: 300),
        ],
        tableBounds: Rect.fromLTRB(200, 100, 500, 300),
        headerBottomY: 80,
        timeColumnRightX: 180,
      );

      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          // Cell (Monday, 08:30): Mathematics, Dr. Smith, Room A-04
          const OcrTextLine(text: 'Mathematics', boundingBox: Rect.fromLTWH(210, 110, 100, 20)),
          const OcrTextLine(text: 'Dr. Smith', boundingBox: Rect.fromLTWH(210, 135, 80, 20)),
          const OcrTextLine(text: 'Room A-04', boundingBox: Rect.fromLTWH(210, 160, 70, 20)),

          // Cell (Monday, 09:30): Physics, Prof. Miller, Room B-12
          const OcrTextLine(text: 'Physics', boundingBox: Rect.fromLTWH(210, 210, 80, 20)),
          const OcrTextLine(text: 'Prof. Miller', boundingBox: Rect.fromLTWH(210, 235, 90, 20)),
          const OcrTextLine(text: 'Room B-12', boundingBox: Rect.fromLTWH(210, 260, 70, 20)),

          // Cell (Tuesday, 08:30): English, Mr. John, Room A-01
          const OcrTextLine(text: 'English', boundingBox: Rect.fromLTWH(360, 110, 70, 20)),
          const OcrTextLine(text: 'Mr. John', boundingBox: Rect.fromLTWH(360, 135, 60, 20)),
          const OcrTextLine(text: 'Room A-01', boundingBox: Rect.fromLTWH(360, 160, 70, 20)),

          // Cell (Tuesday, 09:30) is EMPTY!
        ],
        fullText: '',
        imageSize: const Size(600, 400),
      );

      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      expect(cells.length, 4); // 2 cols * 2 rows

      final classes = parser.parseCells(cells);
      // Empty Tuesday 09:30 cell must NOT create a fake class! Exactly 3 classes expected.
      expect(classes.length, 3);

      final math = classes.firstWhere((c) => c.subject == 'Mathematics');
      expect(math.dayOfWeek, 'Monday');
      expect(math.startTime, '08:30');
      expect(math.endTime, '09:20');
      expect(math.teacher, 'Dr. Smith');
      expect(math.room, 'Room A-04');
      expect(math.isAiUnsure, isFalse);

      final physics = classes.firstWhere((c) => c.subject == 'Physics');
      expect(physics.dayOfWeek, 'Monday');
      expect(physics.startTime, '09:30');
      expect(physics.endTime, '10:20');
      expect(physics.teacher, 'Prof. Miller');
      expect(physics.room, 'Room B-12');

      final english = classes.firstWhere((c) => c.subject == 'English');
      expect(english.dayOfWeek, 'Tuesday');
      expect(english.startTime, '08:30');
      expect(english.endTime, '09:20');
      expect(english.teacher, 'Mr. John');
      expect(english.room, 'Room A-01');
    });

    test('Merges multi-row classes spanning consecutive time slots into one class', () {
      const grid = TimetableGrid(
        columns: [
          GridColumn(dayName: 'Monday', left: 200, right: 350),
        ],
        rows: [
          GridRow(startTime: '11:00', endTime: '11:50', top: 100, bottom: 200),
          GridRow(startTime: '11:50', endTime: '12:40', top: 200, bottom: 300),
        ],
        tableBounds: Rect.fromLTRB(200, 100, 350, 300),
        headerBottomY: 80,
        timeColumnRightX: 180,
      );

      // Same class "Chemistry Lab" in both consecutive rows
      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          // Row 0
          const OcrTextLine(text: 'Chemistry Lab', boundingBox: Rect.fromLTWH(210, 110, 100, 20)),
          const OcrTextLine(text: 'Ms. Sara', boundingBox: Rect.fromLTWH(210, 140, 80, 20)),
          const OcrTextLine(text: 'Lab 2', boundingBox: Rect.fromLTWH(210, 170, 60, 20)),

          // Row 1 (Continuation of Chemistry Lab)
          const OcrTextLine(text: 'Chemistry Lab', boundingBox: Rect.fromLTWH(210, 210, 100, 20)),
        ],
        fullText: '',
        imageSize: const Size(400, 400),
      );

      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      final classes = parser.parseCells(cells);

      // Must be MERGED into exactly ONE class spanning 11:00 to 12:40!
      expect(classes.length, 1);
      final chemLab = classes.first;
      expect(chemLab.subject, 'Chemistry Lab');
      expect(chemLab.dayOfWeek, 'Monday');
      expect(chemLab.startTime, '11:00');
      expect(chemLab.endTime, '12:40');
      expect(chemLab.teacher, 'Ms. Sara');
      expect(chemLab.room, 'Lab 2');
    });

    test('Flags class as unsure (isAiUnsure: true) when room is missing', () {
      const grid = TimetableGrid(
        columns: [GridColumn(dayName: 'Wednesday', left: 200, right: 350)],
        rows: [GridRow(startTime: '10:00', endTime: '10:50', top: 100, bottom: 200)],
        tableBounds: Rect.fromLTRB(200, 100, 350, 200),
        headerBottomY: 80,
        timeColumnRightX: 180,
      );

      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          const OcrTextLine(text: 'Seminar', boundingBox: Rect.fromLTWH(210, 120, 80, 20)),
          const OcrTextLine(text: 'Dr. Watson', boundingBox: Rect.fromLTWH(210, 150, 80, 20)),
          // Room is intentionally missing!
        ],
        fullText: '',
        imageSize: const Size(400, 300),
      );

      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      final classes = parser.parseCells(cells);

      expect(classes.length, 1);
      expect(classes.first.subject, 'Seminar');
      expect(classes.first.room, isNull);
      expect(classes.first.isAiUnsure, isTrue); // Flagged for review!
    });
  });

  group('5. Complete Pipeline & SQLite Integration Test', () {
    test('End-to-End: OCR -> Grid -> Parser -> SQLite insertion & query', () async {
      final db = await AppDatabase.createInMemory();
      final repo = TimetableRepository(dbManager: db);

      // Simulate full university timetable OCR result
      final simulatedOcrResult = OcrResult(
        blocks: [],
        lines: [
          // Day Headers at y=50
          const OcrTextLine(text: 'MON', boundingBox: Rect.fromLTWH(200, 50, 120, 30)),
          const OcrTextLine(text: 'TUE', boundingBox: Rect.fromLTWH(350, 50, 120, 30)),
          const OcrTextLine(text: 'WED', boundingBox: Rect.fromLTWH(500, 50, 120, 30)),
          const OcrTextLine(text: 'THU', boundingBox: Rect.fromLTWH(650, 50, 120, 30)),
          const OcrTextLine(text: 'FRI', boundingBox: Rect.fromLTWH(800, 50, 120, 30)),

          // Time Column at x=50
          const OcrTextLine(text: '08:30 - 09:20', boundingBox: Rect.fromLTWH(50, 120, 110, 30)),
          const OcrTextLine(text: '09:30 - 10:20', boundingBox: Rect.fromLTWH(50, 220, 110, 30)),
          const OcrTextLine(text: '11:00 - 12:40', boundingBox: Rect.fromLTWH(50, 320, 110, 30)),

          // Classes
          // Mon 08:30: Mathematics (Room A-04, Dr. Smith)
          const OcrTextLine(text: 'Mathematics', boundingBox: Rect.fromLTWH(210, 110, 100, 20)),
          const OcrTextLine(text: 'Dr. Smith', boundingBox: Rect.fromLTWH(210, 135, 80, 20)),
          const OcrTextLine(text: 'Room A-04', boundingBox: Rect.fromLTWH(210, 160, 70, 20)),

          // Mon 09:30: Physics (Room B-12, Prof. Miller)
          const OcrTextLine(text: 'Physics', boundingBox: Rect.fromLTWH(210, 210, 80, 20)),
          const OcrTextLine(text: 'Prof. Miller', boundingBox: Rect.fromLTWH(210, 235, 90, 20)),
          const OcrTextLine(text: 'Room B-12', boundingBox: Rect.fromLTWH(210, 260, 70, 20)),

          // Thu 09:30: Physics (Room B-12, Prof. Miller)
          const OcrTextLine(text: 'Physics', boundingBox: Rect.fromLTWH(660, 210, 80, 20)),
          const OcrTextLine(text: 'Prof. Miller', boundingBox: Rect.fromLTWH(660, 235, 90, 20)),
          const OcrTextLine(text: 'Room B-12', boundingBox: Rect.fromLTWH(660, 260, 70, 20)),

          // Fri 08:30: Computer Science (Room C-07, Ms. Sara Ahmed Khan)
          const OcrTextLine(text: 'Computer Science', boundingBox: Rect.fromLTWH(810, 110, 110, 20)),
          const OcrTextLine(text: 'Ms. Sara Ahmed Khan', boundingBox: Rect.fromLTWH(810, 135, 110, 20)),
          const OcrTextLine(text: 'Room C-07', boundingBox: Rect.fromLTWH(810, 160, 70, 20)),
        ],
        fullText: '',
        imageSize: const Size(1000, 600),
      );

      final service = TimetableScannerService(
        ocrEngine: MockOcrEngine.fromResult(simulatedOcrResult),
      );

      // Run local on-device scan
      final parsedClasses = await service.scanTimetable('test_mock.jpg');
      expect(parsedClasses.length, 4);

      // Persist into SQLite database
      await repo.replaceAllClasses(parsedClasses);

      // Query database
      final storedClasses = await repo.getAllClasses();
      expect(storedClasses.length, 4);

      final mondayClasses = await repo.getClassesForDay('Monday');
      expect(mondayClasses.length, 2);
      expect(mondayClasses[0].subject, 'Mathematics');
      expect(mondayClasses[0].startTime, '08:30');
      expect(mondayClasses[1].subject, 'Physics');
      expect(mondayClasses[1].startTime, '09:30');

      final fridayClasses = await repo.getClassesForDay('Friday');
      expect(fridayClasses.length, 1);
      expect(fridayClasses.first.subject, 'Computer Science');
      expect(fridayClasses.first.room, 'Room C-07');
      expect(fridayClasses.first.teacher, 'Ms. Sara Ahmed Khan');

      repo.dispose();
    });
  });

  group('6. Edge Cases, Noise Resilience & Format Variations', () {
    const assigner = GridCellAssigner();
    const parser = DeterministicClassParser();

    test('Filters out OCR noise lines (separators, pipes, dashes)', () {
      const grid = TimetableGrid(
        columns: [GridColumn(dayName: 'Monday', left: 100, right: 300)],
        rows: [GridRow(startTime: '09:00', endTime: '10:00', top: 50, bottom: 150)],
        tableBounds: Rect.fromLTRB(100, 50, 300, 150),
        headerBottomY: 40,
        timeColumnRightX: 90,
      );

      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          const OcrTextLine(text: '|------------------|', boundingBox: Rect.fromLTWH(110, 55, 100, 10)),
          const OcrTextLine(text: 'Linear Algebra', boundingBox: Rect.fromLTWH(110, 70, 90, 20)),
          const OcrTextLine(text: '....................', boundingBox: Rect.fromLTWH(110, 95, 100, 10)),
          const OcrTextLine(text: 'Engr. Fatima', boundingBox: Rect.fromLTWH(110, 110, 80, 20)),
          const OcrTextLine(text: 'Hall-3', boundingBox: Rect.fromLTWH(110, 130, 50, 15)),
        ],
        fullText: '',
        imageSize: const Size(400, 200),
      );

      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      final classes = parser.parseCells(cells);

      expect(classes.length, 1);
      final cls = classes.first;
      expect(cls.subject, 'Linear Algebra');
      expect(cls.teacher, 'Engr. Fatima');
      expect(cls.room, 'Hall-3');
    });

    test('Cell-internal time range overrides row boundary times', () {
      const grid = TimetableGrid(
        columns: [GridColumn(dayName: 'Wednesday', left: 100, right: 300)],
        rows: [GridRow(startTime: '08:00', endTime: '09:00', top: 50, bottom: 150)],
        tableBounds: Rect.fromLTRB(100, 50, 300, 150),
        headerBottomY: 40,
        timeColumnRightX: 90,
      );

      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          const OcrTextLine(text: 'Data Structures', boundingBox: Rect.fromLTWH(110, 60, 90, 20)),
          const OcrTextLine(text: '08:15 - 09:45', boundingBox: Rect.fromLTWH(110, 85, 80, 20)),
          const OcrTextLine(text: 'Lab 4', boundingBox: Rect.fromLTWH(110, 110, 50, 20)),
        ],
        fullText: '',
        imageSize: const Size(400, 200),
      );

      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      final classes = parser.parseCells(cells);

      expect(classes.length, 1);
      final cls = classes.first;
      expect(cls.subject, 'Data Structures');
      // Must take the cell's explicit internal time!
      expect(cls.startTime, '08:15');
      expect(cls.endTime, '09:45');
      expect(cls.room, 'Lab 4');
    });

    test('Recognizes labeled teacher and room lines (Teacher: ..., Room: ...)', () {
      const grid = TimetableGrid(
        columns: [GridColumn(dayName: 'Thursday', left: 100, right: 300)],
        rows: [GridRow(startTime: '10:00', endTime: '11:00', top: 50, bottom: 150)],
        tableBounds: Rect.fromLTRB(100, 50, 300, 150),
        headerBottomY: 40,
        timeColumnRightX: 90,
      );

      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          const OcrTextLine(text: 'Software Engineering', boundingBox: Rect.fromLTWH(110, 60, 120, 20)),
          const OcrTextLine(text: 'Instructor: John Doe', boundingBox: Rect.fromLTWH(110, 85, 110, 20)),
          const OcrTextLine(text: 'Room: LT-1', boundingBox: Rect.fromLTWH(110, 110, 70, 20)),
        ],
        fullText: '',
        imageSize: const Size(400, 200),
      );

      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      final classes = parser.parseCells(cells);

      expect(classes.length, 1);
      final cls = classes.first;
      expect(cls.subject, 'Software Engineering');
      expect(cls.teacher, 'John Doe');
      expect(cls.room, 'Room: LT-1');
    });
  });
}
