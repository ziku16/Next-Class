import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/data/models/class_item.dart';
import 'package:nextclass/domain/parser/class_deduplicator.dart';
import 'package:nextclass/domain/parser/day_detector.dart';
import 'package:nextclass/domain/parser/deterministic_class_parser.dart';
import 'package:nextclass/domain/parser/field_classifiers.dart';
import 'package:nextclass/domain/parser/grid_cell_assigner.dart';
import 'package:nextclass/domain/parser/ocr_models.dart';
import 'package:nextclass/domain/parser/time_detector.dart';
import 'package:nextclass/domain/parser/timetable_grid_detector.dart';

void main() {
  group('Universal Timetable Parser 8 Core Regression Edge Cases (PART 27)', () {
    const parser = DeterministicClassParser();
    const assigner = GridCellAssigner();
    const gridDetector = TimetableGridDetector();

    // ------------------------------------------------------------------------
    // Test 1: Duplicates merged into 1 class
    // Same class detected twice on one day (duplicate OCR block / multi-span)
    // must be merged into a single canonical class.
    // ------------------------------------------------------------------------
    test('Test 1: Duplicates merged into 1 class via multi-level deduplication', () {
      final rawClasses = [
        ClassItem(
          id: 'c1',
          dayOfWeek: 'Monday',
          startTime: '08:30',
          endTime: '10:00',
          subject: 'Operating Systems',
          teacher: 'Dr. Arshad',
          room: 'LT 1',
          subjectColorIndex: 0,
        ),
        ClassItem(
          id: 'c2',
          dayOfWeek: 'Monday',
          startTime: '08:30',
          endTime: '10:00',
          subject: 'Operating Systems',
          teacher: 'Dr. Arshad',
          room: 'LT 1',
          subjectColorIndex: 0,
        ),
      ];

      final deduplicated = ClassDeduplicator.deduplicateClasses(rawClasses);

      expect(deduplicated.length, 1,
          reason: 'Duplicate identical class blocks must be merged into 1');
      expect(deduplicated.first.subject, 'Operating Systems');
      expect(deduplicated.first.teacher, 'Dr. Arshad');
      expect(deduplicated.first.room, 'LT 1');
    });

    // ------------------------------------------------------------------------
    // Test 2: Room never mistaken as subject
    // ("Data Structures", "Mr. Ali", "LT 1") -> Subject: Data Structures, Room: LT 1
    // ------------------------------------------------------------------------
    test('Test 2: Room never mistaken as subject (Data Structures, Mr. Ali, LT 1)', () {
      // Direct classifier checks
      expect(FieldClassifiers.isLocation('LT 1'), isTrue);
      expect(FieldClassifiers.isValidSubject('LT 1'), isFalse,
          reason: 'LT 1 is a room, must never qualify as a subject');
      expect(FieldClassifiers.isTeacher('Mr. Ali'), isTrue);
      expect(FieldClassifiers.isValidSubject('Data Structures'), isTrue);

      const cell = TimetableCell(
        dayOfWeek: 'Tuesday',
        startTime: '08:30',
        endTime: '10:00',
        columnIndex: 0,
        rowIndex: 1,
        timeSlotIndex: 0,
        boundingBox: Rect.fromLTWH(100, 100, 200, 100),
        lines: [
          OcrTextLine(
            text: 'Data Structures',
            boundingBox: Rect.fromLTWH(110, 110, 180, 20),
          ),
          OcrTextLine(
            text: 'Mr. Ali',
            boundingBox: Rect.fromLTWH(110, 135, 180, 20),
          ),
          OcrTextLine(
            text: 'LT 1',
            boundingBox: Rect.fromLTWH(110, 160, 180, 20),
          ),
        ],
      );

      final classes = parser.parseCells([cell]);

      expect(classes.length, 1);
      final cls = classes.first;
      expect(cls.subject, 'Data Structures',
          reason: 'Subject must be Data Structures, not LT 1 or Mr. Ali');
      expect(cls.teacher, 'Mr. Ali');
      expect(cls.room, 'LT 1');
    });

    // ------------------------------------------------------------------------
    // Test 3: Time never mistaken as teacher
    // ("10:00 - 11:30") -> Time must never become teacher or subject
    // ------------------------------------------------------------------------
    test('Test 3: Time never mistaken as teacher (10:00 - 11:30)', () {
      const timeStr = '10:00 - 11:30';
      expect(FieldClassifiers.isTime(timeStr), isTrue);
      expect(FieldClassifiers.isTeacher(timeStr), isFalse,
          reason: 'Time range must never be classified as teacher');
      expect(FieldClassifiers.isValidSubject(timeStr), isFalse,
          reason: 'Time range must never be classified as subject');
      expect(FieldClassifiers.isLocation(timeStr), isFalse,
          reason: 'Time range must never be classified as room');

      const cell = TimetableCell(
        dayOfWeek: 'Wednesday',
        startTime: '08:30',
        endTime: '10:00',
        columnIndex: 1,
        rowIndex: 2,
        timeSlotIndex: 1,
        boundingBox: Rect.fromLTWH(100, 200, 200, 100),
        lines: [
          OcrTextLine(
            text: 'Linear Algebra',
            boundingBox: Rect.fromLTWH(110, 210, 180, 20),
          ),
          OcrTextLine(
            text: '10:00 - 11:30',
            boundingBox: Rect.fromLTWH(110, 235, 180, 20),
          ),
          OcrTextLine(
            text: 'CR 2',
            boundingBox: Rect.fromLTWH(110, 260, 180, 20),
          ),
        ],
      );

      final classes = parser.parseCells([cell]);

      expect(classes.length, 1);
      final cls = classes.first;
      expect(cls.subject, 'Linear Algebra');
      expect(cls.teacher, isNull,
          reason: 'Time string must not be assigned to teacher');
      expect(cls.room, 'CR 2');
      // Cell-internal time range overrides row time
      expect(cls.startTime, '10:00');
      expect(cls.endTime, '11:30');
    });

    // ------------------------------------------------------------------------
    // Test 4: Header filtering
    // ("Lecture 1", "8:30 - 10:00") -> Must not create classes
    // ------------------------------------------------------------------------
    test('Test 4: Header filtering (Lecture 1, 8:30 - 10:00 not classes)', () {
      expect(FieldClassifiers.isLectureHeader('Lecture 1'), isTrue);
      expect(FieldClassifiers.isLectureHeader('LEC-02'), isTrue);
      expect(FieldClassifiers.isLectureHeader('Period 3'), isTrue);
      expect(FieldClassifiers.isValidSubject('Lecture 1'), isFalse);
      expect(FieldClassifiers.isTime('8:30 - 10:00'), isTrue);
      expect(FieldClassifiers.isValidSubject('8:30 - 10:00'), isFalse);

      const cell = TimetableCell(
        dayOfWeek: 'Thursday',
        startTime: '08:30',
        endTime: '10:00',
        columnIndex: 0,
        rowIndex: 3,
        timeSlotIndex: 0,
        boundingBox: Rect.fromLTWH(100, 100, 200, 100),
        lines: [
          OcrTextLine(
            text: 'Lecture 1',
            boundingBox: Rect.fromLTWH(110, 110, 180, 20),
          ),
          OcrTextLine(
            text: '8:30 - 10:00',
            boundingBox: Rect.fromLTWH(110, 135, 180, 20),
          ),
        ],
      );

      final classes = parser.parseCells([cell]);
      expect(classes, isEmpty,
          reason: 'Headers alone in a cell must produce zero classes');
    });

    // ------------------------------------------------------------------------
    // Test 5: Footer filtering
    // ("aSc Timetables", "Generated on 12/04/2026") -> Discarded, not classes
    // ------------------------------------------------------------------------
    test('Test 5: Footer filtering (aSc Timetables and watermark noise)', () {
      expect(FieldClassifiers.isFooterOrNoise('aSc Timetables'), isTrue);
      expect(FieldClassifiers.isFooterOrNoise('Timetable generated with aSc'), isTrue);
      expect(FieldClassifiers.isFooterOrNoise('Generated: 2026-09-01'), isTrue);
      expect(FieldClassifiers.isFooterOrNoise('Page 1 of 1'), isTrue);
      expect(FieldClassifiers.isFooterOrNoise('------------------'), isTrue);
      expect(FieldClassifiers.isFooterOrNoise('=================='), isTrue);

      const cell = TimetableCell(
        dayOfWeek: 'Friday',
        startTime: '11:30',
        endTime: '13:00',
        columnIndex: 2,
        rowIndex: 4,
        timeSlotIndex: 2,
        boundingBox: Rect.fromLTWH(100, 300, 200, 100),
        lines: [
          OcrTextLine(
            text: 'aSc Timetables',
            boundingBox: Rect.fromLTWH(110, 310, 180, 20),
          ),
          OcrTextLine(
            text: '------------------',
            boundingBox: Rect.fromLTWH(110, 335, 180, 20),
          ),
        ],
      );

      final classes = parser.parseCells([cell]);
      expect(classes, isEmpty,
          reason: 'Footer watermark lines must never produce classes');
    });

    // ------------------------------------------------------------------------
    // Test 6: Dual lab classes in single cell correctly split without leakage
    // Multi-group split: DBS(Lab) / Ms. Mehreen / Lab Group 1 / CS C.Lab 7
    //               and DS(Lab)  / Mr. Bilal   / Lab Group 2 / EE C.Lab (U)
    // ------------------------------------------------------------------------
    test('Test 6: Dual lab classes in single cell split without attribute leakage', () {
      const cell = TimetableCell(
        dayOfWeek: 'Wednesday',
        startTime: '10:00',
        endTime: '11:30',
        columnIndex: 1,
        rowIndex: 2,
        timeSlotIndex: 1,
        boundingBox: Rect.fromLTWH(100, 150, 300, 150),
        lines: [
          OcrTextLine(
            text: 'DBS(Lab)',
            boundingBox: Rect.fromLTWH(110, 160, 120, 20),
          ),
          OcrTextLine(
            text: 'Ms. Mehreen Wahab',
            boundingBox: Rect.fromLTWH(110, 185, 120, 20),
          ),
          OcrTextLine(
            text: 'Lab Group 1',
            boundingBox: Rect.fromLTWH(110, 210, 120, 20),
          ),
          OcrTextLine(
            text: 'CS C.Lab 7',
            boundingBox: Rect.fromLTWH(110, 235, 120, 20),
          ),
          OcrTextLine(
            text: 'DS(Lab)',
            boundingBox: Rect.fromLTWH(240, 160, 120, 20),
          ),
          OcrTextLine(
            text: 'Mr. Bilal Bukhari',
            boundingBox: Rect.fromLTWH(240, 185, 120, 20),
          ),
          OcrTextLine(
            text: 'Lab Group 2',
            boundingBox: Rect.fromLTWH(240, 210, 120, 20),
          ),
          OcrTextLine(
            text: 'EE C.Lab (U)',
            boundingBox: Rect.fromLTWH(240, 235, 120, 20),
          ),
        ],
      );

      final classes = parser.parseCells([cell]);

      expect(classes.length, 2,
          reason: 'Single cell with dual labs must split into exactly 2 classes');

      final lab1 = classes.firstWhere((c) => c.subject.contains('DBS'));
      final lab2 = classes.firstWhere((c) => c.subject.contains('DS') && !c.subject.contains('DBS'));

      // Validate Lab 1 attributes (no leakage from Lab 2)
      expect(lab1.teacher, 'Ms. Mehreen Wahab');
      expect(lab1.room, contains('CS C.Lab 7'));
      expect(lab1.room, contains('Lab Group 1'));
      expect(lab1.room, isNot(contains('EE C.Lab')));
      expect(lab1.teacher, isNot(contains('Mr. Bilal')));

      // Validate Lab 2 attributes (no leakage from Lab 1)
      expect(lab2.teacher, 'Mr. Bilal Bukhari');
      expect(lab2.room, contains('EE C.Lab (U)'));
      expect(lab2.room, contains('Lab Group 2'));
      expect(lab2.room, isNot(contains('CS C.Lab 7')));
      expect(lab2.teacher, isNot(contains('Ms. Mehreen')));
    });

    // ------------------------------------------------------------------------
    // Test 7: Empty cell produces zero classes
    // Cells with empty lines or whitespace only must produce zero classes
    // ------------------------------------------------------------------------
    test('Test 7: Empty cell produces zero classes', () {
      const emptyCell1 = TimetableCell(
        dayOfWeek: 'Monday',
        startTime: '13:00',
        endTime: '14:30',
        columnIndex: 3,
        rowIndex: 0,
        timeSlotIndex: 3,
        boundingBox: Rect.fromLTWH(100, 300, 200, 100),
        lines: [],
      );

      const emptyCell2 = TimetableCell(
        dayOfWeek: 'Tuesday',
        startTime: '13:00',
        endTime: '14:30',
        columnIndex: 3,
        rowIndex: 1,
        timeSlotIndex: 3,
        boundingBox: Rect.fromLTWH(100, 300, 200, 100),
        lines: [
          OcrTextLine(text: '   ', boundingBox: Rect.fromLTWH(110, 310, 50, 20)),
          OcrTextLine(text: '', boundingBox: Rect.fromLTWH(110, 340, 50, 20)),
        ],
      );

      final classes = parser.parseCells([emptyCell1, emptyCell2]);
      expect(classes, isEmpty,
          reason: 'Empty cells must strictly produce 0 classes');
    });

    // ------------------------------------------------------------------------
    // Test 8: Different layout (Days as columns, Times as rows)
    // Layout detection determines orientation and parses correctly
    // ------------------------------------------------------------------------
    test('Test 8: Different layout (Days as columns, Times as rows)', () {
      // Setup OCR text lines with Days horizontally across the top (columns)
      // and Time Slots vertically along the left (rows)
      final ocrResult = OcrResult(
        blocks: [],
        lines: [
          // Header Days as columns (Y=50)
          const OcrTextLine(text: 'Monday', boundingBox: Rect.fromLTWH(150, 50, 100, 30)),
          const OcrTextLine(text: 'Tuesday', boundingBox: Rect.fromLTWH(270, 50, 100, 30)),
          const OcrTextLine(text: 'Wednesday', boundingBox: Rect.fromLTWH(390, 50, 100, 30)),
          const OcrTextLine(text: 'Thursday', boundingBox: Rect.fromLTWH(510, 50, 100, 30)),
          const OcrTextLine(text: 'Friday', boundingBox: Rect.fromLTWH(630, 50, 100, 30)),

          // Time Slots as rows along left (X=40)
          const OcrTextLine(text: '08:30 - 10:00', boundingBox: Rect.fromLTWH(40, 100, 100, 30)),
          const OcrTextLine(text: '10:00 - 11:30', boundingBox: Rect.fromLTWH(40, 200, 100, 30)),

          // Monday Slot 0 (X=150..250, Y=100..190): Machine Learning
          const OcrTextLine(text: 'Machine Learning', boundingBox: Rect.fromLTWH(160, 110, 80, 15)),
          const OcrTextLine(text: 'Dr. Alan Turing', boundingBox: Rect.fromLTWH(160, 128, 80, 15)),
          const OcrTextLine(text: 'Lab 5', boundingBox: Rect.fromLTWH(160, 146, 80, 15)),

          // Wednesday Slot 1 (X=390..490, Y=200..290): Cloud Computing
          const OcrTextLine(text: 'Cloud Computing', boundingBox: Rect.fromLTWH(400, 205, 80, 15)),
          const OcrTextLine(text: 'Prof. Hopper', boundingBox: Rect.fromLTWH(400, 223, 80, 15)),
          const OcrTextLine(text: 'CR 10', boundingBox: Rect.fromLTWH(400, 241, 80, 15)),
        ],
        fullText: '',
        imageSize: const Size(800, 400),
      );

      final grid = gridDetector.detectGrid(ocrResult);
      expect(grid, isNotNull);
      expect(grid!.isDaysAsRows, isFalse,
          reason: 'Orientation must detect Days as horizontal columns, not rows');

      final cells = assigner.assignLinesToCells(ocrResult: ocrResult, grid: grid);
      final classes = parser.parseCells(cells);

      expect(classes.length, 2);

      final ml = classes.firstWhere((c) => c.subject == 'Machine Learning');
      expect(ml.dayOfWeek, 'Monday');
      expect(ml.startTime, '08:30');
      expect(ml.endTime, '10:00');
      expect(ml.teacher, 'Dr. Alan Turing');
      expect(ml.room, 'Lab 5');

      final cloud = classes.firstWhere((c) => c.subject == 'Cloud Computing');
      expect(cloud.dayOfWeek, 'Wednesday');
      expect(cloud.startTime, '10:00');
      expect(cloud.endTime, '11:30');
      expect(cloud.teacher, 'Prof. Hopper');
      expect(cloud.room, 'CR 10');
    });
  });
}
