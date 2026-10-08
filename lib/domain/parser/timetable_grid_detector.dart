import 'dart:math';
import 'dart:ui';
import 'day_detector.dart';
import 'ocr_models.dart';
import 'time_detector.dart';

/// Represents a column in the timetable grid (either a Lecture period or a weekday).
class GridColumn {
  final int index;
  final String label; // 'Lecture 1', 'Lecture 2', etc., or 'Monday'
  final String startTime;
  final String endTime;
  final String? dayName; // 'Monday' if days are columns
  final double left;
  final double right;

  const GridColumn({
    this.index = 0,
    this.label = '',
    this.startTime = '08:30',
    this.endTime = '10:00',
    this.dayName,
    required this.left,
    required this.right,
  });

  double get width => right - left;
  double get centerX => (left + right) / 2;

  bool containsX(double x) => x >= left && x <= right;

  @override
  String toString() => 'GridCol(${dayName ?? label}: ${left.toStringAsFixed(1)}..${right.toStringAsFixed(1)})';
}

/// Represents a row in the timetable grid (either a weekday or a time period).
class GridRow {
  final int index;
  final String label; // 'Monday', 'Tuesday', etc., or time range
  final String? dayName; // 'Monday' if days are rows
  final String startTime;
  final String endTime;
  final double top;
  final double bottom;

  const GridRow({
    this.index = 0,
    this.label = '',
    this.dayName,
    this.startTime = '08:30',
    this.endTime = '10:00',
    required this.top,
    required this.bottom,
  });

  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;

  bool containsY(double y) => y >= top && y <= bottom;

  @override
  String toString() => 'GridRow(${dayName ?? label}: ${top.toStringAsFixed(1)}..${bottom.toStringAsFixed(1)})';
}

/// Reconstructed geometric grid of the timetable.
class TimetableGrid {
  final List<GridColumn> columns;
  final List<GridRow> rows;
  final Rect tableBounds;
  final double headerBottomY;
  final double dayColumnRightX;
  final bool isDaysAsRows; // true for standard university timetable (Rows=Days, Cols=Lectures)

  const TimetableGrid({
    required this.columns,
    required this.rows,
    required this.tableBounds,
    required this.headerBottomY,
    double dayColumnRightX = 0.0,
    double? timeColumnRightX,
    this.isDaysAsRows = false,
  }) : dayColumnRightX = (timeColumnRightX ?? dayColumnRightX);

  double get timeColumnRightX => dayColumnRightX;

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
      return closest;
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
      return closest;
    }
    return null;
  }
}

/// Detects and reconstructs the structural columns (Lectures or Days) and rows (Days or Times) of a timetable.
class TimetableGridDetector {
  final DayDetector dayDetector;
  final TimeDetector timeDetector;

  const TimetableGridDetector({
    this.dayDetector = const DayDetector(),
    this.timeDetector = const TimeDetector(),
  });

  // Standard 5 lecture slots defined by university timetable
  static const List<(String, String, String)> standardLectures = [
    ('Lecture 1', '08:30', '10:00'),
    ('Lecture 2', '10:00', '11:30'),
    ('Lecture 3', '11:30', '13:15'),
    ('Lecture 4', '13:35', '15:00'),
    ('Lecture 5', '15:00', '16:30'),
  ];

  static const List<String> standardDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  /// Builds a [TimetableGrid] from spatial OCR results.
  TimetableGrid detectGrid(OcrResult ocrResult) {
    final lines = ocrResult.lines;
    if (lines.isEmpty) {
      return const TimetableGrid(
        columns: [],
        rows: [],
        tableBounds: Rect.zero,
        headerBottomY: 0,
        dayColumnRightX: 0,
        isDaysAsRows: true,
      );
    }

    final imgWidth = ocrResult.imageSize.width > 0 ? ocrResult.imageSize.width : 1000.0;
    final imgHeight = ocrResult.imageSize.height > 0 ? ocrResult.imageSize.height : 1000.0;

    // Determine grid orientation:
    // Check if day headers are arranged vertically on the left (standard university grid)
    // or horizontally across the top (transposed grid).
    final isDaysAsRows = _determineIfDaysAsRows(lines, imgWidth, imgHeight);

    if (isDaysAsRows) {
      return _detectUniversityGrid(lines, imgWidth, imgHeight);
    } else {
      return _detectTransposedGrid(lines, imgWidth, imgHeight);
    }
  }

