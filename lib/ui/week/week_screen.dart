import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/class_item.dart';
import '../../data/repositories/timetable_repository.dart';
import '../home/app_bottom_nav.dart';
import '../review/edit_class_sheet.dart';
import '../shared/class_card.dart';
import '../shared/offline_banner.dart';
import 'class_detail_sheet.dart';
import 'day_selector_strip.dart';

/// Full Timetable Week View (Flow 5).
/// Features:
/// - Horizontal day selector strip with today highlight and auto-scroll
/// - Grouped day sections (Monday through Sunday) with dynamic counters
/// - Compact class cards with room and time
/// - Tapping opens ClassDetailSheet with Add Quiz deep link
/// - Fully responsive to 130% accessibility font scale
class WeekScreen extends StatefulWidget {
  final TimetableRepository? timetableRepository;
  final DateTime? referenceDate;
  final List<ClassItem>? initialClasses;
  final ValueChanged<int>? onNavigateToTab;
  final ValueChanged<ClassItem>? onAddQuizForClass;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onUploadTimetable;
  final bool? isOffline;

  const WeekScreen({
    super.key,
    this.timetableRepository,
    this.referenceDate,
    this.initialClasses,
    this.onNavigateToTab,
    this.onAddQuizForClass,
    this.onOpenSettings,
    this.onUploadTimetable,
    this.isOffline,
  });

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late final TimetableRepository _timetableRepo;
  late final ScrollController _scrollController;
  late final List<GlobalKey> _dayKeys;

  late DateTime _referenceDate;
  late List<DateTime> _weekDays;
  int _selectedDayIndex = 0;

  bool _isLoading = true;
  List<ClassItem> _allClasses = [];

  static const List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _timetableRepo = widget.timetableRepository ?? TimetableRepository();
    _scrollController = ScrollController();
    _dayKeys = List.generate(7, (_) => GlobalKey());

    _referenceDate = widget.referenceDate ?? DateTime.now();
    _computeWeekDays();

    // Default selected day is today's weekday index (0 = Mon, 6 = Sun)
    _selectedDayIndex = (_referenceDate.weekday - 1).clamp(0, 6);

