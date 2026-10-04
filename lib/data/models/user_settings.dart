/// User preferences for reminders, notifications, and timetable display.
class UserSettings {
  final int? classReminderMinutes; // null = Off; 5, 10, 15 (default), 30, 60
  final bool quizReminderEnabled; // default: true ("The evening before")
  final String quizReminderTime; // default: '20:00' (8:00 pm)
  final bool exactAlarmsGranted; // Android 12+ permission flag
  final bool hideEmptyDays; // Review screen toggle

  const UserSettings({
    this.classReminderMinutes = 15,
    this.quizReminderEnabled = true,
    this.quizReminderTime = '20:00',
    this.exactAlarmsGranted = false,
    this.hideEmptyDays = false,
  });

  /// Factory providing default application settings
  factory UserSettings.defaults() => const UserSettings();

  /// Standard options for class reminder minutes
  static const List<int?> classReminderOptions = [null, 5, 10, 15, 30, 60];

  /// Human-friendly label for class reminder option
  static String classReminderLabel(int? minutes) {
    if (minutes == null || minutes <= 0) return 'Off';
    return '$minutes min before';
  }

  /// Formatted quiz reminder time (e.g. "8:00 pm")
  String get formattedQuizReminderTime {
    final parts = quizReminderTime.split(':');
    if (parts.length != 2) return quizReminderTime;
    final hour = int.tryParse(parts[0]) ?? 20;
    final minute = int.tryParse(parts[1]) ?? 0;
    final period = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  UserSettings copyWith({
    int? classReminderMinutes,
    bool clearClassReminderMinutes = false,
    bool? quizReminderEnabled,
    String? quizReminderTime,
    bool? exactAlarmsGranted,
    bool? hideEmptyDays,
  }) {
    return UserSettings(
      classReminderMinutes: clearClassReminderMinutes
          ? null
          : (classReminderMinutes ?? this.classReminderMinutes),
      quizReminderEnabled: quizReminderEnabled ?? this.quizReminderEnabled,
      quizReminderTime: quizReminderTime ?? this.quizReminderTime,
      exactAlarmsGranted: exactAlarmsGranted ?? this.exactAlarmsGranted,
      hideEmptyDays: hideEmptyDays ?? this.hideEmptyDays,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'classReminderMinutes': classReminderMinutes,
      'quizReminderEnabled': quizReminderEnabled ? 1 : 0,
      'quizReminderTime': quizReminderTime,
      'exactAlarmsGranted': exactAlarmsGranted ? 1 : 0,
      'hideEmptyDays': hideEmptyDays ? 1 : 0,
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      classReminderMinutes: map['classReminderMinutes'] as int?,
      quizReminderEnabled: (map['quizReminderEnabled'] as int? ?? 1) == 1,
      quizReminderTime: map['quizReminderTime'] as String? ?? '20:00',
      exactAlarmsGranted: (map['exactAlarmsGranted'] as int? ?? 0) == 1,
      hideEmptyDays: (map['hideEmptyDays'] as int? ?? 0) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          runtimeType == other.runtimeType &&
          classReminderMinutes == other.classReminderMinutes &&
          quizReminderEnabled == other.quizReminderEnabled &&
          quizReminderTime == other.quizReminderTime &&
          exactAlarmsGranted == other.exactAlarmsGranted &&
          hideEmptyDays == other.hideEmptyDays;

  @override
  int get hashCode =>
      classReminderMinutes.hashCode ^
      quizReminderEnabled.hashCode ^
      quizReminderTime.hashCode ^
      exactAlarmsGranted.hashCode ^
      hideEmptyDays.hashCode;

  @override
  String toString() {
    return 'UserSettings(classRemind: $classReminderMinutes min, quizRemind: $quizReminderEnabled @ $quizReminderTime, exactAlarms: $exactAlarmsGranted)';
  }
}
