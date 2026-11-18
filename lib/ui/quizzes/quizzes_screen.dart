import 'package:flutter/material.dart';
import '../../core/theme/next_class_colors.dart';
import '../../data/models/class_item.dart';
import '../../data/models/quiz_item.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/repositories/timetable_repository.dart';
import '../../state/quiz_provider.dart';
import '../home/app_bottom_nav.dart';
import '../shared/nc_banner.dart';
import '../shared/offline_banner.dart';
import '../shared/undo_snackbar.dart';
import 'add_edit_quiz_sheet.dart';
import 'quiz_card.dart';

/// Full Quizzes Management Screen (Flow 6).
/// Features:
/// - Chronologically grouped sections: TODAY, TOMORROW, THIS WEEK, LATER
/// - Past quizzes filtered out from active view
/// - Extended FAB (+ Add quiz) styled with tertiaryContainer
/// - Timetable dependency guard warning banner when zero classes exist
/// - Empty state illustration & message
/// - Swipe-to-delete with 5-second floating Undo SnackBar
/// - 130% font scale accessibility adaptation
class QuizzesScreen extends StatefulWidget {
  final QuizProvider? quizProvider;
  final QuizRepository? quizRepository;
  final TimetableRepository? timetableRepository;

  final DateTime? referenceDate;
  final List<QuizItem>? initialQuizzes;
  final List<ClassItem>? initialClasses;

  final ValueChanged<int>? onNavigateToTab;
  final VoidCallback? onUploadTimetable;
  final VoidCallback? onAddQuiz;
  final VoidCallback? onAddExam;
  final VoidCallback? onOpenSettings;
  final bool? isOffline;

  const QuizzesScreen({
    super.key,
    this.quizProvider,
    this.quizRepository,
    this.timetableRepository,
    this.referenceDate,
    this.initialQuizzes,
    this.initialClasses,
    this.onNavigateToTab,
    this.onUploadTimetable,
    this.onAddQuiz,
    this.onAddExam,
    this.onOpenSettings,
    this.isOffline,
  });

