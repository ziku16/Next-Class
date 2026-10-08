import 'dart:ui';
import 'ocr_models.dart';
import 'timetable_grid_detector.dart';

/// Represents a single cell in the timetable grid, holding the extracted text lines.
class TimetableCell {
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final int columnIndex;
  final int rowIndex;
  final int timeSlotIndex; // Index along the time axis (for merging multi-period classes)
  final List<OcrTextLine> lines;
  final Rect boundingBox;

  const TimetableCell({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.columnIndex,
    required this.rowIndex,
    required this.timeSlotIndex,
    required this.lines,
    required this.boundingBox,
  });

  bool get isEmpty => lines.isEmpty || lines.every((l) => l.text.trim().isEmpty);
  bool get isNotEmpty => !isEmpty;

  String get text => lines.map((l) => l.text.trim()).where((t) => t.isNotEmpty).join('\n');

  @override
  String toString() => 'Cell($dayOfWeek $startTime-$endTime, lines: ${lines.length})';
}

/// Assigns OCR text elements and lines into spatial timetable grid cells using 2D coordinates.
class GridCellAssigner {
  const GridCellAssigner();

  /// Assigns [ocrResult] lines into a 2D matrix of [TimetableCell]s based on [grid].
  List<TimetableCell> assignLinesToCells({
    required OcrResult ocrResult,
    required TimetableGrid grid,
  }) {
    if (!grid.isValid) return [];

    final cols = grid.columns;
    final rows = grid.rows;

    // Initialize 2D grid of cell buckets: (colIndex, rowIndex) -> List<OcrTextLine>
    final Map<int, Map<int, List<OcrTextLine>>> cellBuckets = {};
    for (int c = 0; c < cols.length; c++) {
      cellBuckets[c] = {};
      for (int r = 0; r < rows.length; r++) {
        cellBuckets[c]![r] = [];
      }
    }

    // Assign each line to the best cell based on its center coordinates
    for (final line in ocrResult.lines) {
      final cleanText = line.text.trim();
      if (cleanText.isEmpty) continue;

      // 1. Skip lines in the header area across the top
      if (line.bottom <= grid.headerBottomY && grid.headerBottomY > 0) {
        continue;
      }

      // If Days-as-Rows, also skip explicit Lecture header tokens
      if (grid.isDaysAsRows) {
        if (RegExp(r'^(?:Lecture|Lec)\s*[1-5]$', caseSensitive: false).hasMatch(cleanText)) {
          continue;
        }
        if (RegExp(r'^\d{1,2}[:.]\d{2}\s*[-–]\s*\d{1,2}[:.]\d{2}$').hasMatch(cleanText) &&
            line.top < (grid.rows.isNotEmpty ? grid.rows.first.top + 30 : 150)) {
          continue;
        }
      }

      // 2. Skip lines in the day column on the left
      if (line.right <= grid.dayColumnRightX && grid.dayColumnRightX > 0) {
        continue;
      }
      if (grid.isDaysAsRows && line.center.dx < grid.columns.first.left) {
        continue;
      }

      // 3. Find target Column index using centerX coordinate
      final centerX = line.center.dx;
      int? matchedColIdx;
      for (int c = 0; c < cols.length; c++) {
        if (cols[c].containsX(centerX)) {
          matchedColIdx = c;
          break;
        }
      }
      if (matchedColIdx == null) {
        final col = grid.findColumn(centerX);
        if (col != null) matchedColIdx = cols.indexOf(col);
      }
      if (matchedColIdx == null || matchedColIdx < 0) continue;

      // 4. Find target Row index using centerY coordinate
      final centerY = line.center.dy;
      int? matchedRowIdx;
      for (int r = 0; r < rows.length; r++) {
        if (rows[r].containsY(centerY)) {
          matchedRowIdx = r;
          break;
        }
      }
      if (matchedRowIdx == null) {
        final row = grid.findRow(centerY);
        if (row != null) matchedRowIdx = rows.indexOf(row);
      }
      if (matchedRowIdx == null || matchedRowIdx < 0) continue;

      cellBuckets[matchedColIdx]![matchedRowIdx]!.add(line);
    }

    // Build list of TimetableCell objects
    final List<TimetableCell> cells = [];
    for (int c = 0; c < cols.length; c++) {
      for (int r = 0; r < rows.length; r++) {
        final lines = cellBuckets[c]![r]!;
        // Sort cell lines strictly top-to-bottom
        lines.sort((a, b) => a.top.compareTo(b.top));

        Rect bounds = Rect.fromLTRB(cols[c].left, rows[r].top, cols[c].right, rows[r].bottom);
        if (lines.isNotEmpty) {
          final l = lines.map((l) => l.left).reduce((a, b) => a < b ? a : b);
          final t = lines.map((l) => l.top).reduce((a, b) => a < b ? a : b);
          final ri = lines.map((l) => l.right).reduce((a, b) => a > b ? a : b);
          final bo = lines.map((l) => l.bottom).reduce((a, b) => a > b ? a : b);
          bounds = Rect.fromLTRB(l, t, ri, bo);
        }

        // Determine day and times based on grid orientation
        final String cellDay;
        final String cellStart;
        final String cellEnd;
        final int timeSlotIdx;

        if (grid.isDaysAsRows) {
          cellDay = rows[r].dayName ?? rows[r].label;
          cellStart = cols[c].startTime;
          cellEnd = cols[c].endTime;
          timeSlotIdx = c; // Column is the time slot in university grid
        } else {
          cellDay = cols[c].dayName ?? cols[c].label;
          cellStart = rows[r].startTime;
          cellEnd = rows[r].endTime;
          timeSlotIdx = r; // Row is the time slot in transposed grid
        }

        cells.add(TimetableCell(
          dayOfWeek: cellDay,
          startTime: cellStart,
          endTime: cellEnd,
          columnIndex: c,
          rowIndex: r,
          timeSlotIndex: timeSlotIdx,
          lines: lines,
          boundingBox: bounds,
        ));
      }
    }

    return cells;
  }
}
