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
    final Color textColor = Colors.black;
    final Color numColor = Colors.black;

    if (isSelected) {
      bgColor = const Color(0xFFFFB74D); // Vibrant orange active
    } else if (isToday) {
      bgColor = const Color(0xFFFFE500); // Safety yellow
    } else {
      bgColor = Colors.white;
    }

    return Container(
      key: Key('day_chip_$index'),
      child: GestureDetector(
        onTap: () => widget.onDaySelected(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: chipWidth,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: isSelected ? const Offset(1.5, 1.5) : const Offset(2.5, 2.5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Day Abbreviation
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  dayName.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 2),

              // Day Number
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  dayNum,
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

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
