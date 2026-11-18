import 'package:flutter/foundation.dart';
import '../data/models/exam_item.dart';
import '../data/models/exam_schedule.dart';
import '../data/repositories/exam_repository.dart';
import '../domain/services/academic_schedule_service.dart';
import '../domain/services/notification_service.dart';

class ExamProvider extends ChangeNotifier {
  final ExamRepository _repository;
  List<ExamSchedule> _schedules = [];
  ExamSchedule? _activeSchedule;
  List<ExamItem> _activeExams = [];
  bool _isLoading = false;
  String? _errorMessage;

  ExamProvider({ExamRepository? repository})
      : _repository = repository ?? ExamRepository();

  List<ExamSchedule> get schedules => List.unmodifiable(_schedules);
  ExamSchedule? get activeSchedule => _activeSchedule;
  List<ExamItem> get activeExams => List.unmodifiable(_activeExams);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool isExamMode(DateTime date) =>
      AcademicScheduleService.isExamMode(_activeExams, date);
  List<ExamItem> examsForDate(DateTime date) {
    final target = AcademicScheduleService.calendarDate(date);
    return _activeExams
        .where((exam) => AcademicScheduleService.calendarDate(exam.examDate) == target)
        .toList()
      ..sort((a, b) => (a.startTime ?? '99:99').compareTo(b.startTime ?? '99:99'));
  }

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _schedules = await _repository.getSchedules();
      _activeSchedule = await _repository.getActiveSchedule();
      _activeExams = _activeSchedule == null
          ? []
          : await _repository.getExams(scheduleId: _activeSchedule!.id);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveConfirmedSchedule(
    ExamSchedule schedule,
    List<ExamItem> exams,
  ) async {
    await _repository.saveConfirmedSchedule(schedule, exams);
    await loadData();
    await NotificationService().rescheduleAll();
  }

  Future<void> activateSchedule(String id) async {
    await _repository.activateSchedule(id);
    await loadData();
    await NotificationService().rescheduleAll();
  }

  Future<void> saveManualExam(ExamItem exam) async {
    await _repository.saveExam(exam);
    await loadData();
    await NotificationService().rescheduleAll();
  }

  Future<void> deleteExam(String id) async {
    await _repository.deleteExam(id);
    await loadData();
    await NotificationService().rescheduleAll();
  }

  Future<void> deleteSchedule(String id) async {
    await _repository.deleteSchedule(id);
    await loadData();
    await NotificationService().rescheduleAll();
  }
}
