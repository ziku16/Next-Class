import 'package:flutter/foundation.dart';
import '../data/models/class_item.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/timetable_repository.dart';

/// State management for timetable reviewing, editing, and saving.
class TimetableProvider extends ChangeNotifier {
  final TimetableRepository _timetableRepo;
  final SettingsRepository? _settingsRepo;

  List<ClassItem> _classes = [];
  List<ClassItem> _initialBaseline = [];
  bool _hideEmptyDays = false;
  bool _hideEmptyDaysExplicitlySet = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  Future<void>? _loadSettingsFuture;

  TimetableProvider({
    TimetableRepository? timetableRepository,
    SettingsRepository? settingsRepository,
    List<ClassItem>? initialClasses,
  })  : _timetableRepo = timetableRepository ?? TimetableRepository(),
        _settingsRepo = settingsRepository {
    if (initialClasses != null) {
      setClasses(initialClasses, markAsClean: true);
    }
    _loadSettingsFuture = _loadSettings();
  }

  List<ClassItem> get classes => List.unmodifiable(_classes);
  bool get hideEmptyDays => _hideEmptyDays;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get hasAiUnsureClasses => _classes.any((c) => c.isAiUnsure);

  Future<void> _loadSettings() async {
    final repo = _settingsRepo;
    if (repo != null) {
      try {
        final settings = await repo.getUserSettings();
        if (!_hideEmptyDaysExplicitlySet) {
          _hideEmptyDays = settings.hideEmptyDays;
          notifyListeners();
        }
      } catch (_) {
        // Fallback to default
      }
    }
  }

  /// Sets the classes in the provider and optionally marks them as clean (baseline).
  void setClasses(List<ClassItem> items, {bool markAsClean = true}) {
    _classes = List.from(items);
    _sortClasses();
    if (markAsClean) {
      _initialBaseline = List.from(_classes);
      _hasUnsavedChanges = false;
    } else {
      _checkUnsavedChanges();
    }
    notifyListeners();
  }

  /// Toggles the 'Hide empty days' preference and updates settings persistence.
  Future<void> setHideEmptyDays(bool value) async {
    _hideEmptyDaysExplicitlySet = true;
    _hideEmptyDays = value;
    notifyListeners();
    final repo = _settingsRepo;
    if (repo != null) {
      try {
        if (_loadSettingsFuture != null) {
          await _loadSettingsFuture;
        }
        final settings = await repo.getUserSettings();
        await repo.updateUserSettings(settings.copyWith(hideEmptyDays: value));
      } catch (_) {}
    }
  }

  void _sortClasses() {
    _classes.sort((a, b) {
      final dayCompare = a.dayIndex.compareTo(b.dayIndex);
      if (dayCompare != 0) return dayCompare;
      return a.startMinutes.compareTo(b.startMinutes);
    });
  }

  void _checkUnsavedChanges() {
    if (_classes.length != _initialBaseline.length) {
      _hasUnsavedChanges = true;
      return;
    }
    for (int i = 0; i < _classes.length; i++) {
      if (_classes[i] != _initialBaseline[i]) {
        _hasUnsavedChanges = true;
        return;
      }
    }
    _hasUnsavedChanges = false;
  }

  /// Gets all classes scheduled for a specific day of the week, sorted by start time.
  List<ClassItem> getClassesForDay(String dayOfWeek) {
    return _classes.where((c) => c.dayOfWeek == dayOfWeek).toList();
  }

  /// Count of classes scheduled on a specific day.
  int getClassCountForDay(String dayOfWeek) {
    return _classes.where((c) => c.dayOfWeek == dayOfWeek).length;
  }

  /// Assigns or reuses a subject color index (0..7) for a subject name.
  int getSubjectColorForName(String subject) {
    final trimmed = subject.trim().toLowerCase();
    for (final c in _classes) {
      if (c.subject.trim().toLowerCase() == trimmed) {
        return c.subjectColorIndex;
      }
    }
    return trimmed.hashCode.abs() % 8;
  }

  /// Adds a new class to the timetable.
  void addClass(ClassItem item) {
    _classes.add(item);
    _sortClasses();
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// Updates an existing class in the timetable.
  void updateClass(ClassItem updatedItem) {
    final index = _classes.indexWhere((c) => c.id == updatedItem.id);
    if (index != -1) {
      _classes[index] = updatedItem;
      _sortClasses();
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Deletes a class by its unique ID.
  void deleteClass(String id) {
    _classes.removeWhere((c) => c.id == id);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// Restores a deleted class (e.g. on Undo).
  void restoreClass(ClassItem item) {
    if (!_classes.any((c) => c.id == item.id)) {
      _classes.add(item);
      _sortClasses();
      _checkUnsavedChanges();
      notifyListeners();
    }
  }

  /// Persists all current classes atomically into the SQLite database.
  Future<bool> saveTimetable() async {
    _isSaving = true;
    notifyListeners();
    try {
      await _timetableRepo.replaceAllClasses(_classes);
      _initialBaseline = List.from(_classes);
      _hasUnsavedChanges = false;
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Loads classes from the SQLite database.
  Future<void> loadFromDatabase() async {
    _isLoading = true;
    notifyListeners();
    try {
      final items = await _timetableRepo.getAllClasses();
      _classes = items;
      _initialBaseline = List.from(items);
      _hasUnsavedChanges = false;
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }
}
