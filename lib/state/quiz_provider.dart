import 'package:flutter/foundation.dart';
import '../data/models/class_item.dart';
import '../data/models/quiz_item.dart';
import '../data/repositories/quiz_repository.dart';
import '../data/repositories/timetable_repository.dart';

/// State management for NextClass quizzes (Flow 6).
/// Handles:
/// - Active upcoming quizzes filtering (ignoring past and completed ones)
/// - Chronological grouping: TODAY, TOMORROW, THIS WEEK, LATER
/// - Timetable dependency guard checking
/// - Add, Edit, Delete with 5-second Undo capability
/// - Evening-before reminder scheduling calculation
class QuizProvider extends ChangeNotifier {
  final QuizRepository _quizRepo;
  final TimetableRepository? _timetableRepo;

  DateTime _referenceDate;
  List<QuizItem> _allQuizzes = [];
  List<ClassItem> _classes = [];
  QuizItem? _recentlyDeletedQuiz;
  bool _isLoading = false;
  String? _errorMessage;

  QuizProvider({
    QuizRepository? quizRepository,
    TimetableRepository? timetableRepository,
    DateTime? referenceDate,
    List<QuizItem>? initialQuizzes,
    List<ClassItem>? initialClasses,
  })  : _quizRepo = quizRepository ?? QuizRepository(),
        _timetableRepo = timetableRepository,
        _referenceDate = referenceDate ?? DateTime.now() {
    if (initialQuizzes != null) {
      _allQuizzes = List.from(initialQuizzes);
    }
    if (initialClasses != null) {
      _classes = List.from(initialClasses);
    }
  }

  // --- Getters ---

  DateTime get referenceDate => _referenceDate;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  QuizItem? get recentlyDeletedQuiz => _recentlyDeletedQuiz;
  List<ClassItem> get classes => List.unmodifiable(_classes);

  /// True if user has at least one class in their timetable
  bool get hasTimetableClasses => _classes.isNotEmpty;

  /// Retrieves active quizzes from today onward that are not completed, ordered by due date ASC
  List<QuizItem> get activeQuizzes {
    final startOfToday = DateTime(
      _referenceDate.year,
      _referenceDate.month,
      _referenceDate.day,
    );

    final list = _allQuizzes.where((q) {
      final dueDateZero = DateTime(q.dueDate.year, q.dueDate.month, q.dueDate.day);
      return !dueDateZero.isBefore(startOfToday) && !q.isCompleted;
    }).toList();

    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return List.unmodifiable(list);
  }

  /// True if there are active upcoming quizzes
  bool get hasActiveQuizzes => activeQuizzes.isNotEmpty;

  /// Chronologically grouped map: TODAY, TOMORROW, THIS WEEK, LATER
  Map<QuizUrgency, List<QuizItem>> get groupedQuizzes {
    final grouped = <QuizUrgency, List<QuizItem>>{
      QuizUrgency.today: [],
      QuizUrgency.tomorrow: [],
      QuizUrgency.thisWeek: [],
      QuizUrgency.later: [],
    };

    for (final quiz in activeQuizzes) {
      final category = quiz.urgencyCategory(_referenceDate);
      grouped[category]!.add(quiz);
    }

    return grouped;
  }

  // --- State Mutators ---

  void setReferenceDate(DateTime date) {
    _referenceDate = date;
    notifyListeners();
  }

  void setQuizzes(List<QuizItem> quizzes) {
    _allQuizzes = List.from(quizzes);
    notifyListeners();
  }

  void setClasses(List<ClassItem> classes) {
    _classes = List.from(classes);
    notifyListeners();
  }

  /// Loads quizzes and timetable classes from repositories
  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final quizzesFuture = _quizRepo.getAllQuizzes();
      final classesFuture = _timetableRepo != null
          ? _timetableRepo.getAllClasses()
          : Future.value(_classes);

      final results = await Future.wait([quizzesFuture, classesFuture]);
      _allQuizzes = results[0] as List<QuizItem>;
      _classes = results[1] as List<ClassItem>;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Persists a new quiz to database and schedules 8:00 PM evening-before alarm
  Future<void> addQuiz(QuizItem item) async {
    try {
      await _quizRepo.insertQuiz(item);

      // Local update
      _allQuizzes.removeWhere((q) => q.id == item.id);
      _allQuizzes.add(item);

      scheduleEveningBeforeReminder(item);

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Updates an existing quiz
  Future<void> updateQuiz(QuizItem item) async {
    try {
      await _quizRepo.updateQuiz(item);

      final index = _allQuizzes.indexWhere((q) => q.id == item.id);
      if (index != -1) {
        _allQuizzes[index] = item;
      } else {
        _allQuizzes.add(item);
      }

      scheduleEveningBeforeReminder(item);

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Deletes a quiz by ID and saves it to `recentlyDeletedQuiz` for undo
  Future<void> deleteQuiz(String id) async {
    try {
      final quizToDelete = _allQuizzes.firstWhere((q) => q.id == id);
      _recentlyDeletedQuiz = quizToDelete;

      await _quizRepo.deleteQuiz(id);
      _allQuizzes.removeWhere((q) => q.id == id);

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Restores the most recently deleted quiz (for 5s Undo)
  Future<bool> undoDelete() async {
    final quiz = _recentlyDeletedQuiz;
    if (quiz == null) return false;

    try {
      await _quizRepo.insertQuiz(quiz);
      _allQuizzes.add(quiz);
      _recentlyDeletedQuiz = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggles completed state of a quiz
  Future<void> toggleCompleted(String id) async {
    try {
      await _quizRepo.toggleQuizCompleted(id);
      final index = _allQuizzes.indexWhere((q) => q.id == id);
      if (index != -1) {
        final current = _allQuizzes[index];
        _allQuizzes[index] = current.copyWith(isCompleted: !current.isCompleted);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Calculates the 8:00 PM evening-before reminder time for a quiz
  DateTime calculateEveningBeforeReminderTime(QuizItem item) {
    return DateTime(
      item.dueDate.year,
      item.dueDate.month,
      item.dueDate.day - 1,
      20, // 8:00 PM
      0,
    );
  }

  /// Schedules the 8:00 PM evening-before alarm (hook for Phase 10 Notification Engine)
  void scheduleEveningBeforeReminder(QuizItem item) {
    final reminderTime = calculateEveningBeforeReminderTime(item);
    // Notification engine in Phase 10 will register the exact Android alarm
    if (kDebugMode) {
      debugPrint(
        'Quiz reminder scheduled for "${item.title}" at $reminderTime',
      );
    }
  }
}
