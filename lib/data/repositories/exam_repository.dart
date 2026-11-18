import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/exam_item.dart';
import '../models/exam_schedule.dart';

/// Persistence for saved examination schedules and their dated entries.
class ExamRepository {
  final AppDatabase _dbManager;

  ExamRepository({AppDatabase? dbManager})
      : _dbManager = dbManager ?? AppDatabase.instance;

  Future<List<ExamSchedule>> getSchedules() async {
    final db = await _dbManager.database;
    final rows = await db.query('exam_schedules', orderBy: 'createdAt DESC');
    return rows.map(ExamSchedule.fromMap).toList();
  }

  Future<ExamSchedule?> getActiveSchedule() async {
    final db = await _dbManager.database;
    final rows = await db.query(
      'exam_schedules', where: 'isActive = 1', limit: 1,
    );
    return rows.isEmpty ? null : ExamSchedule.fromMap(rows.first);
  }

  Future<List<ExamItem>> getExams({String? scheduleId}) async {
    final db = await _dbManager.database;
    final id = scheduleId ?? (await getActiveSchedule())?.id;
    if (id == null) return [];
    final rows = await db.query(
      'exams',
      where: 'scheduleId = ?',
      whereArgs: [id],
      orderBy: 'examDate ASC, startTime ASC, subject COLLATE NOCASE ASC',
    );
    return rows.map(ExamItem.fromMap).toList();
  }

  /// Saves only after the user confirms review and makes the new schedule active.
  Future<void> saveConfirmedSchedule(
    ExamSchedule schedule,
    List<ExamItem> exams,
  ) async {
    final db = await _dbManager.database;
    await db.transaction((txn) async {
      await txn.update('exam_schedules', {'isActive': 0});
      await txn.insert(
        'exam_schedules',
        schedule.copyWith(isActive: true).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final exam in exams) {
        await txn.insert(
          'exams',
          exam.copyWith(scheduleId: schedule.id).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> activateSchedule(String id) async {
    final db = await _dbManager.database;
    await db.transaction((txn) async {
      final rows = await txn.query('exam_schedules', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) throw StateError('Examination schedule not found.');
      await txn.update('exam_schedules', {'isActive': 0});
      await txn.update('exam_schedules', {'isActive': 1}, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> saveExam(ExamItem exam) async {
    final db = await _dbManager.database;
    await db.insert('exams', exam.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteExam(String id) async {
    final db = await _dbManager.database;
    await db.delete('exams', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSchedule(String id) async {
    final db = await _dbManager.database;
    await db.delete('exam_schedules', where: 'id = ?', whereArgs: [id]);
  }
}
