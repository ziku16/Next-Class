import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/data/models/exam_item.dart';
import 'package:nextclass/domain/services/academic_schedule_service.dart';

void main() {
  group('AcademicScheduleService Exam Mode', () {
    final exams = [
      ExamItem(
        id: 'e1', scheduleId: 's1', subject: 'Algorithms',
        examDate: DateTime(2026, 11, 20), startTime: '09:00',
      ),
      ExamItem(
        id: 'e2', scheduleId: 's1', subject: 'Databases',
        examDate: DateTime(2026, 11, 23), startTime: '13:00',
      ),
    ];

    test('stays in normal mode before the first exam date', () {
      expect(AcademicScheduleService.isExamMode(exams, DateTime(2026, 11, 19)), isFalse);
    });

    test('includes both exam dates and exam-free dates between them', () {
      for (final date in [20, 21, 22, 23]) {
        expect(AcademicScheduleService.isExamMode(exams, DateTime(2026, 11, date)), isTrue);
      }
    });

    test('returns to normal mode the day after the final exam', () {
      expect(AcademicScheduleService.isExamMode(exams, DateTime(2026, 11, 24)), isFalse);
    });

    test('supports a single-day schedule and empty schedules', () {
      expect(AcademicScheduleService.isExamMode([exams.first], DateTime(2026, 11, 20)), isTrue);
      expect(AcademicScheduleService.isExamMode([], DateTime(2026, 11, 20)), isFalse);
    });
  });
}
