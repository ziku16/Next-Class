import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/class_item.dart';
import '../data/repositories/quiz_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/timetable_repository.dart';
import '../data/repositories/exam_repository.dart';
import '../domain/services/notification_service.dart';
import '../state/quiz_provider.dart';
import '../state/exam_provider.dart';
import 'exams/exam_management_screen.dart';
import 'home/today_screen.dart';
import 'quizzes/add_edit_quiz_sheet.dart';
import 'quizzes/quizzes_screen.dart';
import 'review/review_screen.dart';
import 'settings/settings_screen.dart';
import 'upload/upload_screen.dart';
import 'shared/fluid_page_route.dart';
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

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  late final TimetableRepository _timetableRepo;
  late final QuizRepository _quizRepo;
  late final SettingsRepository _settingsRepo;
  late final QuizProvider _quizProvider;
  late final ExamProvider _examProvider;
  Timer? _dateWatcher;
  DateTime _lastObservedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _timetableRepo = widget.timetableRepository ?? TimetableRepository();
    _quizRepo = widget.quizRepository ?? QuizRepository();
    _settingsRepo = widget.settingsRepository ?? SettingsRepository();
    _examProvider = ExamProvider(repository: ExamRepository());
    WidgetsBinding.instance.addObserver(this);
    _examProvider.loadData();
    _quizProvider = QuizProvider(
      quizRepository: _quizRepo,
      timetableRepository: _timetableRepo,
    );
    _quizProvider.loadData();
    _initNotifications();
    _dateWatcher = Timer.periodic(const Duration(minutes: 1), (_) => _refreshOnDateChange());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAcademicState();
  }

  Future<void> _refreshOnDateChange() async {
    final today = DateTime.now();
    if (today.year != _lastObservedDate.year ||
        today.month != _lastObservedDate.month ||
        today.day != _lastObservedDate.day) {
      _lastObservedDate = today;
      await _refreshAcademicState();
    }
  }

  Future<void> _refreshAcademicState() async {
    await _examProvider.loadData();
    await NotificationService().rescheduleAll();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateWatcher?.cancel();
    _examProvider.dispose();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);

      await NotificationService().initialize();
      await NotificationService().requestPermissions();
      await NotificationService().rescheduleAll();
    } catch (_) {}
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      FluidPageRoute(
        builder: (_) => SettingsScreen(
          settingsRepository: _settingsRepo,
          onUploadTimetable: _openUpload,
          onEditTimetable: () async {
            final classes = await _timetableRepo.getAllClasses();
            if (mounted) {
              Navigator.of(context).push(
                FluidPageRoute(
                  builder: (_) => ReviewScreen(
                    initialClasses: classes,
                    onSaved: () async {
                      try {
                        await NotificationService().rescheduleAll();
                      } catch (_) {}
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      setState(() {});
                    },
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
      FluidPageRoute(
        builder: (_) => UploadScreen(
          onClassesExtracted: (classes) {
            Navigator.of(context).pushReplacement(
              FluidPageRoute(
                builder: (_) => ReviewScreen(
                  initialClasses: classes,
                  onSaved: () async {
                    try {
                      await NotificationService().rescheduleAll();
                    } catch (_) {}
                    if (!mounted) return;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    setState(() {});
                  },
                ),
              ),
            );
          },
          onManualEdit: () {
            Navigator.of(context).pushReplacement(
              FluidPageRoute(
                builder: (_) => ReviewScreen(
                  initialClasses: const [],
                  onSaved: () async {
                    try {
                      await NotificationService().rescheduleAll();
                    } catch (_) {}
                    if (!mounted) return;
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

  Future<void> _openExamManagement() async {
    await Navigator.of(context).push(
      FluidPageRoute(
        builder: (_) => ExamManagementScreen(
          provider: _examProvider,
          onScheduleChanged: _refreshAcademicState,
        ),
      ),
    );
    await _refreshAcademicState();
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
            FluidPageRoute(
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

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return TodayScreen(
          key: const PageStorageKey('tab_today'),
          timetableRepository: _timetableRepo,
          quizRepository: _quizRepo,
          settingsRepository: _settingsRepo,
          quizProvider: _quizProvider,
          examProvider: _examProvider,
          onNavigateToTab: _onTabSelected,
          onOpenSettings: _openSettings,
          onUploadTimetable: _openUpload,
          onAddQuiz: () => _openAddQuiz(),
          onAddExam: _openExamManagement,
          onClassTap: _openClassDetail,
        );
      case 1:
        return WeekScreen(
          key: const PageStorageKey('tab_week'),
          timetableRepository: _timetableRepo,
          examProvider: _examProvider,
          onNavigateToTab: _onTabSelected,
          onOpenSettings: _openSettings,
          onUploadTimetable: _openUpload,
          onAddQuizForClass: (cls) => _openAddQuiz(cls),
          onAddQuiz: () => _openAddQuiz(),
          onAddExam: _openExamManagement,
        );
      case 2:
      default:
        return QuizzesScreen(
          key: const PageStorageKey('tab_quizzes'),
          quizProvider: _quizProvider,
          quizRepository: _quizRepo,
          timetableRepository: _timetableRepo,
          onNavigateToTab: _onTabSelected,
          onOpenSettings: _openSettings,
          onUploadTimetable: _openUpload,
          onAddQuiz: () => _openAddQuiz(),
          onAddExam: _openExamManagement,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 240),
      switchInCurve: Curves.fastOutSlowIn,
      switchOutCurve: Curves.fastOutSlowIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.03),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.fastOutSlowIn,
          reverseCurve: Curves.fastOutSlowIn,
        ));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_currentIndex),
        child: _buildCurrentTab(),
      ),
    );
  }
}
