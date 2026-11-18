import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/data/database/app_database.dart';
import 'package:nextclass/data/models/exam_item.dart';
import 'package:nextclass/data/models/exam_schedule.dart';
import 'package:nextclass/data/repositories/exam_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late ExamRepository repository;

  setUp(() async {
    database = await AppDatabase.createInMemory();
    repository = ExamRepository(dbManager: database);
  });

  tearDown(() async => database.close());

  ExamSchedule schedule(String id, {bool active = false}) => ExamSchedule(
        id: id,
        program: 'BSCS',
        semester: 'Semester 3',
        section: 'BCS-3',
        isActive: active,
        createdAt: DateTime(2026, 11, 19),
      );

  test('confirmed schedule and exams persist with one active selection', () async {
    final exam = ExamItem(
      id: 'exam-1', scheduleId: 'schedule-1', subject: 'Algorithms',
      examDate: DateTime(2026, 11, 23), startTime: '09:00', venue: 'Hall A',
    );
    await repository.saveConfirmedSchedule(schedule('schedule-1'), [exam]);
    await repository.saveConfirmedSchedule(schedule('schedule-2'), [
      exam.copyWith(id: 'exam-2', scheduleId: 'schedule-2'),
    ]);

    expect((await repository.getActiveSchedule())?.id, 'schedule-2');
    expect(await repository.getExams(), hasLength(1));
    expect((await repository.getExams()).single.venue, 'Hall A');
  });

  test('deleting an exam removes it without deleting its schedule', () async {
    final exam = ExamItem(
      id: 'exam-1', scheduleId: 'schedule-1', subject: 'Algorithms',
      examDate: DateTime(2026, 11, 23),
    );
    await repository.saveConfirmedSchedule(schedule('schedule-1', active: true), [exam]);

    await repository.deleteExam('exam-1');

    expect(await repository.getExams(), isEmpty);
    expect((await repository.getActiveSchedule())?.id, 'schedule-1');
  });
}
