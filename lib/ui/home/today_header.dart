import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/next_class_colors.dart';
import '../../data/models/class_item.dart';

/// Summary metadata calculated for the dynamic pill badge.
class ScheduleSummaryInfo {
  final IconData icon;
  final String text;
  final bool isCelebratory;

  const ScheduleSummaryInfo({
    required this.icon,
    required this.text,
    this.isCelebratory = false,
  });

  /// Computes the compact schedule summary for the current day.
  factory ScheduleSummaryInfo.compute({
    required DateTime now,
    required List<ClassItem> classesToday,
    required bool hasTimetable,
  }) {
    if (!hasTimetable) {
      return const ScheduleSummaryInfo(
        icon: Icons.info_outline_rounded,
        text: 'Nothing scheduled yet',
      );
    }

    if (classesToday.isEmpty) {
      return const ScheduleSummaryInfo(
        icon: Icons.weekend_rounded,
        text: 'Nothing on the timetable',
      );
    }

    final sorted = List<ClassItem>.from(classesToday)
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final currentMinutes = now.hour * 60 + now.minute;
    final totalCount = sorted.length;
    final totalLabel = totalCount == 1 ? '1 class' : '$totalCount classes';

    // 1. Active class in progress
    final activeClass = sorted.cast<ClassItem?>().firstWhere(
      (c) => currentMinutes >= c!.startMinutes && currentMinutes < c.endMinutes,
      orElse: () => null,
    );

    if (activeClass != null) {
      return ScheduleSummaryInfo(
        icon: Icons.schedule_rounded,
        text:
            '$totalLabel today · ${activeClass.subject} ends at ${activeClass.endTime}',
      );
    }

    // 2. All classes completed
    final allDone = sorted.every((c) => currentMinutes >= c.endMinutes);
    if (allDone) {
      return const ScheduleSummaryInfo(
        icon: Icons.celebration_rounded,
        text: 'Classes finished for today',
      );
    }

    // 3. Before first class
    final firstClass = sorted.first;
    if (currentMinutes < firstClass.startMinutes) {
      return ScheduleSummaryInfo(
        icon: Icons.schedule_rounded,
        text: '$totalLabel today · next at ${firstClass.startTime}',
      );
    }

    // 4. Between classes
    final upcoming = sorted
        .where((c) => c.startMinutes > currentMinutes)
        .toList();
    if (upcoming.isNotEmpty) {
      final nextClass = upcoming.first;
      final remainingCount = upcoming.length;
      final remainingLabel = remainingCount == 1
          ? '1 class left'
          : '$remainingCount classes left';
      return ScheduleSummaryInfo(
        icon: Icons.schedule_rounded,
        text: '$remainingLabel · next at ${nextClass.startTime}',
      );
    }

    return const ScheduleSummaryInfo(
      icon: Icons.celebration_rounded,
      text: 'Classes finished for today',
    );
  }
}

/// Compact date and schedule summary for the Today screen.
class TodayHeader extends StatelessWidget {
  final String userName;
  final DateTime currentTime;
  final List<ClassItem> classesToday;
  final bool hasTimetable;

  const TodayHeader({
    super.key,
    this.userName = '',
    required this.currentTime,
    required this.classesToday,
    this.hasTimetable = true,
  });

  String _formatDate() {
    return DateFormat('EEEE, d MMMM').format(currentTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ncColors = context.ncColors;

    final summary = ScheduleSummaryInfo.compute(
      now: currentTime,
      classesToday: classesToday,
      hasTimetable: hasTimetable,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDate(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: ncColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),

        // 4. Dynamic Schedule Summary Pill (ticket style)
        _buildSummaryPill(context, theme, ncColors, summary),
      ],
    );
  }

  Widget _buildSummaryPill(
    BuildContext context,
    ThemeData theme,
    NextClassColors ncColors,
    ScheduleSummaryInfo summary,
  ) {
    final Color bgColor;
    final Color iconColor;
    final Color textColor;

    if (summary.isCelebratory) {
      bgColor = const Color(0xFF00E676); // Electric green celebration
      iconColor = Colors.black;
      textColor = Colors.black;
    } else if (!hasTimetable || classesToday.isEmpty) {
      bgColor = ncColors.surface;
      iconColor = ncColors.icon;
      textColor = ncColors.textPrimary;
    } else {
      bgColor = const Color(0xFFFFE500); // High-contrast safety yellow ticket
      iconColor = Colors.black;
      textColor = Colors.black;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ncColors.border, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: ncColors.shadow,
            offset: const Offset(2.5, 2.5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(summary.icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              summary.text,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
