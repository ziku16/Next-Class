/// One examination belonging to a saved examination schedule.
class ExamItem {
  final String id;
  final String scheduleId;
  final String subject;
  /// Local calendar date, stored without a timezone component.
  final DateTime examDate;
  final String? startTime;
  final String? endTime;
  final String? venue;
  final String? examType;
  final bool isAiUnsure;

  const ExamItem({
    required this.id,
    required this.scheduleId,
    required this.subject,
    required this.examDate,
    this.startTime,
    this.endTime,
    this.venue,
    this.examType,
    this.isAiUnsure = false,
  });

  DateTime get localDate => DateTime(examDate.year, examDate.month, examDate.day);

  String get dateKey =>
      '${examDate.year.toString().padLeft(4, '0')}-${examDate.month.toString().padLeft(2, '0')}-${examDate.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toMap() => {
        'id': id,
        'scheduleId': scheduleId,
        'subject': subject,
        'examDate': dateKey,
        'startTime': startTime,
        'endTime': endTime,
        'venue': venue,
        'examType': examType,
        'isAiUnsure': isAiUnsure ? 1 : 0,
      };

  factory ExamItem.fromMap(Map<String, Object?> map) => ExamItem(
        id: map['id'] as String,
        scheduleId: map['scheduleId'] as String,
        subject: map['subject'] as String,
        examDate: DateTime.parse(map['examDate'] as String),
        startTime: map['startTime'] as String?,
        endTime: map['endTime'] as String?,
        venue: map['venue'] as String?,
        examType: map['examType'] as String?,
        isAiUnsure: (map['isAiUnsure'] as int? ?? 0) == 1,
      );

  ExamItem copyWith({
    String? id,
    String? scheduleId,
    String? subject,
    DateTime? examDate,
    String? startTime,
    String? endTime,
    String? venue,
    String? examType,
    bool? isAiUnsure,
    bool clearStartTime = false,
    bool clearEndTime = false,
    bool clearVenue = false,
    bool clearExamType = false,
  }) =>
      ExamItem(
        id: id ?? this.id,
        scheduleId: scheduleId ?? this.scheduleId,
        subject: subject ?? this.subject,
        examDate: examDate ?? this.examDate,
        startTime: clearStartTime ? null : startTime ?? this.startTime,
        endTime: clearEndTime ? null : endTime ?? this.endTime,
        venue: clearVenue ? null : venue ?? this.venue,
        examType: clearExamType ? null : examType ?? this.examType,
        isAiUnsure: isAiUnsure ?? this.isAiUnsure,
      );
}
