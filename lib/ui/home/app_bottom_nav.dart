import 'package:flutter/material.dart';
import '../../core/theme/next_class_colors.dart';
import '../shared/bounceable.dart';

/// Revo-Brutalist Bottom Navigation Bar for NextClass:
/// - Surface bar with 3px border
/// - Chunky rectangular tab segments with 2.5px solid borders and hard offset drop shadows
/// - High-contrast vibrant active tab highlighting
/// - Theme-adaptive icons and ultra-bold typography
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final nc = context.ncColors;

    return Container(
      decoration: BoxDecoration(
        color: nc.surface,
        border: Border(
          top: BorderSide(color: nc.border, width: 3.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _buildTabItem(
              context: context,
              index: 0,
              icon: currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
              label: 'Today',
            ),
            const SizedBox(width: 8),
            _buildTabItem(
              context: context,
              index: 1,
              icon: currentIndex == 1
                  ? Icons.calendar_month_rounded
                  : Icons.calendar_month_outlined,
              label: 'Week',
            ),
            const SizedBox(width: 8),
            _buildTabItem(
              context: context,
              index: 2,
              icon: currentIndex == 2
                  ? Icons.assignment_turned_in_rounded
                  : Icons.assignment_outlined,
              label: 'Quizzes',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentIndex == index;
    final nc = context.ncColors;

    return Expanded(
      child: GestureDetector(
        onTap: () => onDestinationSelected(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFB74D) : nc.surface,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: nc.border, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: nc.shadow,
                offset: isSelected ? const Offset(1.5, 1.5) : const Offset(3.0, 3.0),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.black : nc.icon,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: isSelected ? Colors.black : nc.textPrimary,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper factory to build the contextual NextClass FloatingActionButton.
  /// Chunky brutalist button with 3px border, hard offset drop shadow,
  /// and vivid orange / safety yellow background.
  static Widget buildFab({
    required BuildContext context,
    required bool hasTimetable,
    required VoidCallback onPressed,
  }) {
    final nc = context.ncColors;
    final label = hasTimetable ? 'Add quiz' : 'Upload timetable';
    final icon = hasTimetable ? Icons.add_rounded : Icons.upload_file_rounded;
    final bgColor = hasTimetable ? const Color(0xFFFF5500) : const Color(0xFFFFE500);
    final fgColor = hasTimetable ? Colors.white : Colors.black;

    return Bounceable(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: nc.shadow,
              offset: const Offset(3.5, 3.5),
              blurRadius: 0,
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: nc.border, width: 3.0),
          ),
          icon: Icon(icon, color: fgColor, size: 22),
          label: Text(
            label,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: fgColor,
            ),
          ),
        ),
      ),
    );
  }
}
