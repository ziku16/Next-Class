import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/class_item.dart';
import '../../data/models/quiz_item.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/timetable_repository.dart';
import '../../domain/services/academic_schedule_service.dart';
import '../../state/quiz_provider.dart';
import '../../state/exam_provider.dart';
import '../../data/models/exam_item.dart';
import '../shared/class_card.dart';
import 'quizzes_preview_row.dart';
import '../shared/nc_banner.dart';
import '../shared/offline_banner.dart';
import '../shared/undo_snackbar.dart';
import '../../core/theme/next_class_colors.dart';
import 'app_bottom_nav.dart';
import 'today_header.dart';

/// The primary daily view for NextClass (Flow 4).
/// Displays:
/// - Real-time greeting and dynamic agenda summary
/// - Offline and Reminders warning banners
/// - Active, upcoming, and completed class feed
/// - Upcoming quizzes preview carousel
/// - Weekend, empty, and first-launch states
class TodayScreen extends StatefulWidget {
  final TimetableRepository? timetableRepository;
  final QuizRepository? quizRepository;
  final SettingsRepository? settingsRepository;
  final QuizProvider? quizProvider;
  final ExamProvider? examProvider;

  final DateTime? currentTime;
  final bool? isOffline;
  final bool? remindersEnabled;
  final List<ClassItem>? initialClasses;
  final List<QuizItem>? initialQuizzes;
  final UserSettings? initialSettings;
  final String userName;

  final ValueChanged<int>? onNavigateToTab;
  final VoidCallback? onAddQuiz;
  final VoidCallback? onAddExam;
  final VoidCallback? onUploadTimetable;
  final VoidCallback? onOpenSettings;
  final ValueChanged<ClassItem>? onClassTap;

  const TodayScreen({
    super.key,
    this.timetableRepository,
    this.quizRepository,
    this.settingsRepository,
    this.quizProvider,
    this.examProvider,
    this.currentTime,
    this.isOffline,
    this.remindersEnabled,
    this.initialClasses,
    this.initialQuizzes,
    this.initialSettings,
    this.userName = '',
    this.onNavigateToTab,
    this.onAddQuiz,
    this.onAddExam,
    this.onUploadTimetable,
    this.onOpenSettings,
    this.onClassTap,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late final TimetableRepository _timetableRepo;
  late final SettingsRepository _settingsRepo;

  late DateTime _now;
  Timer? _minuteTicker;
  StreamSubscription? _connectivitySubscription;

  bool _isLoading = true;
  bool _isOffline = false;
  bool _remindersEnabled = true;

  List<ClassItem> _allClasses = [];
  List<ClassItem> _todayClasses = [];

  @override
  void initState() {
    super.initState();
    _timetableRepo = widget.timetableRepository ?? TimetableRepository();
    _settingsRepo = widget.settingsRepository ?? SettingsRepository();

    _now = widget.currentTime ?? DateTime.now();
    _isOffline = widget.isOffline ?? false;
    _remindersEnabled = widget.remindersEnabled ?? true;

    if (widget.initialClasses != null) {
      _allClasses = widget.initialClasses!;
      _filterTodayClasses();
      _isLoading = false;
    }
    widget.examProvider?.addListener(_onExamProviderUpdated);
    widget.quizProvider?.addListener(_onQuizProviderUpdated);
    if (widget.currentTime != null) widget.quizProvider?.setReferenceDate(_now);

    if (widget.currentTime == null) {
      // Re-evaluate every minute for live progress and active class status
      _minuteTicker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) {
          setState(() {
            _now = DateTime.now();
            _filterTodayClasses();
          });
        }
      });
    }

