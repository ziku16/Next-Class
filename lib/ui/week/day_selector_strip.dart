import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Horizontal selector strip of 7 day chips (Monday through Sunday) for the Week view.
/// Shows short day abbreviation and day-of-month number.
/// Highlights the active / selected day and today.
class DaySelectorStrip extends StatefulWidget {
  final DateTime referenceDate;
  final int selectedDayIndex; // 0 = Mon, 6 = Sun
  final ValueChanged<int> onDaySelected;

  const DaySelectorStrip({
    super.key,
    required this.referenceDate,
    required this.selectedDayIndex,
    required this.onDaySelected,
  });

  @override
  State<DaySelectorStrip> createState() => _DaySelectorStripState();
}

class _DaySelectorStripState extends State<DaySelectorStrip> {
  late final ScrollController _scrollController;
  late final List<DateTime> _weekDays;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _computeWeekDays();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant DaySelectorStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.referenceDate != oldWidget.referenceDate) {
      _computeWeekDays();
    }
    if (widget.selectedDayIndex != oldWidget.selectedDayIndex) {
      _scrollToSelected(animate: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _computeWeekDays() {
    final ref = widget.referenceDate;
    final monday = ref.subtract(Duration(days: ref.weekday - 1));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);
    _weekDays = List.generate(7, (i) => mondayStart.add(Duration(days: i)));
  }

  void _scrollToSelected({required bool animate}) {
    if (!_scrollController.hasClients) return;
    final targetOffset = (widget.selectedDayIndex * 58.0)
        .clamp(0.0, _scrollController.position.maxScrollExtent);

    if (animate) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final stripHeight = (86.0 * textScale).clamp(86.0, 115.0);

    return Container(
      height: stripHeight,
      color: theme.colorScheme.surface,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _weekDays.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final dayDate = _weekDays[index];
          final isSelected = index == widget.selectedDayIndex;
          final isToday = dayDate.year == today.year &&
              dayDate.month == today.month &&
              dayDate.day == today.day;

          return _buildDayChip(
            context: context,
            theme: theme,
            index: index,
            date: dayDate,
            isSelected: isSelected,
            isToday: isToday,
          );
        },
      ),
    );
  }

  Widget _buildDayChip({
    required BuildContext context,
    required ThemeData theme,
    required int index,
    required DateTime date,
    required bool isSelected,
    required bool isToday,
  }) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final chipWidth = (54.0 * textScale).clamp(52.0, 72.0);

    final dayName = DateFormat('E').format(date); // Mon, Tue...
    final dayNum = date.day.toString();

    final Color bgColor;
    final Color textColor;
    final Color numColor;
    final Border? border;

    if (isSelected) {
      bgColor = theme.colorScheme.primaryContainer;
      textColor = theme.colorScheme.onPrimaryContainer;
      numColor = theme.colorScheme.onPrimaryContainer;
      border = Border.all(
        color: theme.colorScheme.primary,
        width: 1.5,
      );
    } else if (isToday) {
      bgColor = theme.colorScheme.surfaceContainerHigh;
      textColor = theme.colorScheme.primary;
      numColor = theme.colorScheme.primary;
      border = Border.all(
        color: theme.colorScheme.primary.withValues(alpha: 0.6),
        width: 1.0,
      );
    } else {
      bgColor = theme.colorScheme.surfaceContainerLow;
      textColor = theme.colorScheme.onSurfaceVariant;
      numColor = theme.colorScheme.onSurface;
      border = Border.all(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        width: 1.0,
      );
    }

    return InkWell(
      key: Key('day_chip_$index'),
      onTap: () => widget.onDaySelected(index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: chipWidth,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: border,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Day Abbreviation
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                dayName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor,
                  fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 2),

            // Day Number
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                dayNum,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: numColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            // Small indicator dot if today and not selected
            if (isToday && !isSelected) ...[
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
