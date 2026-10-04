enum QuizUrgency {
  today,
  tomorrow,
  thisWeek,
  later,
}

/// Domain model representing an upcoming quiz or assessment.
class QuizItem {
  final String id;
  final String classId; // FK to ClassItem
  final String subject;
  final String title;
  final DateTime dueDate;
  final String? note;
  final bool isCompleted;

  const QuizItem({
    required this.id,
    required this.classId,
    required this.subject,
    required this.title,
    required this.dueDate,
    this.note,
    this.isCompleted = false,
  });

  /// Calculates number of calendar days between referenceDate and dueDate.
  int daysUntilDue(DateTime referenceDate) {
    final ref = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(ref).inDays;
  }

  /// True if quiz is due today
  bool isToday(DateTime referenceDate) => daysUntilDue(referenceDate) == 0;

  /// True if quiz is due tomorrow
  bool isTomorrow(DateTime referenceDate) => daysUntilDue(referenceDate) == 1;

  /// Determines the urgency group for grouping in the Quizzes list
  QuizUrgency urgencyCategory(DateTime referenceDate) {
    final diff = daysUntilDue(referenceDate);
    if (diff <= 0) return QuizUrgency.today;
    if (diff == 1) return QuizUrgency.tomorrow;
    if (diff <= 7) return QuizUrgency.thisWeek;
    return QuizUrgency.later;
  }

  /// Badge text displayed on quiz card (e.g., "Today", "Tomorrow", "5 days left")
  String urgencyBadgeText(DateTime referenceDate) {
    final diff = daysUntilDue(referenceDate);
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '$diff days left';
  }

  QuizItem copyWith({
    String? id,
    String? classId,
    String? subject,
    String? title,
    DateTime? dueDate,
    String? note,
    bool? isCompleted,
  }) {
    return QuizItem(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classId': classId,
      'subject': subject,
      'title': title,
      'dueDate': dueDate.toIso8601String(),
      'note': note,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory QuizItem.fromMap(Map<String, dynamic> map) {
    return QuizItem(
      id: map['id'] as String,
      classId: map['classId'] as String,
      subject: map['subject'] as String,
      title: map['title'] as String,
      dueDate: DateTime.parse(map['dueDate'] as String),
      note: map['note'] as String?,
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          classId == other.classId &&
          subject == other.subject &&
          title == other.title &&
          dueDate == other.dueDate &&
          note == other.note &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode =>
      id.hashCode ^
      classId.hashCode ^
      subject.hashCode ^
      title.hashCode ^
      dueDate.hashCode ^
      note.hashCode ^
      isCompleted.hashCode;

  @override
  String toString() {
    return 'QuizItem(id: $id, subject: $subject, title: $title, dueDate: $dueDate)';
  }
}
