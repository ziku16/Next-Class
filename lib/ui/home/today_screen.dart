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
import '../../state/quiz_provider.dart';
import '../shared/class_card.dart';
import '../shared/nc_banner.dart';
import '../shared/offline_banner.dart';
import 'app_bottom_nav.dart';
import 'quizzes_preview_row.dart';
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

  final DateTime? currentTime;
  final bool? isOffline;
  final bool? remindersEnabled;
  final List<ClassItem>? initialClasses;
  final List<QuizItem>? initialQuizzes;
  final UserSettings? initialSettings;
  final String userName;

  final ValueChanged<int>? onNavigateToTab;
  final VoidCallback? onAddQuiz;
  final VoidCallback? onUploadTimetable;
  final VoidCallback? onOpenSettings;
  final ValueChanged<ClassItem>? onClassTap;

  const TodayScreen({
    super.key,
    this.timetableRepository,
    this.quizRepository,
    this.settingsRepository,
    this.quizProvider,
    this.currentTime,
    this.isOffline,
    this.remindersEnabled,
    this.initialClasses,
    this.initialQuizzes,
    this.initialSettings,
    this.userName = '',
    this.onNavigateToTab,
    this.onAddQuiz,
    this.onUploadTimetable,
    this.onOpenSettings,
    this.onClassTap,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late final TimetableRepository _timetableRepo;
  late final QuizRepository _quizRepo;
  late final SettingsRepository _settingsRepo;

  late DateTime _now;
  Timer? _minuteTicker;
  StreamSubscription? _connectivitySubscription;

  bool _isLoading = true;
  bool _isOffline = false;
  bool _remindersEnabled = true;

  List<ClassItem> _allClasses = [];
  List<ClassItem> _todayClasses = [];
  List<QuizItem> _upcomingQuizzes = [];

  @override
  void initState() {
    super.initState();
    _timetableRepo = widget.timetableRepository ?? TimetableRepository();
    _quizRepo = widget.quizRepository ?? QuizRepository();
    _settingsRepo = widget.settingsRepository ?? SettingsRepository();

    _now = widget.currentTime ?? DateTime.now();
    _isOffline = widget.isOffline ?? false;
    _remindersEnabled = widget.remindersEnabled ?? true;

    if (widget.initialClasses != null) {
      _allClasses = widget.initialClasses!;
      _filterTodayClasses();
      _isLoading = false;
    }

    if (widget.quizProvider != null) {
      _upcomingQuizzes = widget.quizProvider!.quizzes;
      widget.quizProvider!.addListener(_onQuizProviderUpdated);
    } else if (widget.initialQuizzes != null) {
      _upcomingQuizzes = widget.initialQuizzes!;
    }

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

  void _onQuizProviderUpdated() {
    if (mounted && widget.quizProvider != null) {
      setState(() {
        _upcomingQuizzes = widget.quizProvider!.quizzes;
      });
    }
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
    if (widget.quizProvider != oldWidget.quizProvider) {
      oldWidget.quizProvider?.removeListener(_onQuizProviderUpdated);
      widget.quizProvider?.addListener(_onQuizProviderUpdated);
      if (widget.quizProvider != null) {
        _upcomingQuizzes = widget.quizProvider!.quizzes;
      }
    } else if (widget.initialQuizzes != oldWidget.initialQuizzes &&
        widget.initialQuizzes != null) {
      _upcomingQuizzes = widget.initialQuizzes!;
    }
  }

  @override
  void dispose() {
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
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen((results) {
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
      if (widget.initialClasses == null) {
        final classes = await _timetableRepo.getAllClasses();
        _allClasses = classes;
        _filterTodayClasses();
      }

      if (widget.quizProvider != null) {
        _upcomingQuizzes = widget.quizProvider!.quizzes;
      } else if (widget.initialQuizzes == null) {
        final quizzes =
            await _quizRepo.getUpcomingQuizzes(referenceDate: _now);
        _upcomingQuizzes = quizzes;
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
    final todayList =
        _allClasses.where((c) => c.dayOfWeek == currentDay).toList();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminders enabled (15 min before class).')),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTimetable = _allClasses.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF6EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        shape: const Border(bottom: BorderSide(color: Colors.black, width: 3.0)),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE500), // Safety yellow
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: Offset(2.5, 2.5),
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
              Icon(
                Icons.north_east_rounded,
                size: 16,
                color: Colors.black,
              ),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black, width: 2.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.settings,
                  color: Colors.black,
                  size: 20,
                ),
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
      ),
      floatingActionButton: AppBottomNav.buildFab(
        context: context,
        hasTimetable: hasTimetable,
        onPressed: () {
          if (!hasTimetable) {
            widget.onUploadTimetable?.call();
          } else {
            widget.onAddQuiz?.call();
          }
        },
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: NcBanner.permission(
                  onTurnOn: _turnOnReminders,
                ),
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
                          TodayHeader(
                            userName: widget.userName,
                            currentTime: _now,
                            classesToday: _todayClasses,
                            hasTimetable: hasTimetable,
                          ),
                          const SizedBox(height: 24),

                          // Feed Content: Classes or Empty/Weekend state
                          if (!hasTimetable)
                            _buildFirstLaunchEmptyState(context, theme)
                          else if (_todayClasses.isEmpty)
                            _buildWeekendNoClassesState(context, theme)
                          else
                            _buildTodayClassFeed(context, theme),

                          const SizedBox(height: 28),

                          // Upcoming Quizzes Preview
                          QuizzesPreviewRow(
                            quizzes: _upcomingQuizzes,
                            referenceDate: _now,
                            onSeeAll: () => widget.onNavigateToTab?.call(2),
                            onAddQuiz: widget.onAddQuiz,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
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
    final upcomingClasses =
        _todayClasses.where((c) => c.startMinutes > currentMinutes).toList();
    final nextClass = upcomingClasses.isNotEmpty ? upcomingClasses.first : null;

    // Find completed classes
    final completedClasses =
        _todayClasses.where((c) => c.endMinutes <= currentMinutes).toList();

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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Today',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.black,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: const Text(
                'OCT0221 / CLASSIFY',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: Colors.black,
                ),
              ),
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.black,
          width: 3.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
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
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a photo of your timetable to automatically extract every class and get reminded right on time.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
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
                side: const BorderSide(color: Colors.black, width: 2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty state for weekends or days without any scheduled classes.
  Widget _buildWeekendNoClassesState(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.black,
          width: 3.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
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
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Take a breather or get ahead on upcoming quizzes.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
