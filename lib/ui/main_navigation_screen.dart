import 'package:flutter/material.dart';
import '../data/models/class_item.dart';
import '../data/repositories/quiz_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/timetable_repository.dart';
import '../domain/services/notification_service.dart';
import '../state/quiz_provider.dart';
import 'home/today_screen.dart';
import 'quizzes/add_edit_quiz_sheet.dart';
import 'quizzes/quizzes_screen.dart';
import 'review/review_screen.dart';
import 'settings/settings_screen.dart';
import 'upload/upload_screen.dart';
import 'week/class_detail_sheet.dart';
import 'week/week_screen.dart';

/// Root interactive shell for NextClass hosting the 3 primary tabs:
/// 0: Today
/// 1: Week
/// 2: Quizzes
class MainNavigationScreen extends StatefulWidget {
  final int initialTab;
  final TimetableRepository? timetableRepository;
  final QuizRepository? quizRepository;
  final SettingsRepository? settingsRepository;

  const MainNavigationScreen({
    super.key,
    this.initialTab = 0,
    this.timetableRepository,
    this.quizRepository,
    this.settingsRepository,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late final TimetableRepository _timetableRepo;
  late final QuizRepository _quizRepo;
  late final SettingsRepository _settingsRepo;
  late final QuizProvider _quizProvider;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _timetableRepo = widget.timetableRepository ?? TimetableRepository();
    _quizRepo = widget.quizRepository ?? QuizRepository();
    _settingsRepo = widget.settingsRepository ?? SettingsRepository();
    _quizProvider = QuizProvider(
      quizRepository: _quizRepo,
      timetableRepository: _timetableRepo,
    );
    _quizProvider.loadData();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    try {
      await NotificationService().initialize();
    } catch (_) {}
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settingsRepository: _settingsRepo,
          onUploadTimetable: _openUpload,
          onEditTimetable: () async {
            final classes = await _timetableRepo.getAllClasses();
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReviewScreen(
                    initialClasses: classes,
                    onSaved: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _openUpload() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UploadScreen(
          onClassesExtracted: (classes) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ReviewScreen(
                  initialClasses: classes,
                  onSaved: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    setState(() {});
                  },
                ),
              ),
            );
          },
          onManualEdit: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ReviewScreen(
                  initialClasses: const [],
                  onSaved: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    setState(() {});
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openAddQuiz([ClassItem? classItem]) async {
    final classes = await _timetableRepo.getAllClasses();
    if (!mounted) return;

    await AddEditQuizSheet.show(
      context,
      preselectedClassId: classItem?.id,
      classes: classes,
      timetableRepository: _timetableRepo,
      quizProvider: _quizProvider,
      onUploadTimetable: _openUpload,
      onSaved: (_) => setState(() {}),
    );
  }

  void _openClassDetail(ClassItem item) {
    ClassDetailSheet.show(
      context,
      classItem: item,
      onAddQuiz: () => _openAddQuiz(item),
      onEditClass: () async {
        final classes = await _timetableRepo.getAllClasses();
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReviewScreen(
                initialClasses: classes,
                onSaved: () {
                  Navigator.of(context).pop();
                  setState(() {});
                },
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _currentIndex,
      children: [
        TodayScreen(
          key: const PageStorageKey('tab_today'),
          timetableRepository: _timetableRepo,
          quizRepository: _quizRepo,
          settingsRepository: _settingsRepo,
          quizProvider: _quizProvider,
          onNavigateToTab: _onTabSelected,
          onOpenSettings: _openSettings,
          onUploadTimetable: _openUpload,
          onAddQuiz: () => _openAddQuiz(),
          onClassTap: _openClassDetail,
        ),
        WeekScreen(
          key: const PageStorageKey('tab_week'),
          timetableRepository: _timetableRepo,
          onNavigateToTab: _onTabSelected,
          onOpenSettings: _openSettings,
          onUploadTimetable: _openUpload,
          onAddQuizForClass: (cls) => _openAddQuiz(cls),
        ),
        QuizzesScreen(
          key: const PageStorageKey('tab_quizzes'),
          quizProvider: _quizProvider,
          quizRepository: _quizRepo,
          timetableRepository: _timetableRepo,
          onNavigateToTab: _onTabSelected,
          onOpenSettings: _openSettings,
          onUploadTimetable: _openUpload,
        ),
      ],
    );
  }
}
