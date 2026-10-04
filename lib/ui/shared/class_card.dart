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
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // 6 dp Subject color stripe
                Container(
                  width: 6,
                  color: subjectColor,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classItem.subject,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${classItem.startTime} – ${classItem.endTime}${classItem.room != null ? ' · ${classItem.room}' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state == ClassCardState.past) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: ncColors.success,
                    ),
                  ),
                ],
                const SizedBox(width: 16),
              ],
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
    Border border;
    switch (state) {
      case ClassCardState.current:
        border = Border.all(color: ncColors.classCurrentBorder, width: 2.0);
        break;
      case ClassCardState.next:
        border = Border.all(color: theme.colorScheme.outline, width: 1.0);
        break;
      case ClassCardState.past:
        border = Border.all(color: theme.colorScheme.outlineVariant, width: 1.0);
        break;
      default:
        border = Border.all(color: Colors.transparent, width: 0.0);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 6 dp Subject color stripe
                  Container(
                    width: 6,
                    color: subjectColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Subject and optional Status Badge (drops below title under large type)
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
                                  style: theme.textTheme.titleMedium,
                                );
                              }

                              if (textScale >= 1.2) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      classItem.subject,
                                      style: theme.textTheme.titleMedium,
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
                                      style: theme.textTheme.titleMedium,
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
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
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
                                    Icon(
                                      Icons.meeting_room_outlined,
                                      size: 16,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      classItem.room!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              if (classItem.teacher != null && classItem.teacher!.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      classItem.teacher!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
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
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Now',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

      case ClassCardState.next:
        final min = minutesUntilNext ?? 25;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                'in $min min',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

      case ClassCardState.past:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 14,
                color: ncColors.success,
              ),
              const SizedBox(width: 4),
              Text(
                'Done',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
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
              color: ncColors.warningContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.help_outline,
                  size: 14,
                  color: ncColors.onWarningContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  'Check',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: ncColors.onWarningContainer,
                    fontWeight: FontWeight.w700,
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
