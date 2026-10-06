import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/next_class_colors.dart';
import '../../data/models/quiz_item.dart';

/// Card component representing a single quiz item (Flow 6).
/// Features:
/// - 6 dp warm coral vertical stripe accent
/// - Urgent styling (alarm icon, quizUrgent badge) for today/tomorrow
/// - Neutral badge for later quizzes
/// - Formatted due date, subject title, and optional notes
/// - Dismissible swipe-to-delete with red background and explicit delete button
/// - Full 130% accessibility text scaling adaptation
class QuizCard extends StatelessWidget {
  final QuizItem quiz;
  final DateTime referenceDate;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool enableSwipeToDelete;

  const QuizCard({
    super.key,
    required this.quiz,
    required this.referenceDate,
    this.onTap,
    this.onDelete,
    this.enableSwipeToDelete = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ncColors = context.ncColors;

    final urgency = quiz.urgencyCategory(referenceDate);
    final isUrgent = urgency == QuizUrgency.today || urgency == QuizUrgency.tomorrow;

    // Left stripe color: warm coral or urgent coral
    final stripeColor = isUrgent ? ncColors.quizUrgent : ncColors.quiz;

    // Optional subject dot color derived from subject name hash
    final subjectColor =
        ncColors.getSubjectColor(quiz.subject.hashCode.abs() % 8);

    final cardWidget = Container(
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFFFFF8E1) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.black,
          width: 3.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(3.5, 3.5),
            blurRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 10 dp Left Accent Stripe with solid black divider
              Container(
                width: 10,
                decoration: BoxDecoration(
                  color: stripeColor,
                  border: const Border(
                    right: BorderSide(color: Colors.black, width: 2.5),
                  ),
                ),
              ),

              // Content Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Row: Subject + Urgency Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Subject dot and name
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: subjectColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              quiz.subject,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Urgency Badge
                          _buildUrgencyBadge(context, theme, ncColors, urgency),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Quiz Topic / Title (e.g. Unit 3, Ch. 4–5)
                      Text(
                        quiz.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Bottom Metadata: Date & optional note
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                DateFormat('EEE, d MMM').format(quiz.dueDate),
                                style: const TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                          if (quiz.note != null && quiz.note!.trim().isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.notes_rounded,
                                  size: 14,
                                  color: Colors.black,
                                ),
                                const SizedBox(width: 5),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 160),
                                  child: Text(
                                    quiz.note!,
                                    style: const TextStyle(
                                      fontFamily: 'SpaceGrotesk',
                                      color: Color(0xFF222222),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Trailing action: Delete icon button
              if (onDelete != null)
                Center(
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.black,
                    ),
                    tooltip: 'Delete quiz',
                    onPressed: onDelete,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (enableSwipeToDelete && onDelete != null) {
      return Dismissible(
        key: Key('quiz_card_${quiz.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFFF1744),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.black, width: 3.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        onDismissed: (_) => onDelete!(),
        child: cardWidget,
      );
    }

    return cardWidget;
  }

  Widget _buildUrgencyBadge(
    BuildContext context,
    ThemeData theme,
    NextClassColors ncColors,
    QuizUrgency urgency,
  ) {
    final Color bg;
    final Color fg;
    final IconData icon;
    final String label;

    switch (urgency) {
      case QuizUrgency.today:
        bg = const Color(0xFFFF1744); // Vivid red
        fg = Colors.white;
        icon = Icons.alarm_rounded;
        label = 'Today';
        break;
      case QuizUrgency.tomorrow:
        bg = const Color(0xFFFFE500); // Safety yellow
        fg = Colors.black;
        icon = Icons.alarm_rounded;
        label = 'Tomorrow';
        break;
      case QuizUrgency.thisWeek:
      case QuizUrgency.later:
        bg = const Color(0xFF2979FF); // Bright blue
        fg = Colors.white;
        icon = Icons.schedule_rounded;
        label = quiz.urgencyBadgeText(referenceDate);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(1.5, 1.5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
