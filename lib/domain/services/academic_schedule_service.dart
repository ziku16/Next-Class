import '../../data/models/exam_item.dart';
import '../../data/models/exam_schedule.dart';
import '../../data/repositories/exam_repository.dart';

class AcademicScheduleState {
  final bool isExamMode;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<ExamItem> activeExams;
  final List<ExamItem> examsToday;

  const AcademicScheduleState({
    required this.isExamMode,
    required this.startDate,
    required this.endDate,
    required this.activeExams,
    required this.examsToday,
  });
}

class ExamPeriod {
  final DateTime startDate;
  final DateTime endDate;
  const ExamPeriod({required this.startDate, required this.endDate});

  bool contains(DateTime date) {
    final current = AcademicScheduleService.calendarDate(date);
    return !current.isBefore(startDate) && !current.isAfter(endDate);
  }
}

/// One authoritative calendar-date calculation shared by views and alarms.
class AcademicScheduleService {
  final ExamRepository _repository;

  AcademicScheduleService({ExamRepository? repository})
      : _repository = repository ?? ExamRepository();

  static DateTime calendarDate(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static bool isExamMode(List<ExamItem> exams, DateTime date) {
    return periodFor(exams)?.contains(date) ?? false;
  }

  static ExamPeriod? periodFor(List<ExamItem> exams) {
    if (exams.isEmpty) return null;
    final examDates = exams.map((e) => calendarDate(e.examDate)).toList()..sort();
    return ExamPeriod(startDate: examDates.first, endDate: examDates.last);
  }

  Future<(ExamSchedule?, List<ExamItem>)> loadActiveSchedule() async {
    final schedule = await _repository.getActiveSchedule();
    if (schedule == null) return (null, const []);
    return (schedule, await _repository.getExams(scheduleId: schedule.id));
  }

  Future<AcademicScheduleState> resolve(DateTime date) async {
    final (_, exams) = await loadActiveSchedule();
    final localDate = calendarDate(date);
    final relevant = exams.where((exam) => !calendarDate(exam.examDate).isBefore(localDate)).toList()
      ..sort(_compareExams);
    if (exams.isEmpty) {
      return const AcademicScheduleState(
        isExamMode: false, startDate: null, endDate: null,
        activeExams: [], examsToday: [],
      );
    }
    final period = periodFor(exams)!;
    return AcademicScheduleState(
      isExamMode: isExamMode(exams, localDate),
      startDate: period.startDate,
      endDate: period.endDate,
      activeExams: relevant,
      examsToday: exams.where((e) => calendarDate(e.examDate) == localDate).toList()
        ..sort(_compareExams),
    );
  }

  static int _compareExams(ExamItem a, ExamItem b) {
    final dateOrder = calendarDate(a.examDate).compareTo(calendarDate(b.examDate));
    if (dateOrder != 0) return dateOrder;
    final timeOrder = (a.startTime ?? '99:99').compareTo(b.startTime ?? '99:99');
    return timeOrder != 0 ? timeOrder : a.subject.compareTo(b.subject);
  }
}