  /// Determines whether the timetable uses standard university layout (Rows = Days, Columns = Lectures).
  bool _determineIfDaysAsRows(List<OcrTextLine> lines, double imgWidth, double imgHeight) {
    // Check for explicit "Lecture" headers
    final hasLectureHeader = lines.any((l) =>
        RegExp(r'\b(?:Lecture|Lec)\s*[1-5]\b', caseSensitive: false).hasMatch(l.text));
    if (hasLectureHeader) return true;

    // Check for standard lecture time headers across top (e.g. "8:30 - 10:00", "11:30 - 13:15")
    final hasStandardLectureTimes = lines.any((l) =>
        RegExp(r'\b(?:8:30|08:30|10:00|11:30|13:35|15:00)\s*[-–]\s*(?:10:00|11:30|13:15|15:00|16:30)\b').hasMatch(l.text));
    if (hasStandardLectureTimes) return true;

    // Check day labels positions
    final leftDayCandidates = <DayCandidate>[];
    final topDayCandidates = <DayCandidate>[];

    for (final line in lines) {
      final tokens = line.text.split(RegExp(r'[\s\-,/|]+'));
      for (final t in tokens) {
        final day = DayDetector.matchDay(t);
        if (day != null) {
          if (line.center.dx < imgWidth * 0.35) {
            leftDayCandidates.add(DayCandidate(dayName: day, boundingBox: line.boundingBox, rawText: line.text));
          }
          if (line.center.dy < imgHeight * 0.25) {
            topDayCandidates.add(DayCandidate(dayName: day, boundingBox: line.boundingBox, rawText: line.text));
          }
          break;
        }
      }
    }

    final uniqueLeftDays = leftDayCandidates.map((d) => d.dayName).toSet().length;
    final uniqueTopDays = topDayCandidates.map((d) => d.dayName).toSet().length;

    // If more days found on the left vertically, it's Days-as-Rows!
    if (uniqueLeftDays >= 2 && uniqueLeftDays >= uniqueTopDays) {
      return true;
    }

    // If day labels are spread horizontally across top with high unique count:
    if (uniqueTopDays >= 3 && uniqueLeftDays < 2) {
      return false; // Transposed layout
    }

    // Default to University timetable grid
    return true;
  }

