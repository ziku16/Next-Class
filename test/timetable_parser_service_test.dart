import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nextclass/data/database/app_database.dart';
import 'package:nextclass/data/models/class_item.dart';
import 'package:nextclass/services/timetable_parser_service.dart';
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
  });
}
