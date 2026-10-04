import 'package:flutter/material.dart';

/// Horizontal strip of day chips (Mon through Sun) with calendar numbers.
/// Highlights today's chip and supports auto-scrolling into view.
class DayChips extends StatefulWidget {
  final int selectedDayIndex; // 0 = Mon .. 6 = Sun
  final int? todayIndex; // 0 = Mon .. 6 = Sun (highlighted as Today)
  final List<int>? dayNumbers; // Optional day numbers for the week (e.g. 29, 30, 1, 2, 3, 4, 5)
  final ValueChanged<int> onDaySelected;

  const DayChips({
    super.key,
    required this.selectedDayIndex,
    this.todayIndex,
    this.dayNumbers,
    required this.onDaySelected,
  });

  @override
  State<DayChips> createState() => _DayChipsState();
}

class _DayChipsState extends State<DayChips> {
  late final ScrollController _scrollController;

  static const List<String> _shortDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveDay();
    });
  }

  void _scrollToActiveDay() {
    if (!_scrollController.hasClients) return;
    final targetIndex = widget.selectedDayIndex >= 0 ? widget.selectedDayIndex : (widget.todayIndex ?? 0);
    final targetOffset = (targetIndex * 64.0) - 32.0;
    if (targetOffset > 0 && targetOffset < _scrollController.position.maxScrollExtent) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 62,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = widget.selectedDayIndex == index;
          final isToday = widget.todayIndex == index;
          final dayName = _shortDays[index];
          final dayNumber = widget.dayNumbers != null && widget.dayNumbers!.length > index
              ? widget.dayNumbers![index].toString()
              : null;

          Color bgColor;
          Color fgColor;
          BorderSide borderSide = BorderSide.none;

          if (isSelected) {
            bgColor = theme.colorScheme.primary;
            fgColor = theme.colorScheme.onPrimary;
          } else if (isToday) {
            bgColor = theme.colorScheme.primaryContainer;
            fgColor = theme.colorScheme.onPrimaryContainer;
            borderSide = BorderSide(color: theme.colorScheme.primary, width: 1.5);
          } else {
            bgColor = theme.colorScheme.surfaceContainerLow;
            fgColor = theme.colorScheme.onSurface;
          }

          return Material(
            color: bgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: borderSide,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => widget.onDaySelected(index),
              child: Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? fgColor
                            : (isToday ? fgColor : theme.colorScheme.onSurfaceVariant),
                        fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (dayNumber != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        dayNumber,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: fgColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
