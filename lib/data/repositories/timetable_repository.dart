import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/class_item.dart';

/// Repository handling persistence and retrieval of timetable classes.
class TimetableRepository {
  final AppDatabase _dbManager;
  final _classesStreamController = StreamController<List<ClassItem>>.broadcast();

  TimetableRepository({AppDatabase? dbManager})
      : _dbManager = dbManager ?? AppDatabase.instance;

  /// Stream of all classes, updated whenever classes change
  Stream<List<ClassItem>> get classesStream => _classesStreamController.stream;

  void dispose() {
    _classesStreamController.close();
  }

  Future<void> _notifyListeners() async {
    final classes = await getAllClasses();
    _classesStreamController.add(classes);
  }

  /// Retrieves all classes, ordered by day of week and start time.
  Future<List<ClassItem>> getAllClasses() async {
    final db = await _dbManager.database;
    final maps = await db.query('classes');

    final list = maps.map((m) => ClassItem.fromMap(m)).toList();

    // Sort by dayOfWeek order, then by start time
    list.sort((a, b) {
      final dayCompare = a.dayIndex.compareTo(b.dayIndex);
      if (dayCompare != 0) return dayCompare;
      return a.startMinutes.compareTo(b.startMinutes);
    });

    return list;
  }

  /// Retrieves classes scheduled for a specific day of the week.
  Future<List<ClassItem>> getClassesForDay(String dayOfWeek) async {
    final db = await _dbManager.database;
    final maps = await db.query(
      'classes',
      where: 'dayOfWeek = ?',
      whereArgs: [dayOfWeek],
    );

    final list = maps.map((m) => ClassItem.fromMap(m)).toList();
    list.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return list;
  }

  /// Retrieves a single class by its ID.
  Future<ClassItem?> getClassById(String id) async {
    final db = await _dbManager.database;
    final maps = await db.query(
      'classes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return ClassItem.fromMap(maps.first);
  }

  /// Inserts a new class.
  Future<void> insertClass(ClassItem item) async {
    final db = await _dbManager.database;
    await db.insert(
      'classes',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notifyListeners();
  }

  /// Transactionally inserts multiple classes (e.g. during timetable creation).
  Future<void> insertClasses(List<ClassItem> items) async {
    final db = await _dbManager.database;
    await db.transaction((txn) async {
      for (final item in items) {
        await txn.insert(
          'classes',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await _notifyListeners();
  }

  /// Updates an existing class.
  Future<void> updateClass(ClassItem item) async {
    final db = await _dbManager.database;
    await db.update(
      'classes',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    await _notifyListeners();
  }

  /// Deletes a class by ID. Due to SQLite foreign key cascade, linked quizzes are also purged.
  Future<void> deleteClass(String id) async {
    final db = await _dbManager.database;
    await db.delete(
      'classes',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _notifyListeners();
  }

  /// Atomically replaces the entire timetable with a new set of classes.
  Future<void> replaceAllClasses(List<ClassItem> newClasses) async {
    final db = await _dbManager.database;
    await db.transaction((txn) async {
      await txn.delete('classes');
      for (final item in newClasses) {
        await txn.insert(
          'classes',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await _notifyListeners();
  }

  /// Checks if any timetable classes exist
  Future<bool> hasClasses() async {
    final db = await _dbManager.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM classes'),
    );
    return (count ?? 0) > 0;
  }
}
