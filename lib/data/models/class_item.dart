/// Domain model representing a scheduled class session.
class ClassItem {
  final String id;
  final String subject;
  final int subjectColorIndex; // 0..7
  final String dayOfWeek; // 'Monday', 'Tuesday', etc.
  final String startTime; // 'HH:mm' 24h
  final String endTime; // 'HH:mm' 24h
  final String? room;
  final String? teacher;
  final bool isAiUnsure;

  const ClassItem({
    required this.id,
    required this.subject,
    required this.subjectColorIndex,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
    this.teacher,
    this.isAiUnsure = false,
  });

  /// Days of the week in standard order (Monday = 0 .. Sunday = 6)
  static const List<String> daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Short day labels (Mon..Sun)
  static const List<String> shortDaysOfWeek = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Gets the day index (0 = Monday, 6 = Sunday)
  int get dayIndex => daysOfWeek.indexOf(dayOfWeek);

  /// Helper to convert 'HH:mm' string to total minutes from midnight
  int _toMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  /// Total start time in minutes from midnight
  int get startMinutes => _toMinutes(startTime);

  /// Total end time in minutes from midnight
  int get endMinutes => _toMinutes(endTime);

  /// Duration of the class in minutes
  int get durationInMinutes => endMinutes - startMinutes;

  /// Checks if start time is before end time
  bool get isValidTime => endMinutes > startMinutes;

  /// Constructs a DateTime on a given reference date with this class's start time
  DateTime startDateTime(DateTime referenceDate) {
    final parts = startTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
      hour,
      minute,
    );
  }

  /// Constructs a DateTime on a given reference date with this class's end time
  DateTime endDateTime(DateTime referenceDate) {
    final parts = endTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
      hour,
      minute,
    );
  }

  ClassItem copyWith({
    String? id,
    String? subject,
    int? subjectColorIndex,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    String? room,
    String? teacher,
    bool? isAiUnsure,
  }) {
    return ClassItem(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      subjectColorIndex: subjectColorIndex ?? this.subjectColorIndex,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      teacher: teacher ?? this.teacher,
      isAiUnsure: isAiUnsure ?? this.isAiUnsure,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'subjectColorIndex': subjectColorIndex,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'teacher': teacher,
      'isAiUnsure': isAiUnsure ? 1 : 0,
    };
  }

  factory ClassItem.fromMap(Map<String, dynamic> map) {
    return ClassItem(
      id: map['id'] as String,
      subject: map['subject'] as String,
      subjectColorIndex: (map['subjectColorIndex'] as num).toInt(),
      dayOfWeek: map['dayOfWeek'] as String,
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      room: map['room'] as String?,
      teacher: map['teacher'] as String?,
      isAiUnsure: (map['isAiUnsure'] as int? ?? 0) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          subject == other.subject &&
          subjectColorIndex == other.subjectColorIndex &&
          dayOfWeek == other.dayOfWeek &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          room == other.room &&
          teacher == other.teacher &&
          isAiUnsure == other.isAiUnsure;

  @override
  int get hashCode =>
      id.hashCode ^
      subject.hashCode ^
      subjectColorIndex.hashCode ^
      dayOfWeek.hashCode ^
      startTime.hashCode ^
      endTime.hashCode ^
      room.hashCode ^
      teacher.hashCode ^
      isAiUnsure.hashCode;

  @override
  String toString() {
    return 'ClassItem(id: $id, subject: $subject, day: $dayOfWeek, time: $startTime-$endTime, room: $room)';
  }
}