  /// Detects the standard university timetable grid:
  /// - Rows: Monday, Tuesday, Wednesday, Thursday, Friday (5 rows)
  /// - Columns: Lecture 1 (08:30-10:00), Lecture 2 (10:00-11:30), Lecture 3 (11:30-13:15), Lecture 4 (13:35-15:00), Lecture 5 (15:00-16:30)
  TimetableGrid _detectUniversityGrid(List<OcrTextLine> lines, double imgWidth, double imgHeight) {
    // 1. Detect Day Labels on the left
    final dayCandidates = <DayCandidate>[];
    for (final line in lines) {
      if (line.center.dx > imgWidth * 0.35) continue; // Must be in the left column
      final tokens = line.text.split(RegExp(r'[\s\-,/|]+'));
      for (final t in tokens) {
        final day = DayDetector.matchDay(t);
        if (day != null) {
          dayCandidates.add(DayCandidate(
            dayName: day,
            boundingBox: line.boundingBox,
            rawText: line.text,
          ));
          break;
        }
      }
    }

    // Sort left day candidates top-to-bottom
    dayCandidates.sort((a, b) => a.center.dy.compareTo(b.center.dy));

    // Deduplicate by day name
    final Map<String, DayCandidate> detectedDays = {};
    for (final c in dayCandidates) {
      detectedDays.putIfAbsent(c.dayName, () => c);
    }

    // Determine Day column right boundary
    double dayColumnRightX = imgWidth * 0.14;
    if (dayCandidates.isNotEmpty) {
      dayColumnRightX = dayCandidates.map((c) => c.right).reduce(max) + 10;
      dayColumnRightX = dayColumnRightX.clamp(imgWidth * 0.08, imgWidth * 0.30);
    }

    // 2. Detect Lecture Headers across the top
    final headerCandidates = <OcrTextLine>[];
    for (final line in lines) {
      if (line.center.dx < dayColumnRightX - 10) continue; // In day column
      final text = line.text;
      final isLectureWord = RegExp(r'\b(?:Lecture|Lec)\s*[1-5]\b', caseSensitive: false).hasMatch(text);
      final isLectureTime = RegExp(r'\b\d{1,2}[:.]\d{2}\s*[-–]\s*\d{1,2}[:.]\d{2}\b').hasMatch(text);
      if (isLectureWord || isLectureTime) {
        headerCandidates.add(line);
      }
    }

    double headerBottomY = imgHeight * 0.15;
    if (headerCandidates.isNotEmpty) {
      headerBottomY = headerCandidates.map((l) => l.bottom).reduce(max) + 5;
    } else if (dayCandidates.isNotEmpty) {
      headerBottomY = dayCandidates.first.top - 5;
    }
    headerBottomY = headerBottomY.clamp(imgHeight * 0.08, imgHeight * 0.30);

    // Determine table boundaries
    final tableLeft = dayCandidates.isNotEmpty
        ? dayCandidates.map((c) => c.left).reduce(min) - 10
        : imgWidth * 0.02;

    final contentLines = lines.where((l) => l.center.dy > headerBottomY && l.center.dx > dayColumnRightX).toList();
    final allRightPoints = [
      if (headerCandidates.isNotEmpty) ...headerCandidates.map((l) => l.right),
      if (contentLines.isNotEmpty) ...contentLines.map((l) => l.right),
    ];
    final maxRight = allRightPoints.isNotEmpty ? allRightPoints.reduce(max) : imgWidth * 0.95;
    final tableRight = max(maxRight + 20, imgWidth * 0.95).clamp(dayColumnRightX + 100, imgWidth);

    final tableTop = headerBottomY;
    final tableBottom = dayCandidates.isNotEmpty
        ? max(dayCandidates.last.bottom + 20, contentLines.isNotEmpty ? contentLines.map((l) => l.bottom).reduce(max) + 15 : imgHeight * 0.85)
        : (contentLines.isNotEmpty ? contentLines.map((l) => l.bottom).reduce(max) + 15 : imgHeight * 0.85);

    // 3. Reconstruct 5 Day Rows (Monday .. Friday)
    final totalRowHeight = tableBottom - tableTop;
    final avgRowHeight = totalRowHeight / standardDays.length;

    final List<GridRow> rows = [];
    for (int i = 0; i < standardDays.length; i++) {
      final dayName = standardDays[i];
      double rTop = tableTop + i * avgRowHeight;
      double rBottom = tableTop + (i + 1) * avgRowHeight;

      // When day labels are detected, partition cleanly using the day label tops
      if (detectedDays.isNotEmpty) {
        if (i == 0) {
          rTop = tableTop;
        } else if (detectedDays.containsKey(dayName)) {
          rTop = detectedDays[dayName]!.top - 10;
        } else if (detectedDays.containsKey(standardDays[i - 1])) {
          rTop = detectedDays[standardDays[i - 1]]!.top + avgRowHeight;
        }

        if (i == standardDays.length - 1) {
          rBottom = tableBottom;
        } else if (detectedDays.containsKey(standardDays[i + 1])) {
          rBottom = detectedDays[standardDays[i + 1]]!.top - 10;
        } else if (detectedDays.containsKey(dayName)) {
          rBottom = detectedDays[dayName]!.top + avgRowHeight;
        }
      }

      rows.add(GridRow(
        index: i,
        label: dayName,
        dayName: dayName,
        startTime: standardLectures.first.$2,
        endTime: standardLectures.last.$3,
        top: rTop,
        bottom: rBottom,
      ));
    }

    // 4. Reconstruct 5 Lecture Columns (Lecture 1 .. 5)
    final Map<int, OcrTextLine> detectedLectureHeaders = {};
    for (final h in headerCandidates) {
      final m = RegExp(r'\b(?:Lecture|Lec)\s*([1-5])\b', caseSensitive: false).firstMatch(h.text);
      if (m != null) {
        final lecNum = int.tryParse(m.group(1)!) ?? 0;
        if (lecNum >= 1 && lecNum <= 5) {
          detectedLectureHeaders[lecNum - 1] = h;
        }
      }
    }

    final List<GridColumn> columns = [];
    final hasAllHeaders = detectedLectureHeaders.length == standardLectures.length;

    if (hasAllHeaders) {
      final colBoundaries = <double>[dayColumnRightX];
      for (int i = 0; i < standardLectures.length - 1; i++) {
        final currentH = detectedLectureHeaders[i]!;
        final nextH = detectedLectureHeaders[i + 1]!;
        colBoundaries.add((currentH.right + nextH.left) / 2);
      }
      colBoundaries.add(tableRight);

      for (int i = 0; i < standardLectures.length; i++) {
        final slot = standardLectures[i];
        columns.add(GridColumn(
          index: i,
          label: slot.$1,
          startTime: slot.$2,
          endTime: slot.$3,
          dayName: null,
          left: colBoundaries[i],
          right: colBoundaries[i + 1],
        ));
      }
    } else {
      final usableWidth = tableRight - dayColumnRightX;
      final avgColWidth = usableWidth / standardLectures.length;

      for (int i = 0; i < standardLectures.length; i++) {
        final slot = standardLectures[i];
        final colLeft = dayColumnRightX + i * avgColWidth;
        final colRight = (i == standardLectures.length - 1)
            ? tableRight
            : dayColumnRightX + (i + 1) * avgColWidth;

        columns.add(GridColumn(
          index: i,
          label: slot.$1,
          startTime: slot.$2,
          endTime: slot.$3,
          dayName: null,
          left: colLeft,
          right: colRight,
        ));
      }
    }

    return TimetableGrid(
      columns: columns,
      rows: rows,
      tableBounds: Rect.fromLTRB(tableLeft, tableTop - 40, tableRight, tableBottom),
      headerBottomY: headerBottomY,
      dayColumnRightX: dayColumnRightX,
      isDaysAsRows: true,
    );
  }

