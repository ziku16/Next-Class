/// Student identity and active-selection metadata for an imported exam sheet.
class ExamSchedule {
  final String id;
  final String program;
  final String semester;
  final String section;
  final bool isActive;
  final DateTime createdAt;

  const ExamSchedule({
    required this.id,
    required this.program,
    required this.semester,
    required this.section,
    this.isActive = false,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'program': program,
        'semester': semester,
        'section': section,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ExamSchedule.fromMap(Map<String, Object?> map) => ExamSchedule(
        id: map['id'] as String,
        program: map['program'] as String,
        semester: map['semester'] as String,
        section: map['section'] as String,
        isActive: (map['isActive'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  ExamSchedule copyWith({bool? isActive}) => ExamSchedule(
        id: id,
        program: program,
        semester: semester,
        section: section,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}
