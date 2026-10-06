import 'package:flutter/material.dart';
import '../../core/theme/next_class_colors.dart';
import '../../data/models/class_item.dart';
import 'live_progress_bar.dart';

enum ClassCardState {
  defaultState,
  current,
  next,
  past,
  compact,
  editable,
}

/// The core class card component across Today, Week, and Review views.
/// Responds cleanly to 130% font scale, wraps subject titles without truncating,
/// and enforces tabular figures on time strings.
class ClassCard extends StatelessWidget {
  final ClassItem classItem;
  final ClassCardState state;
  final int? minutesUntilNext;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool enableSwipeToDelete;

  const ClassCard({
    super.key,
    required this.classItem,
    this.state = ClassCardState.defaultState,
    this.minutesUntilNext,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.enableSwipeToDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ncColors = context.ncColors;
    final subjectColor = ncColors.getSubjectColor(classItem.subjectColorIndex);

    Widget cardWidget;
    if (state == ClassCardState.compact) {
      cardWidget = _buildCompactCard(context, theme, ncColors, subjectColor);
    } else {
      cardWidget = _buildStandardCard(context, theme, ncColors, subjectColor);
    }

    if (enableSwipeToDelete && onDelete != null) {
      return Dismissible(
        key: Key('class_card_${classItem.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.error,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: theme.colorScheme.onError, size: 24),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onError,
                  fontWeight: FontWeight.w700,
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

  /// Compact 1-line card representation for Week view
  Widget _buildCompactCard(
    BuildContext context,
    ThemeData theme,
    NextClassColors ncColors,
    Color subjectColor,
  ) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // 8 dp Subject color stripe with black divider
                  Container(
                    width: 8,
                    decoration: BoxDecoration(
                      color: subjectColor,
                      border: const Border(
                        right: BorderSide(color: Colors.black, width: 2.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            classItem.subject,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${classItem.startTime} – ${classItem.endTime}${classItem.room != null ? ' · ${classItem.room}' : ''}',
                            style: const TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (state == ClassCardState.past) ...[
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(
                        Icons.check_circle,
                        size: 20,
                        color: Colors.black,
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Standard card representation for Today, Review, and Detail streams
  Widget _buildStandardCard(
    BuildContext context,
    ThemeData theme,
    NextClassColors ncColors,
    Color subjectColor,
  ) {
    final Color cardBg;
    switch (state) {
      case ClassCardState.current:
        cardBg = const Color(0xFFFFF9C4); // Pale safety yellow tint
        break;
      case ClassCardState.next:
        cardBg = const Color(0xFFFFE0B2); // Pale vivid orange tint
        break;
      case ClassCardState.past:
        cardBg = const Color(0xFFECEFF1); // Muted ticket grey
        break;
      default:
        cardBg = Colors.white;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 3.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(3.5, 3.5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Subject color block with black border
                  Container(
                    width: 10,
                    decoration: BoxDecoration(
                      color: subjectColor,
                      border: const Border(
                        right: BorderSide(color: Colors.black, width: 2.5),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Subject and optional Status Badge
                          Builder(
                            builder: (context) {
                              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                              final hasStatusBadge = state == ClassCardState.current ||
                                  state == ClassCardState.next ||
                                  state == ClassCardState.past ||
                                  (state == ClassCardState.editable && classItem.isAiUnsure);

                              if (!hasStatusBadge) {
                                return Text(
                                  classItem.subject,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    fontSize: 17,
                                  ),
                                );
                              }

                              if (textScale >= 1.2) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      classItem.subject,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _buildStatusBadge(context, theme, ncColors),
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      classItem.subject,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatusBadge(context, theme, ncColors),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          // Time string with Tabular Figures
                          Text(
                            '${classItem.startTime} – ${classItem.endTime}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Meta icons: Room and Instructor
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (classItem.room != null && classItem.room!.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.meeting_room_outlined,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      classItem.room!,
                                      style: const TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              if (classItem.teacher != null && classItem.teacher!.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      classItem.teacher!,
                                      style: const TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          // Embedded Live Progress Bar for Current state
                          if (state == ClassCardState.current) ...[
                            const SizedBox(height: 12),
                            LiveProgressBar(
                              startTime: classItem.startDateTime(DateTime.now()),
                              endTime: classItem.endDateTime(DateTime.now()),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Actions for Editable state
                  if (state == ClassCardState.editable) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (onEdit != null)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Edit class',
                              onPressed: onEdit,
                            ),
                          if (onDelete != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: 'Delete class',
                              onPressed: onDelete,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    ThemeData theme,
    NextClassColors ncColors,
  ) {
    switch (state) {
      case ClassCardState.current:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE500), // Safety yellow
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF1744), // Live red indicator
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Now',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );

      case ClassCardState.next:
        final min = minutesUntilNext ?? 25;
        final String timeText;
        if (min < 60) {
          timeText = 'in $min min';
        } else {
          final hours = min ~/ 60;
          final remainingMinutes = min % 60;
          if (remainingMinutes == 0) {
            timeText = 'in ${hours}h';
          } else {
            timeText = 'in ${hours}h ${remainingMinutes}m';
          }
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD180), // Orange tint
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule,
                size: 14,
                color: Colors.black,
              ),
              const SizedBox(width: 4),
              Text(
                timeText,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );

      case ClassCardState.past:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFDCE2E6), // Ticket grey
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 14,
                color: Colors.black,
              ),
              const SizedBox(width: 4),
              Text(
                'Done',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );

      case ClassCardState.editable:
        if (classItem.isAiUnsure) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.help_outline,
                  size: 14,
                  color: Colors.black,
                ),
                const SizedBox(width: 4),
                Text(
                  'Check',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();

      default:
        return const SizedBox.shrink();
    }
  }
}
