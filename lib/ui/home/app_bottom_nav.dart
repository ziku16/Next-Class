import 'package:flutter/material.dart';

/// Persistent Material 3 NavigationBar for NextClass with 3 primary tabs:
/// - Today
/// - Week
/// - Quizzes
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
    final theme = Theme.of(context);

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: theme.colorScheme.surface,
      indicatorColor: theme.colorScheme.secondaryContainer,
      elevation: 3,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.today_outlined),
          selectedIcon: Icon(Icons.today_rounded),
          label: 'Today',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_view_week_outlined),
          selectedIcon: Icon(Icons.calendar_view_week_rounded),
          label: 'Week',
        ),
        NavigationDestination(
          icon: Icon(Icons.quiz_outlined),
          selectedIcon: Icon(Icons.quiz_rounded),
          label: 'Quizzes',
        ),
      ],
    );
  }

  /// Helper factory to build the contextual NextClass FloatingActionButton.
  /// Shows "Upload timetable" when no timetable exists, or "+ Add quiz" when active.
  static Widget buildFab({
    required BuildContext context,
    required bool hasTimetable,
    required VoidCallback onPressed,
  }) {
    if (!hasTimetable) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Upload timetable'),
      );
    }

    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add quiz'),
    );
  }
}