  @override
  State<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends State<QuizzesScreen> {
  late final QuizProvider _provider;
  bool _ownsProvider = false;

  @override
  void initState() {
    super.initState();
    if (widget.quizProvider != null) {
      _provider = widget.quizProvider!;
    } else {
      _ownsProvider = true;
      _provider = QuizProvider(
        quizRepository: widget.quizRepository,
        timetableRepository: widget.timetableRepository,
        referenceDate: widget.referenceDate,
        initialQuizzes: widget.initialQuizzes,
        initialClasses: widget.initialClasses,
      );
      if (widget.initialQuizzes == null) {
        _provider.loadData();
      }
    }

    _provider.addListener(_onProviderUpdate);
  }

  @override
  void didUpdateWidget(covariant QuizzesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.referenceDate != oldWidget.referenceDate &&
        widget.referenceDate != null) {
      _provider.setReferenceDate(widget.referenceDate!);
    }
    if (widget.initialQuizzes != oldWidget.initialQuizzes &&
        widget.initialQuizzes != null) {
      _provider.setQuizzes(widget.initialQuizzes!);
    }
    if (widget.initialClasses != oldWidget.initialClasses &&
        widget.initialClasses != null) {
      _provider.setClasses(widget.initialClasses!);
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    if (_ownsProvider) {
      _provider.dispose();
    }
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openAddQuizSheet([ClassItem? preselectedClass]) async {
    await AddEditQuizSheet.show(
      context,
      preselectedClassId: preselectedClass?.id,
      classes: _provider.classes,
      quizProvider: _provider,
      onUploadTimetable: widget.onUploadTimetable,
    );
  }

  Future<void> _openEditQuizSheet(QuizItem quiz) async {
    await AddEditQuizSheet.show(
      context,
      initialQuiz: quiz,
      classes: _provider.classes,
      quizProvider: _provider,
      onUploadTimetable: widget.onUploadTimetable,
    );
  }

  void _handleDeleteQuiz(QuizItem quiz) {
    final title = quiz.title;
    _provider.deleteQuiz(quiz.id);

    UndoSnackBar.show(
      context,
      message: 'Deleted quiz: $title',
      onUndo: () => _provider.undoDelete(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nc = context.ncColors;
    final hasTimetable = _provider.hasTimetableClasses;
    final hasQuizzes = _provider.hasActiveQuizzes;
    final grouped = _provider.groupedQuizzes;

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
            color: const Color(0xFFFFE500),
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
          child: const Text(
            'Quizzes',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.5,
              color: Colors.black,
            ),
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
                  border: Border.all(color: nc.border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: nc.shadow,
                      offset: const Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Icon(Icons.settings, size: 20, color: nc.icon),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 2, // Quizzes
        onDestinationSelected: (index) {
          widget.onNavigateToTab?.call(index);
        },
        onAddQuiz: widget.onAddQuiz ?? () => _openAddQuizSheet(),
        onAddExam: widget.onAddExam,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Slim offline bar below status bar
            OfflineBanner(isOffline: widget.isOffline),

            // Timetable Guard Warning Banner if no classes exist
            if (!hasTimetable)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: NcBanner(
                  key: const Key('timetable_guard_banner'),
                  kind: NcBannerKind.warning,
                  title: 'Add your timetable first',
                  message:
                      "Quizzes belong to a class, and you haven't added any yet.",
                  actionLabel: 'Upload timetable',
                  onAction: widget.onUploadTimetable,
                ),
              ),

            // Main Content Area
            Expanded(
              child: _provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : !hasQuizzes
                      ? _buildEmptyState(context, theme, hasTimetable)
                      : RefreshIndicator(
                          onRefresh: () => _provider.loadData(),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                            children: [
                              // Top REVO Action: Create a Quiz
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black,
                                        offset: Offset(3.5, 3.5),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: FilledButton.icon(
                                      onPressed: () => _openAddQuizSheet(),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF5500),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          side: const BorderSide(color: Colors.black, width: 2.5),
                                        ),
                                      ),
                                      icon: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
                                      label: const Text(
                                        'Create a Quiz',
                                        style: TextStyle(
                                          fontFamily: 'SpaceGrotesk',
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          letterSpacing: 0.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Section Header: Your quizzes
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Your quizzes',
                                      style: TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                        color: nc.textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFE500),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: nc.border, width: 1.5),
                                      ),
                                      child: Text(
                                        '${_provider.activeQuizzes.length} UPCOMING',
                                        style: const TextStyle(
                                          fontFamily: 'SpaceGrotesk',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Group: TODAY
                              if (grouped[QuizUrgency.today]!.isNotEmpty)
                                _buildGroupSection(
                                  context: context,
                                  theme: theme,
                                  title: 'TODAY',
                                  quizzes: grouped[QuizUrgency.today]!,
                                  isUrgent: true,
                                ),

                              // Group: TOMORROW
                              if (grouped[QuizUrgency.tomorrow]!.isNotEmpty)
                                _buildGroupSection(
                                  context: context,
                                  theme: theme,
                                  title: 'TOMORROW',
                                  quizzes: grouped[QuizUrgency.tomorrow]!,
                                  isUrgent: true,
                                ),

                              // Group: THIS WEEK
                              if (grouped[QuizUrgency.thisWeek]!.isNotEmpty)
                                _buildGroupSection(
                                  context: context,
                                  theme: theme,
                                  title: 'THIS WEEK',
                                  quizzes: grouped[QuizUrgency.thisWeek]!,
                                  isUrgent: false,
                                ),

                              // Group: LATER
                              if (grouped[QuizUrgency.later]!.isNotEmpty)
                                _buildGroupSection(
                                  context: context,
                                  theme: theme,
                                  title: 'LATER',
                                  quizzes: grouped[QuizUrgency.later]!,
                                  isUrgent: false,
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

  Widget _buildGroupSection({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required List<QuizItem> quizzes,
    required bool isUrgent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brutalist Section Badge
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isUrgent ? const Color(0xFFFF5500) : const Color(0xFFDCE2E6),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isUrgent) ...[
                    const Icon(Icons.alarm_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      fontSize: 12,
                      color: isUrgent ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isUrgent ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Text(
                      '${quizzes.length}',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: isUrgent ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cards list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: quizzes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              return QuizCard(
                quiz: quiz,
                referenceDate: _provider.referenceDate,
                onTap: () => _openEditQuizSheet(quiz),
                onDelete: () => _handleDeleteQuiz(quiz),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
    bool hasTimetable,
  ) {
    final nc = context.ncColors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: nc.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: nc.border, width: 3),
            boxShadow: [
              BoxShadow(
                color: nc.shadow,
                offset: const Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE500),
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
                child: const Icon(
                  Icons.quiz_outlined,
                  size: 34,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No quizzes yet',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: nc.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "When your teacher announces one, add it here and we'll remind you the evening before.",
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: nc.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: nc.shadow,
                      offset: const Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: FilledButton.tonalIcon(
                  onPressed: () => _openAddQuizSheet(),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text(
                    'Add your first quiz',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5500),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: nc.border, width: 2.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
