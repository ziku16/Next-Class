import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/quiz_item.dart';

/// Repository handling persistence and grouping of quizzes.
class QuizRepository {
  final AppDatabase _dbManager;
  final _quizzesStreamController = StreamController<List<QuizItem>>.broadcast();

  QuizRepository({AppDatabase? dbManager})
      : _dbManager = dbManager ?? AppDatabase.instance;

  /// Stream of all active quizzes, updated whenever quizzes change
  Stream<List<QuizItem>> get quizzesStream => _quizzesStreamController.stream;

  void dispose() {
    _quizzesStreamController.close();
  }

  Future<void> _notifyListeners() async {
    final quizzes = await getAllQuizzes();
    _quizzesStreamController.add(quizzes);
  }

  /// Retrieves all quizzes ordered by due date ascending.
  Future<List<QuizItem>> getAllQuizzes() async {
    final db = await _dbManager.database;
    final maps = await db.query(
      'quizzes',
      orderBy: 'dueDate ASC',
    );
    return maps.map((m) => QuizItem.fromMap(m)).toList();
  }

  /// Retrieves upcoming quizzes (from midnight of reference date onward, ignoring past ones).
  Future<List<QuizItem>> getUpcomingQuizzes({DateTime? referenceDate}) async {
    final ref = referenceDate ?? DateTime.now();
    final startOfToday = DateTime(ref.year, ref.month, ref.day);

    final db = await _dbManager.database;
    final maps = await db.query(
      'quizzes',
      where: 'dueDate >= ? AND isCompleted = 0',
      whereArgs: [startOfToday.toIso8601String()],
      orderBy: 'dueDate ASC',
    );
    return maps.map((m) => QuizItem.fromMap(m)).toList();
  }

  /// Categorizes upcoming quizzes into Design System buckets: TODAY, TOMORROW, THIS WEEK, LATER.
  Future<Map<QuizUrgency, List<QuizItem>>> getGroupedUpcomingQuizzes({DateTime? referenceDate}) async {
    final ref = referenceDate ?? DateTime.now();
    final upcoming = await getUpcomingQuizzes(referenceDate: ref);

    final grouped = <QuizUrgency, List<QuizItem>>{
      QuizUrgency.today: [],
      QuizUrgency.tomorrow: [],
      QuizUrgency.thisWeek: [],
      QuizUrgency.later: [],
    };

    for (final quiz in upcoming) {
      final category = quiz.urgencyCategory(ref);
      grouped[category]!.add(quiz);
    }

    return grouped;
  }

  /// Retrieves all quizzes associated with a specific class.
  Future<List<QuizItem>> getQuizzesForClass(String classId) async {
    final db = await _dbManager.database;
    final maps = await db.query(
      'quizzes',
      where: 'classId = ?',
      whereArgs: [classId],
      orderBy: 'dueDate ASC',
    );
    return maps.map((m) => QuizItem.fromMap(m)).toList();
  }

  /// Inserts a new quiz.
  Future<void> insertQuiz(QuizItem item) async {
    final db = await _dbManager.database;
    await db.insert(
      'quizzes',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notifyListeners();
  }

  /// Updates an existing quiz.
  Future<void> updateQuiz(QuizItem item) async {
    final db = await _dbManager.database;
    await db.update(
      'quizzes',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    await _notifyListeners();
  }

  /// Deletes a quiz by its ID.
  Future<void> deleteQuiz(String id) async {
    final db = await _dbManager.database;
    await db.delete(
      'quizzes',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _notifyListeners();
  }

  /// Toggles the completion state of a quiz.
  Future<void> toggleQuizCompleted(String id) async {
    final db = await _dbManager.database;
    final maps = await db.query('quizzes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return;

    final quiz = QuizItem.fromMap(maps.first);
    final updated = quiz.copyWith(isCompleted: !quiz.isCompleted);
    await updateQuiz(updated);
  }
}
