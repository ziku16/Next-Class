import 'package:flutter/foundation.dart';
import '../data/models/scan_quota.dart';
import '../data/models/user_settings.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/services/alarm_scheduler.dart';

/// State management for NextClass User Settings & Reminders (Flows 7 & 8).
/// Manages:
/// - Class reminder interval (Off, 5, 10, 15, 30, 60m)
/// - Quiz reminder toggle & evening-before time picker
/// - Notifications & exact alarms permission statuses
/// - Scan quota reflection for timetable upload tile
class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repo;

  UserSettings _settings;
  ScanQuota _quota;
  bool _isLoading = false;
  bool _notificationsEnabled = true;

  SettingsProvider({
    SettingsRepository? settingsRepository,
    UserSettings? initialSettings,
    ScanQuota? initialQuota,
    this._notificationsEnabled = true,
  })  : _repo = settingsRepository ?? SettingsRepository(),
        _settings = initialSettings ?? UserSettings.defaults(),
        _quota = initialQuota ?? ScanQuota.initial();

  // --- Getters ---

  UserSettings get settings => _settings;
  ScanQuota get quota => _quota;
  bool get isLoading => _isLoading;
  bool get notificationsEnabled => _notificationsEnabled;

  int? get classReminderMinutes => _settings.classReminderMinutes;
  bool get quizReminderEnabled => _settings.quizReminderEnabled;
  String get quizReminderTime => _settings.quizReminderTime;
  String get formattedQuizReminderTime => _settings.formattedQuizReminderTime;
  bool get exactAlarmsGranted => _settings.exactAlarmsGranted;
  bool get hideEmptyDays => _settings.hideEmptyDays;

  /// Formatted scan quota badge text (e.g. "2 of 2 left today · 3 of 3 this week")
  String get quotaDisplayText {
    final dailyLeft = 2 - _quota.dailyScansUsed;
    final weeklyLeft = 3 - _quota.weeklyScansUsed;
    return '$dailyLeft of 2 left today · $weeklyLeft of 3 this week';
  }

  // --- Actions ---

  /// Loads persisted settings and scan quota from repository
  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final loadedSettings = await _repo.getUserSettings();
      final loadedQuota = await _repo.getScanQuota();

      _settings = loadedSettings;
      _quota = loadedQuota;
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets in-memory settings (useful for tests and previews)
  void setSettings(UserSettings newSettings) {
    _settings = newSettings;
    notifyListeners();
  }

  /// Sets in-memory scan quota
  void setQuota(ScanQuota newQuota) {
    _quota = newQuota;
    notifyListeners();
  }

  /// Updates class reminder minutes (null = Off; 5, 10, 15, 30, 60)
  Future<void> updateClassReminderMinutes(int? minutes) async {
    final updated = minutes == null
        ? _settings.copyWith(clearClassReminderMinutes: true)
        : _settings.copyWith(classReminderMinutes: minutes);

    _settings = updated;
    notifyListeners();

    try {
      await _repo.updateUserSettings(updated);
    } catch (_) {}

    try {
      await AlarmScheduler().rescheduleAll();
    } catch (_) {}
  }

  /// Toggles the quiz reminder evening-before switch
  Future<void> toggleQuizReminder(bool enabled) async {
    final updated = _settings.copyWith(quizReminderEnabled: enabled);
    _settings = updated;
    notifyListeners();

    try {
      await _repo.updateUserSettings(updated);
    } catch (_) {}

    try {
      await AlarmScheduler().rescheduleAll();
    } catch (_) {}
  }

  /// Updates quiz reminder time ('HH:mm', e.g. '20:00' for 8:00 pm)
  Future<void> updateQuizReminderTime(String timeHHmm) async {
    final updated = _settings.copyWith(quizReminderTime: timeHHmm);
    _settings = updated;
    notifyListeners();

    try {
      await _repo.updateUserSettings(updated);
    } catch (_) {}

    try {
      await AlarmScheduler().rescheduleAll();
    } catch (_) {}
  }

  /// Toggles app notification permission flag
  void toggleNotifications(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
  }

  /// Sets exact alarms permission status (Android 12+)
  Future<void> setExactAlarmsGranted(bool granted) async {
    final updated = _settings.copyWith(exactAlarmsGranted: granted);
    _settings = updated;
    notifyListeners();

    try {
      await _repo.updateUserSettings(updated);
    } catch (_) {}
  }

  /// Refreshes quota from repository
  Future<void> refreshQuota() async {
    try {
      final refreshed = await _repo.getScanQuota();
      _quota = refreshed;
      notifyListeners();
    } catch (_) {}
  }
}
