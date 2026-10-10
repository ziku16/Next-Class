import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nextclass/data/database/app_database.dart';
import 'package:nextclass/data/models/class_item.dart';
import 'package:nextclass/services/timetable_parser_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('TimetableParserService Image Preprocessing Tests', () {
    test('preprocessImage downscales images exceeding 1600x1200 and encodes JPEG quality 80', () async {
      // 1. Create a synthetic test image with dimensions 2400 x 1800 (4:3 aspect ratio)
      final rawImage = img.Image(width: 2400, height: 1800);
      img.fill(rawImage, color: img.ColorRgb8(255, 255, 255));
      final pngBytes = img.encodePng(rawImage);

      final tempDir = Directory.systemTemp;
      final rawFile = File('${tempDir.path}/test_raw_timetable_${DateTime.now().millisecondsSinceEpoch}.png');
      await rawFile.writeAsBytes(pngBytes, flush: true);

      addTearDown(() async {
        if (await rawFile.exists()) {
          await rawFile.delete();
        }
      });

      // 2. Preprocess the image
      final processedFile = await TimetableParserService.preprocessImage(rawFile);

      addTearDown(() async {
        if (await processedFile.exists()) {
          await processedFile.delete();
        }
      });

      expect(await processedFile.exists(), isTrue);

      // 3. Inspect processed output
      final processedBytes = await processedFile.readAsBytes();
      final decoded = img.decodeImage(processedBytes);

      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(1600));
      expect(decoded.height, lessThanOrEqualTo(1200));

      // 2400x1800 should be scaled to 1600x1200
      expect(decoded.width, 1600);
      expect(decoded.height, 1200);

      // File size must be well within lightweight bounds (< 300 KB)
      expect(processedBytes.length, lessThan(300 * 1024));
    });

    test('preprocessImage preserves smaller images within 1600x1200 bounds without upscaling', () async {
      final rawImage = img.Image(width: 800, height: 600);
      img.fill(rawImage, color: img.ColorRgb8(200, 200, 200));
      final pngBytes = img.encodePng(rawImage);

      final tempDir = Directory.systemTemp;
      final rawFile = File('${tempDir.path}/test_small_timetable_${DateTime.now().millisecondsSinceEpoch}.png');
      await rawFile.writeAsBytes(pngBytes, flush: true);

      addTearDown(() async {
        if (await rawFile.exists()) {
          await rawFile.delete();
        }
      });

      final processedFile = await TimetableParserService.preprocessImage(rawFile);

      addTearDown(() async {
        if (await processedFile.exists()) {
          await processedFile.delete();
        }
      });

      final processedBytes = await processedFile.readAsBytes();
      final decoded = img.decodeImage(processedBytes);

      expect(decoded, isNotNull);
      expect(decoded!.width, 800);
      expect(decoded.height, 600);
    });

    test('preprocessImage returns original file gracefully if file does not exist', () async {
      final nonExistent = File('non_existent_file_path.jpg');
      final result = await TimetableParserService.preprocessImage(nonExistent);
      expect(result.path, nonExistent.path);
    });
  });

  group('TimetableParserService jsonToClassItems & Teacher Mapping Tests', () {
    test('Extracts teacher entity directly from backend JSON and passes to ClassItem', () {
      final mockJson = {
        'schedule': [
          {
            'day': 'Monday',
            'classes': [
              {
                'subject': 'Data Structures & Algorithms',
                'time': '09:00 - 10:30',
                'room': 'Lab 3',
                'teacher': 'Dr. Alan Turing',
              },
              {
                'subject': 'Operating Systems',
                'time': '11:00 - 12:30',
                'room': 'Hall A',
                'teacher': null,
              },
            ],
          },
        ],
      };

      final items = TimetableParserService.jsonToClassItems(mockJson);

      expect(items.length, 2);

      // First class has teacher Dr. Alan Turing
      expect(items[0].subject, 'Data Structures & Algorithms');
      expect(items[0].teacher, 'Dr. Alan Turing');
      expect(items[0].room, 'Lab 3');
      expect(items[0].startTime, '09:00');
      expect(items[0].endTime, '10:30');

      // Second class has null teacher
      expect(items[1].subject, 'Operating Systems');
      expect(items[1].teacher, isNull);
    });

    test('Extracted teacher persists cleanly to SQLite database', () async {
      final dbManager = await AppDatabase.createInMemory();
      final db = await dbManager.database;

      final mockJson = {
        'schedule': [
          {
            'day': 'Wednesday',
            'classes': [
              {
                'subject': 'Compiler Design',
                'time': '14:00 - 15:30',
                'room': 'CS-204',
                'teacher': 'Prof. Grace Hopper',
              },
            ],
          },
        ],
      };

      final items = TimetableParserService.jsonToClassItems(mockJson);
      final item = items.first;

      // Persist to SQLite
      await db.insert('classes', item.toMap());

      // Query from SQLite
      final rows = await db.query('classes', where: 'id = ?', whereArgs: [item.id]);
      expect(rows, isNotEmpty);

      final retrieved = ClassItem.fromMap(rows.first);
      expect(retrieved.teacher, 'Prof. Grace Hopper');
      expect(retrieved.subject, 'Compiler Design');
      expect(retrieved.room, 'CS-204');
    });

    test('Parses flat entries schema with group and teacher correctly', () {
      final mockJson = {
        'entries': [
          {
            'day': 'Tuesday',
            'subject': 'Software Engineering',
            'group': 'CS-4A',
            'start': '10:00',
            'end': '11:30',
            'room': 'Hall B',
            'teacher': 'Dr. Margaret Hamilton',
          },
          {
            'day': 'Thursday',
            'subject': 'Linear Algebra (Section 2)',
            'group': 'Section 2',
            'start': '08:30',
            'end': '10:00',
            'room': null,
            'teacher': '',
          },
        ],
      };

      final items = TimetableParserService.jsonToClassItems(mockJson);
      expect(items.length, 2);

      // First entry: group appended to subject since not present
      expect(items[0].subject, 'Software Engineering (CS-4A)');
      expect(items[0].dayOfWeek, 'Tuesday');
      expect(items[0].startTime, '10:00');
      expect(items[0].endTime, '11:30');
      expect(items[0].room, 'Hall B');
      expect(items[0].teacher, 'Dr. Margaret Hamilton');

      // Second entry: group already in subject, empty teacher converted to null
      expect(items[1].subject, 'Linear Algebra (Section 2)');
      expect(items[1].dayOfWeek, 'Thursday');
      expect(items[1].startTime, '08:30');
      expect(items[1].endTime, '10:00');
      expect(items[1].room, isNull);
      expect(items[1].teacher, isNull);
    });
  });

  group('On-Device Scan Quota Rate Limiting Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Allows scan when under quota', () async {
      final prefs = await SharedPreferences.getInstance();
      await expectLater(
        TimetableParserService.checkScanQuota(prefs),
        completes,
      );
    });

    test('Throws ScanLimitException when 2 daily scans are exhausted', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Record 2 scans today
      await prefs.setStringList('timetable_scan_timestamps', [
        now.subtract(const Duration(hours: 2)).toIso8601String(),
        now.subtract(const Duration(hours: 1)).toIso8601String(),
      ]);

      expect(
        () => TimetableParserService.checkScanQuota(prefs),
        throwsA(isA<ScanLimitException>().having(
          (e) => e.message,
          'message',
          contains('Daily scan limit reached (2/2)'),
        )),
      );
    });

    test('Throws ScanLimitException when 3 rolling weekly scans are exhausted', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Record 3 scans across rolling week (1 today, 2 on previous days)
      await prefs.setStringList('timetable_scan_timestamps', [
        now.subtract(const Duration(days: 3)).toIso8601String(),
        now.subtract(const Duration(days: 2)).toIso8601String(),
        now.subtract(const Duration(hours: 1)).toIso8601String(),
      ]);

      expect(
        () => TimetableParserService.checkScanQuota(prefs),
        throwsA(isA<ScanLimitException>().having(
          (e) => e.message,
          'message',
          contains('Weekly scan limit reached (3/3)'),
        )),
      );
    });

    test('Prunes timestamps older than 7 rolling days', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      await prefs.setStringList('timetable_scan_timestamps', [
        now.subtract(const Duration(days: 10)).toIso8601String(), // Expired
        now.subtract(const Duration(days: 8)).toIso8601String(),  // Expired
        now.subtract(const Duration(days: 2)).toIso8601String(),  // Active
      ]);

      await TimetableParserService.recordSuccessfulScan(prefs);

      final timestamps = await TimetableParserService.getRecentScanTimestamps(prefs);
      // Only the 2-day-old scan and the newly recorded scan should be present
      expect(timestamps.length, 2);
    });

    test('getRemainingScans returns accurate dailyUsed and weeklyUsed', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Initial empty state
      final initial = await TimetableParserService.getRemainingScans(prefs);
      expect(initial['dailyUsed'], 0);
      expect(initial['weeklyUsed'], 0);

      // Record 1 scan today and 1 scan 2 days ago
      await prefs.setStringList('timetable_scan_timestamps', [
        now.subtract(const Duration(hours: 1)).toIso8601String(),
        now.subtract(const Duration(days: 2)).toIso8601String(),
      ]);

      final updated = await TimetableParserService.getRemainingScans(prefs);
      expect(updated['dailyUsed'], 1);
      expect(updated['weeklyUsed'], 2);
    });
  });

  group('Database Clean State and debugResetDatabase Tests', () {
    test('debugResetDatabase wipes all classes and quizzes cleanly', () async {
      final dbManager = await AppDatabase.createInMemory();
      final db = await dbManager.database;

      // Insert dummy class and quiz
      await db.insert('classes', {
        'id': 'test-1',
        'subject': 'Architecture',
        'subjectColorIndex': 1,
        'dayOfWeek': 'Monday',
        'startTime': '09:00',
        'endTime': '10:30',
        'room': '101',
        'teacher': 'Prof. Mies',
        'isAiUnsure': 0,
      });

      await db.insert('quizzes', {
        'id': 'q-1',
        'classId': 'test-1',
        'subject': 'Architecture',
        'title': 'Midterm Quiz',
        'dueDate': '2026-10-15',
        'isCompleted': 0,
      });

      expect((await db.query('classes')).length, 1);
      expect((await db.query('quizzes')).length, 1);

      // Perform reset
      await dbManager.debugResetDatabase();

      expect((await db.query('classes')).length, 0);
      expect((await db.query('quizzes')).length, 0);
      expect((await db.query('settings')).length, 1); // settings retained
    });
  });
}