    if (widget.initialClasses != null) {
      _allClasses = widget.initialClasses!;
      _isLoading = false;
    } else {
      _loadClasses();
    }
  }

  @override
  void didUpdateWidget(covariant WeekScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.referenceDate != oldWidget.referenceDate &&
        widget.referenceDate != null) {
      _referenceDate = widget.referenceDate!;
      _computeWeekDays();
    }
    if (widget.initialClasses != oldWidget.initialClasses &&
        widget.initialClasses != null) {
      _allClasses = widget.initialClasses!;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _computeWeekDays() {
    final monday = _referenceDate
        .subtract(Duration(days: _referenceDate.weekday - 1));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);
    _weekDays = List.generate(7, (i) => mondayStart.add(Duration(days: i)));
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await _timetableRepo.getAllClasses();
      if (mounted) {
        setState(() {
          _allClasses = classes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToDay(int dayIndex) {
    setState(() {
      _selectedDayIndex = dayIndex;
    });

    final targetKey = _dayKeys[dayIndex];
    final targetContext = targetKey.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    }
  }

  List<ClassItem> _classesForDay(String dayName) {
    final list = _allClasses.where((c) => c.dayOfWeek == dayName).toList();
    list.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return list;
  }

  void _openClassDetail(ClassItem item) {
    final today = DateTime.now();
    final isToday = item.dayOfWeek == DateFormat('EEEE').format(today);
    final currentMinutes = today.hour * 60 + today.minute;

    ClassCardState cardState = ClassCardState.defaultState;
    int? minutesUntilNext;

    if (isToday) {
      if (currentMinutes >= item.startMinutes &&
          currentMinutes < item.endMinutes) {
        cardState = ClassCardState.current;
      } else if (currentMinutes >= item.endMinutes) {
        cardState = ClassCardState.past;
      } else {
        cardState = ClassCardState.next;
        minutesUntilNext = item.startMinutes - currentMinutes;
      }
    }

    ClassDetailSheet.show(
      context,
      classItem: item,
      cardState: cardState,
      minutesUntilNext: minutesUntilNext,
      onAddQuiz: () {
        if (widget.onAddQuizForClass != null) {
          widget.onAddQuizForClass!(item);
        } else if (widget.onNavigateToTab != null) {
          widget.onNavigateToTab!(2); // Route to Quizzes tab
        }
      },
      onEditClass: () async {
        final updated = await EditClassSheet.show(
          context,
          initialClass: item,
        );
        if (updated != null) {
          await _timetableRepo.updateClass(updated);
          _loadClasses();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTimetable = _allClasses.isNotEmpty;

    final selectedDate = _weekDays[_selectedDayIndex];
    final dayNumStr = DateFormat('dd').format(selectedDate);
    final dayNameStr = DateFormat('EEE').format(selectedDate).toUpperCase();
    final monthStr = DateFormat('MMMM').format(selectedDate).toUpperCase();
    final yearStr = selectedDate.year.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF6EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: Colors.black, width: 3.0)),
        title: Text(
          'Week',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
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
        currentIndex: 1, // Week
        onDestinationSelected: (idx) {
          if (widget.onNavigateToTab != null) {
            widget.onNavigateToTab!(idx);
          }
        },
      ),
      floatingActionButton: AppBottomNav.buildFab(
        context: context,
        hasTimetable: hasTimetable,
        onPressed: () {
          if (!hasTimetable) {
            widget.onUploadTimetable?.call();
          } else if (widget.onNavigateToTab != null) {
            widget.onNavigateToTab!(2); // Route to Quizzes
          }
        },
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Slim offline bar below status bar
            OfflineBanner(isOffline: widget.isOffline),

            // Reference Image Massive Date Header: [ 06 MON ] OCTOBER 2026
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dayNumStr,
                          style: const TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          dayNameStr,
                          style: const TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        monthStr,
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Colors.black,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        yearStr,
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Colors.black,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Horizontal Day Selector Strip
            DaySelectorStrip(
              referenceDate: _referenceDate,
              selectedDayIndex: _selectedDayIndex,
              onDaySelected: _scrollToDay,
            ),
            const Divider(height: 2, thickness: 2, color: Colors.black),

            // Grouped Day Stream
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        final dayName = _dayNames[index];
                        final dayDate = _weekDays[index];
                        final classes = _classesForDay(dayName);

                        return _buildDaySection(
                          context: context,
                          theme: theme,
                          index: index,
                          dayName: dayName,
                          dayDate: dayDate,
                          classes: classes,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySection({
    required BuildContext context,
    required ThemeData theme,
    required int index,
    required String dayName,
    required DateTime dayDate,
    required List<ClassItem> classes,
  }) {
    final today = DateTime.now();
    final isToday = dayDate.year == today.year &&
        dayDate.month == today.month &&
        dayDate.day == today.day;

    final dayNum = dayDate.day.toString();
    final monthShort = DateFormat('MMM').format(dayDate);

    final String countLabel;
    if (classes.isEmpty) {
      countLabel = 'free';
    } else if (classes.length == 1) {
      countLabel = '1 class';
    } else {
      countLabel = '${classes.length} classes';
    }

    final headerText = '$dayName $dayNum $monthShort · $countLabel';

    return Container(
      key: _dayKeys[index],
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row
          Row(
            children: [
              Expanded(
                child: Text(
                  headerText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE500),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black, width: 2.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Cards or Empty Day State
          if (classes.isEmpty)
            _buildEmptyDayState(context, theme, dayName)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: classes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, cIndex) {
                final classItem = classes[cIndex];
                final currentMinutes = today.hour * 60 + today.minute;

                ClassCardState state = ClassCardState.compact;
                if (isToday && currentMinutes >= classItem.endMinutes) {
                  state = ClassCardState.past;
                }

                return ClassCard(
                  classItem: classItem,
                  state: state,
                  onTap: () => _openClassDetail(classItem),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayState(
    BuildContext context,
    ThemeData theme,
    String dayName,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.black,
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.weekend,
            size: 20,
            color: Colors.black,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No classes scheduled for $dayName',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
