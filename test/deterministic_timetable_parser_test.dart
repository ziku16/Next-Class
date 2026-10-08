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

  group('7. University Grid (Rows=Days, Columns=Lectures) & Dual Lab Tests', () {
    const gridDetector = TimetableGridDetector();
    const assigner = GridCellAssigner();
    const parser = DeterministicClassParser();

    test('Detects 5 Day Rows and 5 Lecture Columns from University Timetable', () {
      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          // Day Labels on the left (x = 50)
          const OcrTextLine(text: 'Monday', boundingBox: Rect.fromLTWH(30, 100, 80, 25)),
          const OcrTextLine(text: 'Tuesday', boundingBox: Rect.fromLTWH(30, 180, 80, 25)),
          const OcrTextLine(text: 'Wednesday', boundingBox: Rect.fromLTWH(30, 260, 90, 25)),
          const OcrTextLine(text: 'Thursday', boundingBox: Rect.fromLTWH(30, 340, 85, 25)),
          const OcrTextLine(text: 'Friday', boundingBox: Rect.fromLTWH(30, 420, 80, 25)),

          // Lecture Headers across top (y = 40)
          const OcrTextLine(text: 'Lecture 1', boundingBox: Rect.fromLTWH(150, 30, 90, 20)),
          const OcrTextLine(text: '8:30 - 10:00', boundingBox: Rect.fromLTWH(150, 55, 90, 20)),

          const OcrTextLine(text: 'Lecture 2', boundingBox: Rect.fromLTWH(300, 30, 90, 20)),
          const OcrTextLine(text: '10:00 - 11:30', boundingBox: Rect.fromLTWH(300, 55, 95, 20)),

          const OcrTextLine(text: 'Lecture 3', boundingBox: Rect.fromLTWH(460, 30, 90, 20)),
          const OcrTextLine(text: '11:30 - 13:15', boundingBox: Rect.fromLTWH(460, 55, 95, 20)),

          const OcrTextLine(text: 'Lecture 4', boundingBox: Rect.fromLTWH(620, 30, 90, 20)),
          const OcrTextLine(text: '13:35 - 15:00', boundingBox: Rect.fromLTWH(620, 55, 95, 20)),

          const OcrTextLine(text: 'Lecture 5', boundingBox: Rect.fromLTWH(780, 30, 90, 20)),
          const OcrTextLine(text: '15:00 - 16:30', boundingBox: Rect.fromLTWH(780, 55, 95, 20)),
        ],
        fullText: '',
        imageSize: const Size(1000, 550),
      );

      final grid = gridDetector.detectGrid(ocrResult);
      expect(grid.isValid, isTrue);
      expect(grid.isDaysAsRows, isTrue);
      expect(grid.rows.length, 5);
      expect(grid.columns.length, 5);

      // Verify Rows are Days
      expect(grid.rows[0].dayName, 'Monday');
      expect(grid.rows[1].dayName, 'Tuesday');
      expect(grid.rows[2].dayName, 'Wednesday');
      expect(grid.rows[3].dayName, 'Thursday');
      expect(grid.rows[4].dayName, 'Friday');

      // Verify Columns are Lectures with known times
      expect(grid.columns[0].label, 'Lecture 1');
      expect(grid.columns[0].startTime, '08:30');
      expect(grid.columns[0].endTime, '10:00');

      expect(grid.columns[1].label, 'Lecture 2');
      expect(grid.columns[1].startTime, '10:00');
      expect(grid.columns[1].endTime, '11:30');

      expect(grid.columns[2].label, 'Lecture 3');
      expect(grid.columns[2].startTime, '11:30');
      expect(grid.columns[2].endTime, '13:15');

      expect(grid.columns[3].label, 'Lecture 4');
      expect(grid.columns[3].startTime, '13:35');
      expect(grid.columns[3].endTime, '15:00');

      expect(grid.columns[4].label, 'Lecture 5');
      expect(grid.columns[4].startTime, '15:00');
      expect(grid.columns[4].endTime, '16:30');
    });

    test('Assigns classes by OCR coordinates, completely independent of OCR return order', () {
      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          // Day Labels on left
          const OcrTextLine(text: 'Monday', boundingBox: Rect.fromLTWH(30, 100, 80, 25)),
          const OcrTextLine(text: 'Tuesday', boundingBox: Rect.fromLTWH(30, 200, 80, 25)),
          const OcrTextLine(text: 'Wednesday', boundingBox: Rect.fromLTWH(30, 300, 90, 25)),
          const OcrTextLine(text: 'Thursday', boundingBox: Rect.fromLTWH(30, 400, 85, 25)),
          const OcrTextLine(text: 'Friday', boundingBox: Rect.fromLTWH(30, 500, 80, 25)),

          // Header
          const OcrTextLine(text: 'Lecture 1', boundingBox: Rect.fromLTWH(150, 30, 90, 20)),
          const OcrTextLine(text: 'Lecture 2', boundingBox: Rect.fromLTWH(320, 30, 90, 20)),
          const OcrTextLine(text: 'Lecture 3', boundingBox: Rect.fromLTWH(490, 30, 90, 20)),
          const OcrTextLine(text: 'Lecture 4', boundingBox: Rect.fromLTWH(660, 30, 90, 20)),
          const OcrTextLine(text: 'Lecture 5', boundingBox: Rect.fromLTWH(830, 30, 90, 20)),

          // --- Classes in SCRAMBLED order ---
          // 1. Friday Lecture 5 (x=850, y=510)
          const OcrTextLine(text: 'Compiler Construction', boundingBox: Rect.fromLTWH(840, 505, 120, 18)),
          const OcrTextLine(text: 'Dr. Tariq', boundingBox: Rect.fromLTWH(840, 525, 80, 18)),
          const OcrTextLine(text: 'Room CS-3', boundingBox: Rect.fromLTWH(840, 545, 75, 18)),

          // 2. Monday Lecture 1 (x=160, y=110)
          const OcrTextLine(text: 'Database Systems', boundingBox: Rect.fromLTWH(160, 105, 110, 18)),
          const OcrTextLine(text: 'Ms. Mehreen Wahab', boundingBox: Rect.fromLTWH(160, 125, 115, 18)),
          const OcrTextLine(text: 'LT 2', boundingBox: Rect.fromLTWH(160, 145, 50, 18)),

          // 3. Wednesday Lecture 3 (x=500, y=310)
          const OcrTextLine(text: 'Artificial Intelligence', boundingBox: Rect.fromLTWH(500, 305, 125, 18)),
          const OcrTextLine(text: 'Dr. Sarah', boundingBox: Rect.fromLTWH(500, 325, 70, 18)),
          const OcrTextLine(text: 'Hall-B', boundingBox: Rect.fromLTWH(500, 345, 60, 18)),
        ],
        fullText: '',
        imageSize: const Size(1000, 600),
      );

      final grid = gridDetector.detectGrid(ocrResult);
      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      final classes = parser.parseCells(cells);

      // Verify that header row did NOT generate fake classes
      expect(classes.any((c) => c.subject.contains('Lecture')), isFalse);

      // Exactly 3 classes detected
      expect(classes.length, 3);

      // Monday Lecture 1 (08:30 - 10:00)
      final dbs = classes.firstWhere((c) => c.subject == 'Database Systems');
      expect(dbs.dayOfWeek, 'Monday');
      expect(dbs.startTime, '08:30');
      expect(dbs.endTime, '10:00');
      expect(dbs.teacher, 'Ms. Mehreen Wahab');
      expect(dbs.room, 'LT 2');

      // Wednesday Lecture 3 (11:30 - 13:15)
      final ai = classes.firstWhere((c) => c.subject == 'Artificial Intelligence');
      expect(ai.dayOfWeek, 'Wednesday');
      expect(ai.startTime, '11:30');
      expect(ai.endTime, '13:15');
      expect(ai.teacher, 'Dr. Sarah');
      expect(ai.room, 'Hall-B');

      // Friday Lecture 5 (15:00 - 16:30)
      final cc = classes.firstWhere((c) => c.subject == 'Compiler Construction');
      expect(cc.dayOfWeek, 'Friday');
      expect(cc.startTime, '15:00');
      expect(cc.endTime, '16:30');
      expect(cc.teacher, 'Dr. Tariq');
      expect(cc.room, 'Room CS-3');
    });

    test('Splits dual lab entries stacked within a single lecture period into two separate classes', () {
      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          // Day labels (5 days spaced across vertical table)
          const OcrTextLine(text: 'Monday', boundingBox: Rect.fromLTWH(30, 100, 80, 25)),
          const OcrTextLine(text: 'Tuesday', boundingBox: Rect.fromLTWH(30, 280, 80, 25)),
          const OcrTextLine(text: 'Wednesday', boundingBox: Rect.fromLTWH(30, 460, 90, 25)),
          const OcrTextLine(text: 'Thursday', boundingBox: Rect.fromLTWH(30, 640, 85, 25)),
          const OcrTextLine(text: 'Friday', boundingBox: Rect.fromLTWH(30, 820, 80, 25)),

          // 5 Lecture headers across top
          const OcrTextLine(text: 'Lecture 1', boundingBox: Rect.fromLTWH(150, 30, 90, 20)),
          const OcrTextLine(text: 'Lecture 2', boundingBox: Rect.fromLTWH(320, 30, 90, 20)),
          const OcrTextLine(text: 'Lecture 3', boundingBox: Rect.fromLTWH(490, 30, 90, 20)),
          const OcrTextLine(text: 'Lecture 4', boundingBox: Rect.fromLTWH(660, 30, 90, 20)),
          const OcrTextLine(text: 'Lecture 5', boundingBox: Rect.fromLTWH(830, 30, 90, 20)),

          // Cell (Monday, Lecture 2: 10:00 - 11:30 at x=320) contains two stacked lab classes:
          // Sub-block 1: DBS(Lab)
          const OcrTextLine(text: 'DBS(Lab)', boundingBox: Rect.fromLTWH(320, 105, 80, 16)),
          const OcrTextLine(text: 'Ms. Mehreen Wahab', boundingBox: Rect.fromLTWH(320, 123, 110, 16)),
          const OcrTextLine(text: 'Lab Group 1', boundingBox: Rect.fromLTWH(320, 141, 80, 16)),
          const OcrTextLine(text: 'CS C.Lab 7', boundingBox: Rect.fromLTWH(320, 159, 75, 16)),

          // Sub-block 2: DS(Lab)
          const OcrTextLine(text: 'DS(Lab)', boundingBox: Rect.fromLTWH(320, 185, 70, 16)),
          const OcrTextLine(text: 'Mr. Bilal Bukhari', boundingBox: Rect.fromLTWH(320, 203, 105, 16)),
          const OcrTextLine(text: 'Lab Group 2', boundingBox: Rect.fromLTWH(320, 221, 80, 16)),
          const OcrTextLine(text: 'EE C.Lab (U)', boundingBox: Rect.fromLTWH(320, 239, 85, 16)),
        ],
        fullText: '',
        imageSize: const Size(1000, 1000),
      );

      final grid = gridDetector.detectGrid(ocrResult);
      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      final classes = parser.parseCells(cells);

      // Must be split into exactly 2 classes!
      expect(classes.length, 2);

      final dbsLab = classes.firstWhere((c) => c.subject.contains('DBS'));
      expect(dbsLab.dayOfWeek, 'Monday');
      expect(dbsLab.startTime, '10:00');
      expect(dbsLab.endTime, '11:30');
      expect(dbsLab.teacher, 'Ms. Mehreen Wahab');
      expect(dbsLab.room, contains('CS C.Lab 7'));
      expect(dbsLab.room, contains('Lab Group 1'));

      final dsLab = classes.firstWhere((c) => c.subject.contains('DS') && !c.subject.contains('DBS'));
      expect(dsLab.dayOfWeek, 'Monday');
      expect(dsLab.startTime, '10:00');
      expect(dsLab.endTime, '11:30');
      expect(dsLab.teacher, 'Mr. Bilal Bukhari');
      expect(dsLab.room, contains('EE C.Lab (U)'));
      expect(dsLab.room, contains('Lab Group 2'));
    });

    test('Empty cells in the 5x5 grid produce zero classes', () {
      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          const OcrTextLine(text: 'Monday', boundingBox: Rect.fromLTWH(30, 100, 80, 25)),
          const OcrTextLine(text: 'Lecture 1', boundingBox: Rect.fromLTWH(150, 30, 90, 20)),
          const OcrTextLine(text: 'Lecture 2', boundingBox: Rect.fromLTWH(320, 30, 90, 20)),

          // Only Monday Lecture 1 has content
          const OcrTextLine(text: 'Computer Networks', boundingBox: Rect.fromLTWH(160, 110, 110, 20)),
          const OcrTextLine(text: 'Engr. Ali', boundingBox: Rect.fromLTWH(160, 135, 70, 20)),
          const OcrTextLine(text: 'Lab 1', boundingBox: Rect.fromLTWH(160, 160, 50, 20)),

          // Lecture 2 on Monday is COMPLETELY EMPTY!
        ],
        fullText: '',
        imageSize: const Size(600, 300),
      );

      final grid = gridDetector.detectGrid(ocrResult);
      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      final classes = parser.parseCells(cells);

      expect(classes.length, 1);
      expect(classes.first.subject, 'Computer Networks');
    });
  });

  group('8. Regression Suite: Strict Grid as Source of Truth & Zero False Classes', () {
    const gridDetector = TimetableGridDetector();
    const assigner = GridCellAssigner();
    const parser = DeterministicClassParser();

    test('Strict 25 cells created and all external header, footer, day, margin text discarded', () {
      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          // 1. External Title at very top
          const OcrTextLine(text: 'University Weekly Schedule', boundingBox: Rect.fromLTWH(300, 10, 300, 25)),

          // 2. Day Labels in Leftmost Column (Mon .. Fri)
          const OcrTextLine(text: 'Mon', boundingBox: Rect.fromLTWH(20, 120, 50, 20)),
          const OcrTextLine(text: 'Tue', boundingBox: Rect.fromLTWH(20, 220, 50, 20)),
          const OcrTextLine(text: 'Wed', boundingBox: Rect.fromLTWH(20, 320, 50, 20)),
          const OcrTextLine(text: 'Thu', boundingBox: Rect.fromLTWH(20, 420, 50, 20)),
          const OcrTextLine(text: 'Fri', boundingBox: Rect.fromLTWH(20, 520, 50, 20)),

          // 3. Top Header Row (Lecture 1 .. 5 and times)
          const OcrTextLine(text: 'Lecture 1', boundingBox: Rect.fromLTWH(140, 40, 80, 18)),
          const OcrTextLine(text: '8:30 - 10:00', boundingBox: Rect.fromLTWH(140, 62, 90, 18)),
          const OcrTextLine(text: 'Lecture 2', boundingBox: Rect.fromLTWH(310, 40, 80, 18)),
          const OcrTextLine(text: '10:00 - 11:30', boundingBox: Rect.fromLTWH(310, 62, 90, 18)),
          const OcrTextLine(text: 'Lecture 3', boundingBox: Rect.fromLTWH(480, 40, 80, 18)),
          const OcrTextLine(text: '11:30 - 13:15', boundingBox: Rect.fromLTWH(480, 62, 90, 18)),
          const OcrTextLine(text: 'Lecture 4', boundingBox: Rect.fromLTWH(650, 40, 80, 18)),
          const OcrTextLine(text: '13:35 - 15:00', boundingBox: Rect.fromLTWH(650, 62, 90, 18)),
          const OcrTextLine(text: 'Lecture 5', boundingBox: Rect.fromLTWH(820, 40, 80, 18)),
          const OcrTextLine(text: '15:00 - 16:30', boundingBox: Rect.fromLTWH(820, 62, 90, 18)),

          // 4. Valid Classes inside cells
          // Monday Lecture 2 (x=310, y=120)
          const OcrTextLine(text: 'Database Systems', boundingBox: Rect.fromLTWH(310, 115, 120, 18)),
          const OcrTextLine(text: 'Ms. Mehreen Wahab', boundingBox: Rect.fromLTWH(310, 137, 130, 18)),
          const OcrTextLine(text: 'LT 2', boundingBox: Rect.fromLTWH(310, 159, 45, 18)),

          // Wednesday Lecture 4 (x=650, y=320)
          const OcrTextLine(text: 'Calculus and Analytic Geometry', boundingBox: Rect.fromLTWH(650, 315, 150, 18)),
          const OcrTextLine(text: 'CR 2', boundingBox: Rect.fromLTWH(650, 337, 45, 18)),

          // 5. External Footer Text below timetable boundary (y=620)
          const OcrTextLine(text: 'Timetable generated: 10/1/2026', boundingBox: Rect.fromLTWH(40, 620, 200, 20)),
          const OcrTextLine(text: 'aSc Timetables', boundingBox: Rect.fromLTWH(800, 620, 120, 20)),
        ],
        fullText: '',
        imageSize: const Size(1000, 660),
      );

      final grid = gridDetector.detectGrid(ocrResult);
      expect(grid.isValid, isTrue);
      expect(grid.isDaysAsRows, isTrue);
      expect(grid.rows.length, 5);
      expect(grid.columns.length, 5);

      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      // Exactly 25 logical cells (5 days × 5 lectures)
      expect(cells.length, 25);

      final classes = parser.parseCells(cells);
      // Exactly 2 valid classes detected
      expect(classes.length, 2);

      // Verify no header classes
      expect(classes.any((c) => c.subject.contains('Lecture')), isFalse);
      expect(classes.any((c) => c.subject.contains('8:30')), isFalse);

      // Verify no footer classes
      expect(classes.any((c) => c.subject.contains('Timetable generated')), isFalse);
      expect(classes.any((c) => c.subject.contains('aSc Timetables')), isFalse);

      // Verify no day-label classes
      expect(classes.any((c) => c.subject == 'Mon' || c.subject == 'Monday'), isFalse);

      // Verify exact valid classes
      final dbs = classes.firstWhere((c) => c.subject == 'Database Systems');
      expect(dbs.dayOfWeek, 'Monday');
      expect(dbs.startTime, '10:00');
      expect(dbs.endTime, '11:30');
      expect(dbs.teacher, 'Ms. Mehreen Wahab');
      expect(dbs.room, 'LT 2');

      final calc = classes.firstWhere((c) => c.subject.contains('Calculus'));
      expect(calc.dayOfWeek, 'Wednesday');
      expect(calc.startTime, '13:35');
      expect(calc.endTime, '15:00');
      expect(calc.room, 'CR 2');
      expect(calc.teacher, isNull); // No hallucination!
    });

    test('Metadata-only cells (room only, lab group only, teacher only) produce ZERO classes', () {
      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          // Days
          const OcrTextLine(text: 'Mon', boundingBox: Rect.fromLTWH(20, 100, 50, 20)),
          const OcrTextLine(text: 'Tue', boundingBox: Rect.fromLTWH(20, 200, 50, 20)),
          const OcrTextLine(text: 'Wed', boundingBox: Rect.fromLTWH(20, 300, 50, 20)),
          const OcrTextLine(text: 'Thu', boundingBox: Rect.fromLTWH(20, 400, 50, 20)),
          const OcrTextLine(text: 'Fri', boundingBox: Rect.fromLTWH(20, 500, 50, 20)),

          // Headers
          const OcrTextLine(text: 'Lecture 1', boundingBox: Rect.fromLTWH(140, 40, 80, 18)),
          const OcrTextLine(text: 'Lecture 2', boundingBox: Rect.fromLTWH(310, 40, 80, 18)),
          const OcrTextLine(text: 'Lecture 3', boundingBox: Rect.fromLTWH(480, 40, 80, 18)),
          const OcrTextLine(text: 'Lecture 4', boundingBox: Rect.fromLTWH(650, 40, 80, 18)),
          const OcrTextLine(text: 'Lecture 5', boundingBox: Rect.fromLTWH(820, 40, 80, 18)),

          // Cell (Monday, Lecture 1): Room ONLY
          const OcrTextLine(text: 'LT 2', boundingBox: Rect.fromLTWH(140, 110, 45, 18)),

          // Cell (Tuesday, Lecture 2): Lab Group ONLY
          const OcrTextLine(text: 'Lab Group 1', boundingBox: Rect.fromLTWH(310, 210, 90, 18)),

          // Cell (Wednesday, Lecture 3): Teacher ONLY
          const OcrTextLine(text: 'Mr. Bilal Bukhari', boundingBox: Rect.fromLTWH(480, 310, 120, 18)),

          // Cell (Thursday, Lecture 4): Teacher + Room (NO Subject)
          const OcrTextLine(text: 'Ms. Mehreen Wahab', boundingBox: Rect.fromLTWH(650, 410, 130, 18)),
          const OcrTextLine(text: 'CS C.Lab 7', boundingBox: Rect.fromLTWH(650, 435, 90, 18)),

          // Cell (Friday, Lecture 5): OCR Noise ONLY
          const OcrTextLine(text: '----------------', boundingBox: Rect.fromLTWH(820, 510, 100, 18)),
          const OcrTextLine(text: '.........', boundingBox: Rect.fromLTWH(820, 530, 60, 18)),
        ],
        fullText: '',
        imageSize: const Size(1000, 600),
      );

      final grid = gridDetector.detectGrid(ocrResult);
      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      final classes = parser.parseCells(cells);

      // Absolutely ZERO classes should be created from metadata-only cells!
      expect(classes, isEmpty);
    });

    test('Never combines adjacent lecture periods (Lecture 2 + Lecture 3 are isolated)', () {
      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          // Days
          const OcrTextLine(text: 'Mon', boundingBox: Rect.fromLTWH(20, 100, 50, 20)),
          const OcrTextLine(text: 'Tue', boundingBox: Rect.fromLTWH(20, 200, 50, 20)),
          const OcrTextLine(text: 'Wed', boundingBox: Rect.fromLTWH(20, 300, 50, 20)),
          const OcrTextLine(text: 'Thu', boundingBox: Rect.fromLTWH(20, 400, 50, 20)),
          const OcrTextLine(text: 'Fri', boundingBox: Rect.fromLTWH(20, 500, 50, 20)),

          // Headers
          const OcrTextLine(text: 'Lecture 1', boundingBox: Rect.fromLTWH(140, 40, 80, 18)),
          const OcrTextLine(text: 'Lecture 2', boundingBox: Rect.fromLTWH(310, 40, 80, 18)),
          const OcrTextLine(text: 'Lecture 3', boundingBox: Rect.fromLTWH(480, 40, 80, 18)),
          const OcrTextLine(text: 'Lecture 4', boundingBox: Rect.fromLTWH(650, 40, 80, 18)),
          const OcrTextLine(text: 'Lecture 5', boundingBox: Rect.fromLTWH(820, 40, 80, 18)),

          // Monday Lecture 2 (10:00 - 11:30)
          const OcrTextLine(text: 'Database Systems', boundingBox: Rect.fromLTWH(310, 110, 120, 18)),
          const OcrTextLine(text: 'Ms. Mehreen Wahab', boundingBox: Rect.fromLTWH(310, 130, 130, 18)),
          const OcrTextLine(text: 'LT 2', boundingBox: Rect.fromLTWH(310, 150, 45, 18)),

          // Monday Lecture 3 (11:30 - 13:15)
          const OcrTextLine(text: 'Data Structures', boundingBox: Rect.fromLTWH(480, 110, 110, 18)),
          const OcrTextLine(text: 'Mr. Bilal Bukhari', boundingBox: Rect.fromLTWH(480, 130, 120, 18)),
          const OcrTextLine(text: 'LT 4', boundingBox: Rect.fromLTWH(480, 150, 45, 18)),
        ],
        fullText: '',
        imageSize: const Size(1000, 600),
      );

      final grid = gridDetector.detectGrid(ocrResult);
      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      final classes = parser.parseCells(cells);

      expect(classes.length, 2);

      // Class 1: Monday Lecture 2
      final dbs = classes.firstWhere((c) => c.subject == 'Database Systems');
      expect(dbs.startTime, '10:00');
      expect(dbs.endTime, '11:30');
      expect(dbs.teacher, 'Ms. Mehreen Wahab');
      expect(dbs.room, 'LT 2');

      // Class 2: Monday Lecture 3
      final ds = classes.firstWhere((c) => c.subject == 'Data Structures');
      expect(ds.startTime, '11:30');
      expect(ds.endTime, '13:15');
      expect(ds.teacher, 'Mr. Bilal Bukhari');
      expect(ds.room, 'LT 4');
    });

    test('Full university regression: handles dual stacked labs and excludes all non-class metadata', () {
      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          // Days column
          const OcrTextLine(text: 'Mon', boundingBox: Rect.fromLTWH(20, 100, 45, 20)),
          const OcrTextLine(text: 'Tue', boundingBox: Rect.fromLTWH(20, 200, 45, 20)),
          const OcrTextLine(text: 'Wed', boundingBox: Rect.fromLTWH(20, 300, 45, 20)),
          const OcrTextLine(text: 'Thu', boundingBox: Rect.fromLTWH(20, 400, 45, 20)),
          const OcrTextLine(text: 'Fri', boundingBox: Rect.fromLTWH(20, 500, 45, 20)),

          // 5 Lecture headers
          const OcrTextLine(text: 'Lecture 1', boundingBox: Rect.fromLTWH(140, 40, 80, 18)),
          const OcrTextLine(text: '8:30 - 10:00', boundingBox: Rect.fromLTWH(140, 62, 90, 18)),
          const OcrTextLine(text: 'Lecture 2', boundingBox: Rect.fromLTWH(310, 40, 80, 18)),
          const OcrTextLine(text: '10:00 - 11:30', boundingBox: Rect.fromLTWH(310, 62, 90, 18)),
          const OcrTextLine(text: 'Lecture 3', boundingBox: Rect.fromLTWH(480, 40, 80, 18)),
          const OcrTextLine(text: '11:30 - 13:15', boundingBox: Rect.fromLTWH(480, 62, 90, 18)),
          const OcrTextLine(text: 'Lecture 4', boundingBox: Rect.fromLTWH(650, 40, 80, 18)),
          const OcrTextLine(text: '13:35 - 15:00', boundingBox: Rect.fromLTWH(650, 62, 90, 18)),
          const OcrTextLine(text: 'Lecture 5', boundingBox: Rect.fromLTWH(820, 40, 80, 18)),
          const OcrTextLine(text: '15:00 - 16:30', boundingBox: Rect.fromLTWH(820, 62, 90, 18)),

          // 1. Tuesday Lecture 1: Fundamentals of Digital Logic Design in LT 1
          const OcrTextLine(text: 'Fundamentals of Digital Logic Design', boundingBox: Rect.fromLTWH(140, 205, 140, 16)),
          const OcrTextLine(text: 'LT 1', boundingBox: Rect.fromLTWH(140, 225, 40, 16)),

          // 2. Wednesday Lecture 2: Dual stacked lab classes:
          // Sub-block 1: DBS(Lab)
          const OcrTextLine(text: 'DBS(Lab)', boundingBox: Rect.fromLTWH(310, 305, 80, 8)),
          const OcrTextLine(text: 'Ms. Mehreen Wahab', boundingBox: Rect.fromLTWH(310, 314, 110, 8)),
          const OcrTextLine(text: 'Lab Group 1', boundingBox: Rect.fromLTWH(310, 323, 80, 8)),
          const OcrTextLine(text: 'CS C.Lab 7', boundingBox: Rect.fromLTWH(310, 332, 75, 8)),
          // Sub-block 2: DS(Lab)
          const OcrTextLine(text: 'DS(Lab)', boundingBox: Rect.fromLTWH(310, 342, 70, 8)),
          const OcrTextLine(text: 'Mr. Bilal Bukhari', boundingBox: Rect.fromLTWH(310, 351, 105, 8)),
          const OcrTextLine(text: 'Lab Group 2', boundingBox: Rect.fromLTWH(310, 360, 80, 8)),
          const OcrTextLine(text: 'EE C.Lab (U)', boundingBox: Rect.fromLTWH(310, 369, 85, 8)),

          // 3. Thursday Lecture 4: Software Engineering in CR 2
          const OcrTextLine(text: 'Software Engineering', boundingBox: Rect.fromLTWH(650, 405, 120, 16)),
          const OcrTextLine(text: 'CR 2', boundingBox: Rect.fromLTWH(650, 425, 45, 16)),

          // Footer noise
          const OcrTextLine(text: 'Timetable generated: 10/1/2026', boundingBox: Rect.fromLTWH(30, 580, 180, 18)),
          const OcrTextLine(text: 'aSc Timetables', boundingBox: Rect.fromLTWH(820, 580, 110, 18)),
        ],
        fullText: '',
        imageSize: const Size(1000, 620),
      );

      final grid = gridDetector.detectGrid(ocrResult);
      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      final classes = parser.parseCells(cells);

      // Exactly 4 classes: DLD, DBS(Lab), DS(Lab), Software Engineering
      expect(classes.length, 4);

      // Verify no false classes
      for (final c in classes) {
        expect(c.subject.contains('Lecture'), isFalse);
        expect(c.subject.contains('Timetable'), isFalse);
        expect(c.subject.contains('aSc'), isFalse);
        expect(c.subject.contains('Mon'), isFalse);
        expect(c.subject.contains('Tue'), isFalse);
        expect(c.subject.contains('LT 1'), isFalse);
        expect(c.subject.contains('Lab Group'), isFalse);
      }

      // Check DLD
      final dld = classes.firstWhere((c) => c.subject.contains('Logic Design'));
      expect(dld.dayOfWeek, 'Tuesday');
      expect(dld.startTime, '08:30');
      expect(dld.endTime, '10:00');
      expect(dld.room, 'LT 1');

      // Check DBS(Lab)
      final dbsLab = classes.firstWhere((c) => c.subject.contains('DBS'));
      expect(dbsLab.dayOfWeek, 'Wednesday');
      expect(dbsLab.startTime, '10:00');
      expect(dbsLab.endTime, '11:30');
      expect(dbsLab.teacher, 'Ms. Mehreen Wahab');
      expect(dbsLab.room, contains('CS C.Lab 7'));
      expect(dbsLab.room, contains('Lab Group 1'));

      // Check DS(Lab)
      final dsLab = classes.firstWhere((c) => c.subject.contains('DS') && !c.subject.contains('DBS'));
      expect(dsLab.dayOfWeek, 'Wednesday');
      expect(dsLab.startTime, '10:00');
      expect(dsLab.endTime, '11:30');
      expect(dsLab.teacher, 'Mr. Bilal Bukhari');
      expect(dsLab.room, contains('EE C.Lab (U)'));
      expect(dsLab.room, contains('Lab Group 2'));

      // Check Software Engineering
      final se = classes.firstWhere((c) => c.subject == 'Software Engineering');
      expect(se.dayOfWeek, 'Thursday');
      expect(se.startTime, '13:35');
      expect(se.endTime, '15:00');
      expect(se.room, 'CR 2');
    });
  });
}
