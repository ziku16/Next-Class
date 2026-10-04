import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/next_class_colors.dart';

void main() {
  runApp(const NextClassApp());
}

class NextClassApp extends StatelessWidget {
  const NextClassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextClass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const ThemeShowcasePage(),
    );
  }
}

class ThemeShowcasePage extends StatelessWidget {
  const ThemeShowcasePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ncColors = context.ncColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NextClass Design System'),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good morning, Ali', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Lagoon-teal primary, warm coral quizzes, Manrope tabular figures.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('Functional Tokens', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Now · 09:30 – 10:20',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ncColors.quizContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tomorrow · Ch. 4–5',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: ncColors.onQuizContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('8 Modulo Subject Colors', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(8, (index) {
                final color = ncColors.getSubjectColor(index);
                return Chip(
                  avatar: CircleAvatar(backgroundColor: color, radius: 6),
                  label: Text('Subject ${index + 1}'),
                );
              }),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Class Card Preview', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Mathematics · Room B-12',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Save Timetable'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
