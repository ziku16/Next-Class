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

  /// Computes schedule pill badge icon and label according to current time and classes.
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
        text: '$totalLabel today · ${activeClass.subject} ends at ${activeClass.endTime}',
      );
    }

    // 2. All classes completed
    final allDone = sorted.every((c) => currentMinutes >= c.endMinutes);
    if (allDone) {
      return const ScheduleSummaryInfo(
        icon: Icons.celebration_rounded,
        text: "That's a wrap for today. Shabash!",
        isCelebratory: true,
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
    final upcoming = sorted.where((c) => c.startMinutes > currentMinutes).toList();
    if (upcoming.isNotEmpty) {
      final nextClass = upcoming.first;
      final remainingCount = upcoming.length;
      final remainingLabel =
          remainingCount == 1 ? '1 class left' : '$remainingCount classes left';
      return ScheduleSummaryInfo(
        icon: Icons.schedule_rounded,
        text: '$remainingLabel · next at ${nextClass.startTime}',
      );
    }

    return const ScheduleSummaryInfo(
      icon: Icons.celebration_rounded,
      text: "That's a wrap for today. Shabash!",
      isCelebratory: true,
    );
  }
}

/// Header component of the Today screen displaying:
/// - Time-sensitive greeting ("Good morning/afternoon/evening, [User Name]")
/// - Formatted date ("Thursday, 2 October")
/// - Dynamic schedule summary pill with status icon
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

  String _getGreeting() {
    if (!hasTimetable) {
      return userName.trim().isEmpty ? 'Welcome to NextClass' : 'Welcome, $userName';
    }
    final hour = currentTime.hour;
    final prefix = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    if (userName.trim().isEmpty) {
      return prefix;
    }
    return '$prefix, $userName';
  }

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
        // 1. Playful slanted sticker tag: NEXTCLASS ↗
        Transform.rotate(
          angle: -0.04,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE500), // Safety yellow
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black, width: 3.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black,
                  offset: Offset(3.5, 3.5),
                  blurRadius: 0,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NEXTCLASS',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.black,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.north_east_rounded,
                  size: 16,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),

        // 2. Ultra-bold greeting
        Text(
          _getGreeting(),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),

        // 3. Date & Daily metadata badge row
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Date pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black, width: 2.0),
              ),
              child: Text(
                _formatDate(),
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),

            // Daily metadata count stamp
            if (hasTimetable && classesToday.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 2.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  '${classesToday.length} ${classesToday.length == 1 ? "CLASS" : "CLASSES"} TODAY',
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Colors.black,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

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
      bgColor = Colors.white;
      iconColor = Colors.black;
      textColor = Colors.black;
    } else {
      bgColor = const Color(0xFFFFF9C4); // Pale yellow ticket
      iconColor = Colors.black;
      textColor = Colors.black;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.black,
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(2.5, 2.5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            summary.icon,
            size: 18,
            color: iconColor,
          ),
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
