import 'dart:math';
import 'dart:ui';
import 'day_detector.dart';
import 'ocr_models.dart';
import 'time_detector.dart';

/// Represents a detected weekday column in the timetable grid with horizontal bounds.
class GridColumn {
  final String dayName; // 'Monday', 'Tuesday', etc.
  final double left;
  final double right;

  const GridColumn({
    required this.dayName,
    required this.left,
    required this.right,
  });

  double get width => right - left;
  double get centerX => (left + right) / 2;

  bool containsX(double x) => x >= left && x <= right;

  @override
  String toString() => 'GridCol($dayName: ${left.toStringAsFixed(1)}..${right.toStringAsFixed(1)})';
}

/// Represents a detected time row in the timetable grid with vertical bounds.
class GridRow {
  final String startTime;
  final String endTime;
  final double top;
  final double bottom;

  const GridRow({
    required this.startTime,
    required this.endTime,
    required this.top,
    required this.bottom,
  });

  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;

  bool containsY(double y) => y >= top && y <= bottom;

  @override
  String toString() => 'GridRow($startTime-$endTime: ${top.toStringAsFixed(1)}..${bottom.toStringAsFixed(1)})';
}

/// Reconstructed geometric grid of the timetable.
class TimetableGrid {
  final List<GridColumn> columns;
  final List<GridRow> rows;
  final Rect tableBounds;
  final double headerBottomY;
  final double timeColumnRightX;

  const TimetableGrid({
    required this.columns,
    required this.rows,
    required this.tableBounds,
    required this.headerBottomY,
    required this.timeColumnRightX,
  });

  bool get isValid => columns.isNotEmpty && rows.isNotEmpty;

  /// Finds the column containing the given X coordinate.
  GridColumn? findColumn(double x) {
    for (final col in columns) {
      if (col.containsX(x)) return col;
    }
    // Fallback: pick the closest column if slightly out of bounds
    if (columns.isNotEmpty) {
      GridColumn closest = columns.first;
      double minDiff = (x - closest.centerX).abs();
      for (final col in columns.skip(1)) {
        final diff = (x - col.centerX).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closest = col;
        }
      }
      if (minDiff < closest.width) return closest;
    }
    return null;
  }

  /// Finds the row containing the given Y coordinate.
  GridRow? findRow(double y) {
    for (final row in rows) {
      if (row.containsY(y)) return row;
    }
    // Fallback: pick closest row
    if (rows.isNotEmpty) {
      GridRow closest = rows.first;
      double minDiff = (y - closest.centerY).abs();
      for (final r in rows.skip(1)) {
        final diff = (y - r.centerY).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closest = r;
        }
      }
      if (minDiff < closest.height) return closest;
    }
    return null;
  }
}

/// Detects and reconstructs the structural columns (days) and rows (times) of a timetable.
class TimetableGridDetector {
  final DayDetector dayDetector;
  final TimeDetector timeDetector;

  const TimetableGridDetector({
    this.dayDetector = const DayDetector(),
    this.timeDetector = const TimeDetector(),
  });

  /// Builds a [TimetableGrid] from spatial OCR results.
  TimetableGrid detectGrid(OcrResult ocrResult) {
    final lines = ocrResult.lines;
    if (lines.isEmpty) {
      return TimetableGrid(
        columns: [],
        rows: [],
        tableBounds: Rect.zero,
        headerBottomY: 0,
        timeColumnRightX: 0,
      );
    }

    final imgWidth = ocrResult.imageSize.width > 0 ? ocrResult.imageSize.width : 1000.0;
    final imgHeight = ocrResult.imageSize.height > 0 ? ocrResult.imageSize.height : 1000.0;

    // 1. Detect Day Columns
    final dayCandidates = dayDetector.findDayCandidates(lines);

    // 2. Detect Time Rows
    final timeCandidates = timeDetector.findTimeCandidates(lines);

    // Calculate header boundary
    double headerBottomY = 0;
    if (dayCandidates.isNotEmpty) {
      headerBottomY = dayCandidates.map((d) => d.bottom).reduce(max);
    }

    // Calculate time column boundary (time labels on the left)
    double timeColumnRightX = 0;
    if (timeCandidates.isNotEmpty) {
      // Find time candidates that are to the left of the day headers
      final firstDayLeft = dayCandidates.isNotEmpty ? dayCandidates.first.left : imgWidth * 0.25;
      final leftTimes = timeCandidates.where((t) => t.left < firstDayLeft + 20).toList();
      if (leftTimes.isNotEmpty) {
        timeColumnRightX = leftTimes.map((t) => t.right).reduce(max);
      }
    }

    // 3. Reconstruct Columns
    final columns = _reconstructColumns(dayCandidates, timeColumnRightX, imgWidth);

    // 4. Reconstruct Rows
    final rows = _reconstructRows(timeCandidates, headerBottomY, imgHeight);

    // Table bounds
    final leftBound = columns.isNotEmpty ? columns.first.left : timeColumnRightX;
    final rightBound = columns.isNotEmpty ? columns.last.right : imgWidth;
    final topBound = rows.isNotEmpty ? rows.first.top : headerBottomY;
    final bottomBound = rows.isNotEmpty ? rows.last.bottom : imgHeight;

    return TimetableGrid(
      columns: columns,
      rows: rows,
      tableBounds: Rect.fromLTRB(leftBound, topBound, rightBound, bottomBound),
      headerBottomY: headerBottomY,
      timeColumnRightX: timeColumnRightX,
    );
  }

