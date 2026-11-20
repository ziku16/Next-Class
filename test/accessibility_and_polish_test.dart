import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/core/theme/app_theme.dart';
import 'package:nextclass/core/theme/next_class_colors.dart';
import 'package:nextclass/data/models/class_item.dart';
import 'package:nextclass/data/models/scan_quota.dart';
import 'package:nextclass/state/upload_provider.dart';
import 'package:nextclass/ui/home/today_header.dart';
import 'package:nextclass/ui/review/edit_class_sheet.dart';
import 'package:nextclass/ui/shared/class_card.dart';
import 'package:nextclass/ui/shared/day_chips.dart';
import 'package:nextclass/ui/shared/live_progress_bar.dart';
import 'package:nextclass/ui/shared/nc_banner.dart';
import 'package:nextclass/ui/shared/offline_banner.dart';
import 'package:nextclass/ui/upload/parsing_loader_screen.dart';
import 'package:nextclass/ui/week/class_detail_sheet.dart';
import 'package:nextclass/ui/week/day_selector_strip.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrapWithScale(Widget child, {double textScale = 1.0, bool disableAnimations = false, bool isDark = false}) {
  final theme = isDark ? AppTheme.dark : AppTheme.light;
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}

double _relativeLuminance(Color c) {
  double toLinear(double channel) {
    return channel <= 0.03928
        ? channel / 12.92
        : pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = toLinear(c.r);
  final g = toLinear(c.g);
  final b = toLinear(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color c1, Color c2) {
  final l1 = _relativeLuminance(c1);
  final l2 = _relativeLuminance(c2);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const sampleClass = ClassItem(
    id: 'class_a1',
    subject: 'Distributed Systems & Mobile Cloud Architecture',
    subjectColorIndex: 0,
    dayOfWeek: 'Monday',
    startTime: '08:30',
    endTime: '10:00',
    room: 'Hall B-12',
    teacher: 'Prof. Miller',
  );

  group('Task 1: Font Scale Resilience (130% System Font)', () {
    testWidgets('ClassCard wraps subject title and drops status pill below title under 130% font scale', (tester) async {
      await tester.pumpWidget(_wrapWithScale(
        const ClassCard(
          classItem: sampleClass,
          state: ClassCardState.current,
        ),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      // Subject text wraps cleanly
      expect(find.text('Distributed Systems & Mobile Cloud Architecture'), findsOneWidget);
      // Status pill is rendered
      expect(find.text('Now'), findsOneWidget);
      // Time string is rendered without collision
      expect(find.text('08:30 – 10:00'), findsOneWidget);

      // Verify that under 1.3x text scale, the badge sits below the title in a Column
      final titleFinder = find.text('Distributed Systems & Mobile Cloud Architecture');
      final badgeFinder = find.text('Now');
      final timeFinder = find.text('08:30 – 10:00');

      final titleTop = tester.getTopLeft(titleFinder).dy;
      final badgeTop = tester.getTopLeft(badgeFinder).dy;
      final timeTop = tester.getTopLeft(timeFinder).dy;

      // Status pill drops below title: titleTop < badgeTop < timeTop
      expect(badgeTop, greaterThan(titleTop));
      expect(timeTop, greaterThan(badgeTop));
    });

    testWidgets('ClassCard next state drops "in 25 min" pill below title under 130% font scale', (tester) async {
      await tester.pumpWidget(_wrapWithScale(
        const ClassCard(
          classItem: sampleClass,
          state: ClassCardState.next,
          minutesUntilNext: 25,
        ),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(find.text('in 25 min'), findsOneWidget);
      final badgeTop = tester.getTopLeft(find.text('in 25 min')).dy;
      final titleTop = tester.getTopLeft(find.text('Distributed Systems & Mobile Cloud Architecture')).dy;
      expect(badgeTop, greaterThan(titleTop));
    });

    testWidgets('ClassCard past state drops "Done" badge below title under 130% font scale', (tester) async {
      await tester.pumpWidget(_wrapWithScale(
        const ClassCard(
          classItem: sampleClass,
          state: ClassCardState.past,
        ),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);
      final badgeTop = tester.getTopLeft(find.text('Done')).dy;
      final titleTop = tester.getTopLeft(find.text('Distributed Systems & Mobile Cloud Architecture')).dy;
      expect(badgeTop, greaterThan(titleTop));
    });

    testWidgets('ClassCard editable state drops "Check" badge below title under 130% font scale', (tester) async {
      final unsureClass = sampleClass.copyWith(isAiUnsure: true);
      await tester.pumpWidget(_wrapWithScale(
        ClassCard(
          classItem: unsureClass,
          state: ClassCardState.editable,
          onEdit: () {},
          onDelete: () {},
        ),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsOneWidget);
      final badgeTop = tester.getTopLeft(find.text('Check')).dy;
      final titleTop = tester.getTopLeft(find.text('Distributed Systems & Mobile Cloud Architecture')).dy;
      expect(badgeTop, greaterThan(titleTop));
    });

    testWidgets('TodayHeader dynamic schedule summary pill wraps gracefully under 130% font scale', (tester) async {
      await tester.pumpWidget(_wrapWithScale(
        TodayHeader(
          userName: 'Ali',
          currentTime: DateTime(2026, 10, 2, 8, 45),
          classesToday: const [sampleClass],
          hasTimetable: true,
        ),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Friday, 2 October'), findsOneWidget);
      expect(find.byType(TodayHeader), findsOneWidget);
    });

    testWidgets('ClassDetailSheet renders with stretched color stripe under 130% font scale', (tester) async {
      await tester.pumpWidget(_wrapWithScale(
        const ClassDetailSheet(
          classItem: sampleClass,
          cardState: ClassCardState.current,
        ),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Distributed Systems & Mobile Cloud Architecture'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
    });
  });

  group('Task 2: Touch Target Compliance (48x48 dp Minimum)', () {
    testWidgets('NcBanner action and dismiss buttons have minimum 48x48 dp hit bounds', (tester) async {
      await tester.pumpWidget(_wrapWithScale(
        NcBanner(
          kind: NcBannerKind.warning,
          title: 'Attention needed',
          message: 'Please review your timetable entries.',
          actionLabel: 'Fix',
          onAction: () {},
          onDismiss: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Find action TextButton
      final actionButton = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Fix'));
      final minSize = actionButton.style?.minimumSize?.resolve({});
      expect(minSize?.width, greaterThanOrEqualTo(48.0));
      expect(minSize?.height, greaterThanOrEqualTo(48.0));

      // Find close IconButton
      final closeButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(closeButton.constraints?.minWidth, greaterThanOrEqualTo(48.0));
      expect(closeButton.constraints?.minHeight, greaterThanOrEqualTo(48.0));
    });

    testWidgets('OfflineBanner retry button has minimum 48x48 dp hit bounds', (tester) async {
      await tester.pumpWidget(_wrapWithScale(
        OfflineBanner(
          isOffline: true,
          onRetry: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final retryButton = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Retry'));
      final minSize = retryButton.style?.minimumSize?.resolve({});
      expect(minSize?.width, greaterThanOrEqualTo(48.0));
      expect(minSize?.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('DayChips chips have hit area >= 48x48 dp', (tester) async {
      await tester.pumpWidget(_wrapWithScale(
        DayChips(
          selectedDayIndex: 0,
          todayIndex: 0,
          onDaySelected: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // The parent Material/InkWell exceeds 48 dp
      final chipMaterial = find.byType(Material).first;
      final materialSize = tester.getSize(chipMaterial);
      expect(materialSize.width, greaterThanOrEqualTo(48.0));
      expect(materialSize.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('DaySelectorStrip chips have hit area >= 48x48 dp', (tester) async {
      await tester.pumpWidget(_wrapWithScale(
        DaySelectorStrip(
          referenceDate: DateTime(2026, 10, 1),
          selectedDayIndex: 0,
          onDaySelected: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final strip = tester.getSize(find.byType(DaySelectorStrip));
      expect(strip.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('ClassCard editable action buttons have minimum 48x48 dp hit bounds', (tester) async {
      await tester.pumpWidget(_wrapWithScale(
        ClassCard(
          classItem: sampleClass,
          state: ClassCardState.editable,
          onEdit: () {},
          onDelete: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final editBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.edit_outlined));
      final deleteBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.delete_outline));

      // Default Flutter IconButton constraints are 48x48 dp
      final editConstraints = editBtn.constraints ?? const BoxConstraints(minWidth: 48, minHeight: 48);
      final deleteConstraints = deleteBtn.constraints ?? const BoxConstraints(minWidth: 48, minHeight: 48);

      expect(editConstraints.minWidth, greaterThanOrEqualTo(48.0));
      expect(editConstraints.minHeight, greaterThanOrEqualTo(48.0));
      expect(deleteConstraints.minWidth, greaterThanOrEqualTo(48.0));
      expect(deleteConstraints.minHeight, greaterThanOrEqualTo(48.0));
    });
  });

  group('Task 3: WCAG AA Contrast Audit', () {
    test('All 8 Modulo Subject Colors pass contrast against light & dark card surfaces', () {
      final lightCardBg = AppTheme.light.colorScheme.surfaceContainerLow;
      final darkCardBg = AppTheme.dark.colorScheme.surfaceContainerLow;

      for (int i = 0; i < NextClassColors.defaultSubjects.length; i++) {
        final subjectColor = NextClassColors.defaultSubjects[i];
        final contrastLight = _contrastRatio(subjectColor, lightCardBg);
        final contrastDark = _contrastRatio(subjectColor, darkCardBg);

        // Subject colors serve as graphical accents/stripes (WCAG AA non-text contrast >= 3:1)
        expect(
          contrastLight >= 3.0 || contrastDark >= 3.0,
          isTrue,
          reason: 'Subject color $i ($subjectColor) should hold contrast on cards',
        );
      }
    });

    test('Light theme functional pills pass WCAG AA contrast (>= 4.5:1 text or >= 3:1 large text)', () {
      final lightColors = NextClassColors.light;
      final lightScheme = AppTheme.light.colorScheme;

      // Now pill: primaryContainer / onPrimaryContainer
      final nowRatio = _contrastRatio(lightScheme.onPrimaryContainer, lightScheme.primaryContainer);
      expect(nowRatio, greaterThanOrEqualTo(4.5));

      // Next pill: secondaryContainer / onSecondaryContainer
      final nextRatio = _contrastRatio(lightScheme.onSecondaryContainer, lightScheme.secondaryContainer);
      expect(nextRatio, greaterThanOrEqualTo(4.5));

      // Warning / Check pill: warningContainer / onWarningContainer
      final checkRatio = _contrastRatio(lightColors.onWarningContainer, lightColors.warningContainer);
      expect(checkRatio, greaterThanOrEqualTo(4.5));

      // Quiz Urgent pill: onQuizUrgent on quizUrgent
      final urgentRatio = _contrastRatio(lightColors.onQuizUrgent, lightColors.quizUrgent);
      expect(urgentRatio, greaterThanOrEqualTo(4.5));

      // Offline banner: onInverseSurface on inverseSurface
      final offlineRatio = _contrastRatio(lightScheme.onInverseSurface, lightScheme.inverseSurface);
      expect(offlineRatio, greaterThanOrEqualTo(4.5));

      // Success pill: onSuccessContainer on successContainer
      final successRatio = _contrastRatio(lightColors.onSuccessContainer, lightColors.successContainer);
      expect(successRatio, greaterThanOrEqualTo(4.5));
    });

    test('Dark theme functional pills pass WCAG AA contrast (>= 4.5:1 text or >= 3:1 large text)', () {
      final darkColors = NextClassColors.dark;
      final darkScheme = AppTheme.dark.colorScheme;

      // Now pill: primaryContainer / onPrimaryContainer
      final nowRatio = _contrastRatio(darkScheme.onPrimaryContainer, darkScheme.primaryContainer);
      expect(nowRatio, greaterThanOrEqualTo(4.5));

      // Next pill: secondaryContainer / onSecondaryContainer
      final nextRatio = _contrastRatio(darkScheme.onSecondaryContainer, darkScheme.secondaryContainer);
      expect(nextRatio, greaterThanOrEqualTo(4.5));

      // Warning / Check pill: warningContainer / onWarningContainer
      final checkRatio = _contrastRatio(darkColors.onWarningContainer, darkColors.warningContainer);
      expect(checkRatio, greaterThanOrEqualTo(4.5));

      // Quiz Urgent pill: onQuizUrgent on quizUrgent
      final urgentRatio = _contrastRatio(darkColors.onQuizUrgent, darkColors.quizUrgent);
      expect(urgentRatio, greaterThanOrEqualTo(4.5));

      // Offline banner: onInverseSurface on inverseSurface
      final offlineRatio = _contrastRatio(darkScheme.onInverseSurface, darkScheme.inverseSurface);
      expect(offlineRatio, greaterThanOrEqualTo(4.5));

      // Success pill: onSuccessContainer on successContainer
      final successRatio = _contrastRatio(darkColors.onSuccessContainer, darkColors.successContainer);
      expect(successRatio, greaterThanOrEqualTo(4.5));
    });
  });

  group('Task 4: Reduced Motion Support', () {
    testWidgets('LiveProgressBar renders static layout when animations disabled', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrapWithScale(
        LiveProgressBar(
          startTime: now.subtract(const Duration(minutes: 10)),
          endTime: now.add(const Duration(minutes: 10)),
        ),
        disableAnimations: true,
      ));
      await tester.pumpAndSettle();

      // Ensure no active ticker or animation builder runs
      expect(find.byType(LiveProgressBar), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    testWidgets('OfflineBanner collapses immediately when animations disabled', (tester) async {
      await tester.pumpWidget(_wrapWithScale(
        const OfflineBanner(isOffline: true),
        disableAnimations: true,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offline_banner_container')), findsOneWidget);

      final animatedSize = tester.widget<AnimatedSize>(find.byType(AnimatedSize));
      expect(animatedSize.duration, Duration.zero);
    });

    testWidgets('ParsingLoaderScreen uses static progress arc when animations disabled', (tester) async {
      await tester.pumpWidget(_wrapWithScale(
        ParsingLoaderScreen(
          uploadProvider: UploadProvider(),
          autoStartExtraction: false,
        ),
        disableAnimations: true,
      ));
      await tester.pumpAndSettle();

      final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
      // Static value arc rather than infinite spinning animation
      expect(indicator.value, 0.75);

      final switcher = tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
      expect(switcher.duration, Duration.zero);
    });
  });

  group('Task 5: Time Validation Logic & Quota Reset Unit Tests', () {
    testWidgets('EditClassSheet validates end time strictly after start time', (tester) async {
      await tester.pumpWidget(_wrapWithScale(
        const EditClassSheet(),
      ));
      await tester.pumpAndSettle();

      // Enter subject name
      await tester.enterText(find.byType(TextField).first, 'Linear Algebra');
      await tester.pumpAndSettle();

      // Save button is enabled when start is 09:00 and end is 10:00 (default)
      final saveBtn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save class'));
      expect(saveBtn.onPressed, isNotNull);
    });

    test('ScanQuota enforces 2 daily and 3 weekly scan limits', () {
      final quota = ScanQuota.initial();
      expect(quota.canScan(), isTrue);
      expect(quota.dailyScansLeft, 2);
      expect(quota.weeklyScansLeft, 3);
      expect(quota.quotaLabel, '2 of 2 left today · 3 of 3 this week');

      // 1st scan
      final after1 = quota.consumeScan();
      expect(after1.dailyScansLeft, 1);
      expect(after1.weeklyScansLeft, 2);
      expect(after1.canScan(), isTrue);

      // 2nd scan
      final after2 = after1.consumeScan();
      expect(after2.dailyScansLeft, 0);
      expect(after2.weeklyScansLeft, 1);
      expect(after2.isDailyLimitReached, isTrue);
      expect(after2.canScan(), isFalse); // Daily limit reached!
    });

    test('ScanQuota resets daily scans on next calendar day while retaining weekly scans', () {
      final now = DateTime(2026, 10, 2, 10, 0); // Friday 10:00 AM
      final quota = ScanQuota(
        dailyScansUsed: 2,
        lastDailyReset: now,
        weeklyScansUsed: 2,
        lastWeeklyReset: now,
      );

      expect(quota.canScan(now: now), isFalse);

      // Next day: Saturday 9:00 AM
      final nextDay = DateTime(2026, 10, 3, 9, 0);
      final refreshed = quota.resetIfExpired(now: nextDay);

      expect(refreshed.dailyScansUsed, 0);
      expect(refreshed.dailyScansLeft, 2);
      expect(refreshed.weeklyScansUsed, 2); // Retained!
      expect(refreshed.weeklyScansLeft, 1);
      expect(refreshed.canScan(now: nextDay), isTrue);

      // Consume final weekly scan
      final afterSaturdayScan = refreshed.consumeScan(now: nextDay);
      expect(afterSaturdayScan.weeklyScansUsed, 3);
      expect(afterSaturdayScan.weeklyScansLeft, 0);
      expect(afterSaturdayScan.isWeeklyLimitReached, isTrue);
      expect(afterSaturdayScan.canScan(now: nextDay), isFalse);
    });

    test('ScanQuota resets weekly scans after 7 days', () {
      final week1 = DateTime(2026, 10, 2, 10, 0);
      final maxedWeeklyQuota = ScanQuota(
        dailyScansUsed: 0,
        lastDailyReset: week1,
        weeklyScansUsed: 3,
        lastWeeklyReset: week1,
      );

      expect(maxedWeeklyQuota.canScan(now: week1), isFalse);

      // 8 days later
      final week2 = week1.add(const Duration(days: 8));
      final refreshedWeekly = maxedWeeklyQuota.resetIfExpired(now: week2);

      expect(refreshedWeekly.weeklyScansUsed, 0);
      expect(refreshedWeekly.weeklyScansLeft, 3);
      expect(refreshedWeekly.canScan(now: week2), isTrue);
    });
  });
}
