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
    if (quizzes.isEmpty) return const SizedBox.shrink();
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

        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: quizzes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              return _buildQuizCard(context, theme, ncColors, quiz);
            },
          ),
        ),
      ],
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
    final subjectColor = ncColors.getSubjectColor(
      quiz.subject.hashCode.abs() % 8,
    );

    final Color badgeBg;
    final Color badgeTextCol;

    switch (urgency) {
      case QuizUrgency.today:
        badgeBg = const Color(0xFFFF1744); // Vivid red
        badgeTextCol = Colors.white;
        break;
      case QuizUrgency.tomorrow:
        badgeBg = const Color(0xFFFFE500); // Safety yellow
        badgeTextCol = Colors.black;
        break;
      case QuizUrgency.thisWeek:
      case QuizUrgency.later:
        badgeBg = const Color(0xFF2979FF); // Bright blue
        badgeTextCol = Colors.white;
        break;
    }

    final formattedDue = DateFormat('E, d MMM').format(quiz.dueDate);

    return InkWell(
      onTap: onQuizTap != null ? () => onQuizTap!(quiz) : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 212,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(3.0, 3.0),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top row: Subject + Urgency Pill
            Row(
              children: [
                // Subject square indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: subjectColor,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(1),
                    border: Border.all(color: Colors.black, width: 1.0),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    quiz.subject,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Urgency Pill with brutalist border
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Text(
                    badgeText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w900,
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
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Bottom line: formatted due date
            Row(
              children: [
                const Icon(Icons.event, size: 14, color: Colors.black),
                const SizedBox(width: 4),
                Text(
                  formattedDue,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
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