    _loadData();
    _initConnectivity();
  }

  void _onExamProviderUpdated() {
    if (mounted) setState(() {});
  }

  void _onQuizProviderUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentTime != oldWidget.currentTime &&
        widget.currentTime != null) {
      _now = widget.currentTime!;
      _filterTodayClasses();
    }
    if (widget.isOffline != oldWidget.isOffline && widget.isOffline != null) {
      _isOffline = widget.isOffline!;
    }
    if (widget.remindersEnabled != oldWidget.remindersEnabled &&
        widget.remindersEnabled != null) {
      _remindersEnabled = widget.remindersEnabled!;
    }
    if (widget.initialClasses != oldWidget.initialClasses &&
        widget.initialClasses != null) {
      _allClasses = widget.initialClasses!;
      _filterTodayClasses();
    }
    if (widget.examProvider != oldWidget.examProvider) {
      oldWidget.examProvider?.removeListener(_onExamProviderUpdated);
      widget.examProvider?.addListener(_onExamProviderUpdated);
    }
    if (widget.quizProvider != oldWidget.quizProvider) {
      oldWidget.quizProvider?.removeListener(_onQuizProviderUpdated);
      widget.quizProvider?.addListener(_onQuizProviderUpdated);
    }
  }

  @override
  void dispose() {
    widget.examProvider?.removeListener(_onExamProviderUpdated);
    widget.quizProvider?.removeListener(_onQuizProviderUpdated);
    _minuteTicker?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    if (widget.isOffline != null) return;
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (mounted) {
        setState(() {
          _isOffline = connectivityResult.contains(ConnectivityResult.none);
        });
      }
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
        results,
      ) {
        if (mounted) {
          setState(() {
            _isOffline = results.contains(ConnectivityResult.none);
          });
        }
      });
    } catch (_) {
      // Platform or emulator without connectivity plugin
    }
  }

  Future<void> _loadData() async {
    try {
      await widget.examProvider?.loadData();
      if (widget.initialClasses == null) {
        final classes = await _timetableRepo.getAllClasses();
        _allClasses = classes;
        _filterTodayClasses();
      }

      if (widget.remindersEnabled == null) {
        final settings = await _settingsRepo.getUserSettings();
        _remindersEnabled = settings.classReminderMinutes != null;
      }
    } catch (_) {
      // Fallback
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterTodayClasses() {
    final currentDay = DateFormat('EEEE').format(_now);
    final todayList = _allClasses
        .where((c) => c.dayOfWeek == currentDay)
        .toList();
    todayList.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    _todayClasses = todayList;
  }

  Future<void> _turnOnReminders() async {
    try {
      final settings = await _settingsRepo.getUserSettings();
      await _settingsRepo.updateUserSettings(
        settings.copyWith(classReminderMinutes: 15),
      );
      if (mounted) {
        setState(() {
          _remindersEnabled = true;
        });
        UndoSnackBar.showSuccess(
          context,
          message: 'Reminders enabled (15 min before class).',
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nc = context.ncColors;
    final hasTimetable = _allClasses.isNotEmpty;
    final examMode = widget.examProvider?.isExamMode(_now) ?? false;
    final examsToday =
        widget.examProvider?.examsForDate(_now) ?? const <ExamItem>[];

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: nc.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        shape: Border(bottom: BorderSide(color: nc.border, width: 3.0)),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE500), // Safety yellow
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: nc.border, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: nc.shadow,
                offset: const Offset(2.5, 2.5),
                blurRadius: 0,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NextClass',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.black,
                  height: 1.0,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.north_east_rounded, size: 16, color: Colors.black),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: widget.onOpenSettings,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: nc.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: nc.border, width: 2.0),
                  boxShadow: [
                    BoxShadow(
                      color: nc.shadow,
                      offset: const Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Icon(Icons.settings, color: nc.icon, size: 20),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0, // Today
        onDestinationSelected: (index) {
          if (widget.onNavigateToTab != null) {
            widget.onNavigateToTab!(index);
          }
        },
        onAddQuiz: widget.onAddQuiz,
        onAddExam: widget.onAddExam,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Slim offline bar docked below status bar
            OfflineBanner(
              isOffline: _isOffline,
              onRetry: () => _initConnectivity(),
            ),

            // Reminders disabled banner
            if (!_remindersEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: NcBanner.permission(onTurnOn: _turnOnReminders),
              ),

            // Main Scrollable Feed
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        children: [
                          // Header (Greeting, Date, Schedule Pill)
                          if (examMode)
                            _examModeBanner(context)
                          else
                            TodayHeader(
                              userName: widget.userName,
                              currentTime: _now,
                              classesToday: _todayClasses,
                              hasTimetable: hasTimetable,
                            ),
                          const SizedBox(height: 24),

                          if (examMode)
                            _buildExamsToday(context, theme, examsToday)
                          // Feed Content: Classes or Empty/Weekend state
                          else if (!hasTimetable)
                            _buildFirstLaunchEmptyState(context, theme)
                          else if (_todayClasses.isEmpty)
                            _buildWeekendNoClassesState(context, theme)
                          else
                            _buildTodayClassFeed(context, theme),

                          if (!examMode &&
                              widget.examProvider != null &&
                              widget.examProvider!.activeExams.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildNextExamPreview(context),
                          ],
                          if (!examMode) ...[
                            const SizedBox(height: 20),
                            QuizzesPreviewRow(
                              quizzes: _upcomingQuizzes.take(2).toList(),
                              referenceDate: _now,
                              onSeeAll: widget.onNavigateToTab == null
                                  ? null
                                  : () => widget.onNavigateToTab!(2),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<QuizItem> get _upcomingQuizzes {
    final quizzes =
        widget.initialQuizzes ??
        widget.quizProvider?.quizzes ??
        const <QuizItem>[];
    final today = DateTime(_now.year, _now.month, _now.day);
    return quizzes.where((quiz) {
      final dueDate = DateTime(
        quiz.dueDate.year,
        quiz.dueDate.month,
        quiz.dueDate.day,
      );
      return !quiz.isCompleted && !dueDate.isBefore(today);
    }).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  Widget _examModeBanner(BuildContext context) {
    final nc = context.ncColors;
    return Container(
      key: const Key('exam_mode_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE500),
        border: Border.all(color: nc.border, width: 2.5),
        boxShadow: [BoxShadow(color: nc.shadow, offset: const Offset(3, 3))],
      ),
      child: const Row(
        children: [
          Icon(Icons.edit_calendar_rounded),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'EXAM MODE',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamsToday(
    BuildContext context,
    ThemeData theme,
    List<ExamItem> exams,
  ) {
    final nc = context.ncColors;
    if (exams.isEmpty) {
      return Container(
        key: const Key('exam_free_day_state'),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: nc.surface,
          border: Border.all(color: nc.border, width: 2.5),
          boxShadow: [BoxShadow(color: nc.shadow, offset: const Offset(3, 3))],
        ),
        child: const Column(
          children: [
            Icon(Icons.event_available_rounded, size: 36),
            SizedBox(height: 10),
            Text(
              'No exam scheduled today',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            SizedBox(height: 4),
            Text(
              'Your regular classes are paused during Exam Mode.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TODAY’S EXAMS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: nc.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...exams.map(
          (exam) => Container(
            key: Key('today_exam_${exam.id}'),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: nc.surface,
              border: Border.all(color: nc.border, width: 2.5),
              boxShadow: [
                BoxShadow(color: nc.shadow, offset: const Offset(3, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.subject,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (exam.startTime != null)
                      '${exam.startTime}${exam.endTime == null ? '' : '–${exam.endTime}'}',
                    if (exam.venue != null) exam.venue!,
                    if (exam.examType != null) exam.examType!,
                  ].join(' · '),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNextExamPreview(BuildContext context) {
    final nc = context.ncColors;
    final futureExams =
        widget.examProvider!.activeExams
            .where(
              (exam) =>
                  !AcademicScheduleService.calendarDate(exam.examDate)
                      .isBefore(AcademicScheduleService.calendarDate(_now)),
            )
            .toList()
          ..sort((a, b) => a.localDate.compareTo(b.localDate));
    if (futureExams.isEmpty) return const SizedBox.shrink();
    final exam = futureExams.first;
    return Semantics(
      button: true,
      child: InkWell(
        key: const Key('next_exam_preview'),
        onTap: widget.onAddExam,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: nc.surface,
            border: Border.all(color: nc.border, width: 2),
            boxShadow: [
              BoxShadow(color: nc.shadow, offset: const Offset(2, 2)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.event_note_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Next exam · ${exam.subject} · ${DateFormat('d MMM').format(exam.examDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the classes list with in-progress class at the top, followed by upcoming and completed.
  Widget _buildTodayClassFeed(BuildContext context, ThemeData theme) {
    final currentMinutes = _now.hour * 60 + _now.minute;

    // Find active class
    final activeClass = _todayClasses.cast<ClassItem?>().firstWhere(
      (c) => currentMinutes >= c!.startMinutes && currentMinutes < c.endMinutes,
      orElse: () => null,
    );

    // Find upcoming classes
    final upcomingClasses = _todayClasses
        .where((c) => c.startMinutes > currentMinutes)
        .toList();
    final nextClass = upcomingClasses.isNotEmpty ? upcomingClasses.first : null;

    // Find completed classes
    final completedClasses = _todayClasses
        .where((c) => c.endMinutes <= currentMinutes)
        .toList();

    // Order: Active class at top, followed by upcoming, followed by completed
    final orderedFeed = <ClassItem>[];
    if (activeClass != null) {
      orderedFeed.add(activeClass);
      for (final c in upcomingClasses) {
        orderedFeed.add(c);
      }
      for (final c in completedClasses) {
        orderedFeed.add(c);
      }
    } else {
      orderedFeed.addAll(_todayClasses);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Classes',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: context.ncColors.textPrimary,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orderedFeed.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final classItem = orderedFeed[index];
            final ClassCardState cardState;
            int? minutesUntilNext;

            if (currentMinutes >= classItem.startMinutes &&
                currentMinutes < classItem.endMinutes) {
              cardState = ClassCardState.current;
            } else if (currentMinutes >= classItem.endMinutes) {
              cardState = ClassCardState.past;
            } else if (classItem == nextClass) {
              cardState = ClassCardState.next;
              minutesUntilNext = classItem.startMinutes - currentMinutes;
            } else {
              cardState = ClassCardState.defaultState;
            }

            return ClassCard(
              classItem: classItem,
              state: cardState,
              minutesUntilNext: minutesUntilNext,
              onTap: widget.onClassTap != null
                  ? () => widget.onClassTap!(classItem)
                  : null,
            );
          },
        ),
      ],
    );
  }

  /// Empty state for first launch when no timetable has been created yet.
  Widget _buildFirstLaunchEmptyState(BuildContext context, ThemeData theme) {
    final nc = context.ncColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: nc.border, width: 3.0),
        boxShadow: [
          BoxShadow(
            color: nc.shadow,
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE500),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black, width: 2.5),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 36,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.userName.trim().isEmpty
                ? 'Welcome. Nothing scheduled yet.'
                : 'Welcome, ${widget.userName}. Nothing scheduled yet.',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: nc.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a photo of your timetable to automatically extract every class and get reminded right on time.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: nc.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: widget.onUploadTimetable,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload timetable'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(color: nc.border, width: 2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty state for weekends or days without any scheduled classes.
  Widget _buildWeekendNoClassesState(BuildContext context, ThemeData theme) {
    final nc = context.ncColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: nc.border, width: 3.0),
        boxShadow: [
          BoxShadow(
            color: nc.shadow,
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE500),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black, width: 2.5),
            ),
            child: const Icon(
              Icons.weekend_rounded,
              size: 36,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No classes today. Enjoy the break!',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: nc.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Take a breather or get ahead on upcoming quizzes.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: nc.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