  /// Detects the transposed grid (Columns = Days, Rows = Times) for schedules with days across top.
  TimetableGrid _detectTransposedGrid(List<OcrTextLine> lines, double imgWidth, double imgHeight) {
    final dayCandidates = dayDetector.findDayCandidates(lines);
    final timeCandidates = timeDetector.findTimeCandidates(lines);

    double headerBottomY = 0;
    if (dayCandidates.isNotEmpty) {
      headerBottomY = dayCandidates.map((d) => d.bottom).reduce(max);
    }

    double timeColumnRightX = 0;
    if (timeCandidates.isNotEmpty) {
      final firstDayLeft = dayCandidates.isNotEmpty ? dayCandidates.first.left : imgWidth * 0.25;
      final leftTimes = timeCandidates.where((t) => t.left < firstDayLeft + 20).toList();
      if (leftTimes.isNotEmpty) {
        timeColumnRightX = leftTimes.map((t) => t.right).reduce(max);
      }
    }

    // Reconstruct columns
    final List<GridColumn> columns = [];
    if (dayCandidates.isEmpty) {
      final usableLeft = max(timeColumnRightX, imgWidth * 0.1);
      final colWidth = (imgWidth - usableLeft) / 5;
      for (int i = 0; i < standardDays.length; i++) {
        columns.add(GridColumn(
          index: i,
          label: standardDays[i],
          dayName: standardDays[i],
          startTime: '08:30',
          endTime: '17:00',
          left: usableLeft + i * colWidth,
          right: usableLeft + (i + 1) * colWidth,
        ));
      }
    } else {
      double avgWidth = 0;
      if (dayCandidates.length > 1) {
        avgWidth = (dayCandidates.last.center.dx - dayCandidates.first.center.dx) / (dayCandidates.length - 1);
      } else {
        avgWidth = (imgWidth - max(timeColumnRightX, dayCandidates.first.left * 0.5)) / 5;
      }

      for (int i = 0; i < dayCandidates.length; i++) {
        final current = dayCandidates[i];
        double colLeft = (i == 0)
            ? max(timeColumnRightX, current.left - (avgWidth * 0.2))
            : (dayCandidates[i - 1].right + current.left) / 2;
        double colRight = (i == dayCandidates.length - 1)
            ? min(imgWidth, current.right + (avgWidth * 0.2))
            : (current.right + dayCandidates[i + 1].left) / 2;

        columns.add(GridColumn(
          index: i,
          label: current.dayName,
          dayName: current.dayName,
          startTime: '08:30',
          endTime: '17:00',
          left: colLeft,
          right: colRight,
        ));
      }
    }

    // Reconstruct rows
    final List<GridRow> rows = [];
    if (timeCandidates.isEmpty) {
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
      final rowHeight = (imgHeight - usableTop) / defaultPeriods.length;

      for (int i = 0; i < defaultPeriods.length; i++) {
        rows.add(GridRow(
          index: i,
          label: '${defaultPeriods[i].$1}-${defaultPeriods[i].$2}',
          dayName: null,
          startTime: defaultPeriods[i].$1,
          endTime: defaultPeriods[i].$2,
          top: usableTop + i * rowHeight,
          bottom: usableTop + (i + 1) * rowHeight,
        ));
      }
    } else {
      final List<TimeSlotCandidate> uniqueTimes = [];
      for (final t in timeCandidates) {
        if (uniqueTimes.isEmpty || (t.top - uniqueTimes.last.top).abs() > 25) {
          uniqueTimes.add(t);
        }
      }

      double avgRowHeight = 60;
      if (uniqueTimes.length > 1) {
        avgRowHeight = (uniqueTimes.last.center.dy - uniqueTimes.first.center.dy) / (uniqueTimes.length - 1);
      }

      for (int i = 0; i < uniqueTimes.length; i++) {
        final current = uniqueTimes[i];
        final rowTop = (i == 0)
            ? max(headerBottomY, current.top - (avgRowHeight * 0.2))
            : (uniqueTimes[i - 1].bottom + current.top) / 2;
        final rowBottom = (i == uniqueTimes.length - 1)
            ? min(imgHeight, current.bottom + avgRowHeight)
            : (current.bottom + uniqueTimes[i + 1].top) / 2;

        String endTime = current.range.endTime;
        if (!current.range.hasExplicitEndTime && i + 1 < uniqueTimes.length) {
          endTime = uniqueTimes[i + 1].range.startTime;
        }

        rows.add(GridRow(
          index: i,
          label: '${current.range.startTime}-$endTime',
          dayName: null,
          startTime: current.range.startTime,
          endTime: endTime,
          top: rowTop,
          bottom: rowBottom,
        ));
      }
    }

    final leftBound = columns.isNotEmpty ? columns.first.left : timeColumnRightX;
    final rightBound = columns.isNotEmpty ? columns.last.right : imgWidth;
    final topBound = rows.isNotEmpty ? rows.first.top : headerBottomY;
    final bottomBound = rows.isNotEmpty ? rows.last.bottom : imgHeight;

    return TimetableGrid(
      columns: columns,
      rows: rows,
      tableBounds: Rect.fromLTRB(leftBound, topBound, rightBound, bottomBound),
      headerBottomY: headerBottomY,
      dayColumnRightX: timeColumnRightX,
      isDaysAsRows: false,
    );
  }
}
