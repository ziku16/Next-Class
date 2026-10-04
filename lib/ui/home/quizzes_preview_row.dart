import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/next_class_colors.dart';
import '../../data/models/quiz_item.dart';

/// Horizontal preview row of upcoming quizzes displayed on the Today screen.
class QuizzesPreviewRow extends StatelessWidget {
  final List<QuizItem> quizzes;
  final DateTime referenceDate;
  final VoidCallback? onSeeAll;
  final ValueChanged<QuizItem>? onQuizTap;
  final VoidCallback? onAddQuiz;

  const QuizzesPreviewRow({
    super.key,
    required this.quizzes,
    required this.referenceDate,
    this.onSeeAll,
    this.onQuizTap,
    this.onAddQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ncColors = context.ncColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.quiz_outlined,
                  size: 20,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Upcoming quizzes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  'See all',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Content: Horizontal List or Empty Card
        if (quizzes.isEmpty)
          _buildEmptyState(context, theme)
        else
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: quizzes.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final quiz = quizzes[index];
                return _buildQuizCard(context, theme, ncColors, quiz);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.task_alt_rounded,
              size: 22,
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No quizzes coming up.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add one when your teacher announces it.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onAddQuiz != null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Add quiz',
              color: theme.colorScheme.primary,
              onPressed: onAddQuiz,
            ),
        ],
      ),
    );
  }

  Widget _buildQuizCard(
    BuildContext context,
    ThemeData theme,
    NextClassColors ncColors,
    QuizItem quiz,
  ) {
    final urgency = quiz.urgencyCategory(referenceDate);
    final badgeText = quiz.urgencyBadgeText(referenceDate);
    final subjectColor =
        ncColors.getSubjectColor(quiz.subject.hashCode.abs() % 8);

    final Color badgeBg;
    final Color badgeTextCol;

    switch (urgency) {
      case QuizUrgency.today:
        badgeBg = theme.colorScheme.errorContainer;
        badgeTextCol = theme.colorScheme.onErrorContainer;
        break;
      case QuizUrgency.tomorrow:
        badgeBg = ncColors.warningContainer;
        badgeTextCol = ncColors.onWarningContainer;
        break;
      case QuizUrgency.thisWeek:
      case QuizUrgency.later:
        badgeBg = theme.colorScheme.secondaryContainer;
        badgeTextCol = theme.colorScheme.onSecondaryContainer;
        break;
    }

    final formattedDue = DateFormat('E, d MMM').format(quiz.dueDate);

    return InkWell(
      onTap: onQuizTap != null ? () => onQuizTap!(quiz) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top row: Subject + Urgency Pill
            Row(
              children: [
                // Subject dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: subjectColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    quiz.subject,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Urgency Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: badgeTextCol,
                    ),
                  ),
                ),
              ],
            ),

            // Title / Topic
            Text(
              quiz.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Bottom line: formatted due date
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  formattedDue,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