  List<GridColumn> _reconstructColumns(
    List<DayCandidate> days,
    double timeColumnRightX,
    double imgWidth,
  ) {
    if (days.isEmpty) {
      // Fallback: 5 equal columns Monday..Friday across the usable width
      final usableLeft = max(timeColumnRightX, imgWidth * 0.1);
      final usableWidth = imgWidth - usableLeft;
      final colWidth = usableWidth / 5;
      final defaultDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      return List.generate(5, (i) {
        return GridColumn(
          dayName: defaultDays[i],
          left: usableLeft + i * colWidth,
          right: usableLeft + (i + 1) * colWidth,
        );
      });
    }

    // Calculate average column width from detected days
    double avgWidth = 0;
    if (days.length > 1) {
      avgWidth = (days.last.center.dx - days.first.center.dx) / (days.length - 1);
    } else {
      avgWidth = (imgWidth - max(timeColumnRightX, days.first.left * 0.5)) / 5;
    }

    final List<GridColumn> result = [];

    // Construct boundaries between detected consecutive days
    for (int i = 0; i < days.length; i++) {
      final current = days[i];
      double colLeft;
      double colRight;

      if (i == 0) {
        // Left boundary of first column
        colLeft = max(timeColumnRightX, current.left - (avgWidth * 0.2));
      } else {
        final prev = days[i - 1];
        colLeft = (prev.right + current.left) / 2;
      }

      if (i == days.length - 1) {
        // Right boundary of last column
        colRight = min(imgWidth, current.right + (avgWidth * 0.2));
      } else {
        final next = days[i + 1];
        colRight = (current.right + next.left) / 2;
      }

      result.add(GridColumn(
        dayName: current.dayName,
        left: colLeft,
        right: colRight,
      ));
    }

    return result;
  }

  List<GridRow> _reconstructRows(
    List<TimeSlotCandidate> times,
    double headerBottomY,
    double imgHeight,
  ) {
    if (times.isEmpty) {
      // Default fallback: standard 5 university periods
      final defaultPeriods = [
        ('08:30', '09:20'),
        ('09:30', '10:20'),
        ('10:30', '11:20'),
        ('11:30', '12:20'),
        ('12:30', '13:20'),
        ('13:30', '14:20'),
        ('14:30', '15:20'),
      ];
      final usableTop = max(headerBottomY, imgHeight * 0.12);
      final usableHeight = imgHeight - usableTop;
      final rowHeight = usableHeight / defaultPeriods.length;

      return List.generate(defaultPeriods.length, (i) {
        return GridRow(
          startTime: defaultPeriods[i].$1,
          endTime: defaultPeriods[i].$2,
          top: usableTop + i * rowHeight,
          bottom: usableTop + (i + 1) * rowHeight,
        );
      });
    }

    // Deduplicate / cluster times by vertical proximity (within 20px)
    final List<TimeSlotCandidate> uniqueTimes = [];
    for (final t in times) {
      if (uniqueTimes.isEmpty) {
        uniqueTimes.add(t);
      } else {
        final last = uniqueTimes.last;
        if ((t.top - last.top).abs() > 25) {
          uniqueTimes.add(t);
        }
      }
    }

    final List<GridRow> result = [];
    double avgRowHeight = 60;
    if (uniqueTimes.length > 1) {
      avgRowHeight = (uniqueTimes.last.center.dy - uniqueTimes.first.center.dy) / (uniqueTimes.length - 1);
    }

    for (int i = 0; i < uniqueTimes.length; i++) {
      final current = uniqueTimes[i];
      double rowTop;
      double rowBottom;

      if (i == 0) {
        rowTop = max(headerBottomY, current.top - (avgRowHeight * 0.2));
      } else {
        final prev = uniqueTimes[i - 1];
        rowTop = (prev.bottom + current.top) / 2;
      }

      if (i == uniqueTimes.length - 1) {
        rowBottom = min(imgHeight, current.bottom + avgRowHeight);
      } else {
        final next = uniqueTimes[i + 1];
        rowBottom = (current.bottom + next.top) / 2;
      }

      // If the current slot doesn't have an explicit end time, derive from next slot start time
      String endTime = current.range.endTime;
      if (!current.range.hasExplicitEndTime && i + 1 < uniqueTimes.length) {
        endTime = uniqueTimes[i + 1].range.startTime;
      }

      result.add(GridRow(
        startTime: current.range.startTime,
        endTime: endTime,
        top: rowTop,
        bottom: rowBottom,
      ));
    }

    return result;
  }
}
