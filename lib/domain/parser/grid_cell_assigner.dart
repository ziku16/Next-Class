import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'day_detector.dart';
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
  final bool isDaysAsRows;

  const TimetableCell({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.columnIndex,
    required this.rowIndex,
    required this.timeSlotIndex,
    required this.lines,
    required this.boundingBox,
    this.isDaysAsRows = true,
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

    // Decompose lines that span multiple columns (e.g. OCR merged two columns together)
    final List<OcrTextLine> decomposedLines = [];
    for (final line in ocrResult.lines) {
      final cleanText = line.text.trim();
      if (cleanText.isEmpty) continue;

      if (TimetableGridDetector.footerPattern.hasMatch(cleanText)) continue;
      if (RegExp(r'\b(?:semester|university\s*weekly|class\s*schedule)\b', caseSensitive: false).hasMatch(cleanText)) {
        continue;
      }

      // Check if elements span multiple distinct columns
      if (line.elements.length > 1) {
        final Map<int, List<OcrTextElement>> colElements = {};
        for (final elem in line.elements) {
          int? colIdx;
          for (int c = 0; c < cols.length; c++) {
            if (cols[c].containsX(elem.center.dx)) {
              colIdx = c;
              break;
            }
          }
          if (colIdx != null) {
            colElements.putIfAbsent(colIdx, () => []).add(elem);
          }
        }

        if (colElements.keys.length > 1) {
          // Line spans multiple columns! Split it cleanly per column
          for (final entry in colElements.entries) {
            final elems = entry.value;
            final text = elems.map((e) => e.text).join(' ');
            final l = elems.map((e) => e.boundingBox.left).reduce((a, b) => a < b ? a : b);
            final t = elems.map((e) => e.boundingBox.top).reduce((a, b) => a < b ? a : b);
            final r = elems.map((e) => e.boundingBox.right).reduce((a, b) => a > b ? a : b);
            final bo = elems.map((e) => e.boundingBox.bottom).reduce((a, b) => a > b ? a : b);
            decomposedLines.add(OcrTextLine(
              text: text,
              boundingBox: Rect.fromLTRB(l, t, r, bo),
              elements: elems,
            ));
          }
          continue;
        }
      }

      decomposedLines.add(line);
    }

    // Assign each line to the best cell based on overlap geometry
    for (final line in decomposedLines) {
      final cleanText = line.text.trim();
      if (cleanText.isEmpty) continue;

      // Filter out footer strings anywhere in the image
      if (TimetableGridDetector.footerPattern.hasMatch(cleanText)) {
        continue;
      }

      // Filter out global header title metadata
      if (RegExp(r'\b(?:semester|university\s*weekly|class\s*schedule)\b', caseSensitive: false).hasMatch(cleanText)) {
        continue;
      }

      // 1. Skip lines in the header area across the top
      if (line.bottom <= grid.headerBottomY && grid.headerBottomY > 0) {
        continue;
      }

      // If Days-as-Rows, also skip explicit Lecture header tokens
      if (grid.isDaysAsRows) {
        if (RegExp(r'^(?:Lecture|Lec)\s*[1-9]$', caseSensitive: false).hasMatch(cleanText)) {
          continue;
        }
        if (RegExp(r'^\d{1,2}[:.]\d{2}\s*[-–]\s*\d{1,2}[:.]\d{2}$').hasMatch(cleanText) &&
            line.top < (grid.rows.isNotEmpty ? grid.rows.first.top + 30 : 150)) {
          continue;
        }
      }

      // 2. Skip lines in the day column on the left or matching day names
      if (line.right <= grid.dayColumnRightX && grid.dayColumnRightX > 0) {
        continue;
      }
      if (grid.isDaysAsRows && grid.columns.isNotEmpty && line.center.dx < grid.columns.first.left) {
        continue;
      }
      if (DayDetector.matchDay(cleanText) != null &&
          line.center.dx < (grid.columns.isNotEmpty ? grid.columns.first.left + 20 : 150)) {
        continue;
      }

      // 3. Skip lines outside grid bounds (above top row, below bottom row, or outside side columns)
      final centerX = line.center.dx;
      final centerY = line.center.dy;
      if (grid.rows.isNotEmpty) {
        if (centerY < grid.rows.first.top || centerY > grid.rows.last.bottom) {
          continue;
        }
      }
      if (grid.columns.isNotEmpty) {
        if (centerX < grid.columns.first.left || centerX > grid.columns.last.right) {
          continue;
        }
      }

      // 4. Find target Column index using maximum horizontal overlap (fallback to containsX)
      int? matchedColIdx;
      double maxOverlapX = 0;
      for (int c = 0; c < cols.length; c++) {
        final col = cols[c];
        final overlapX = (line.right < col.left || line.left > col.right)
            ? 0.0
            : (col.right < line.right ? col.right : line.right) - (col.left > line.left ? col.left : line.left);
        if (overlapX > maxOverlapX) {
          maxOverlapX = overlapX;
          matchedColIdx = c;
        }
      }
      if (matchedColIdx == null && cols.isNotEmpty) {
        for (int c = 0; c < cols.length; c++) {
          if (cols[c].containsX(centerX)) {
            matchedColIdx = c;
            break;
          }
        }
      }
      if (matchedColIdx == null || matchedColIdx < 0) continue;

      // 5. Find target Row index using maximum vertical overlap (fallback to containsY)
      int? matchedRowIdx;
      double maxOverlapY = 0;
      for (int r = 0; r < rows.length; r++) {
        final row = rows[r];
        final overlapY = (line.bottom < row.top || line.top > row.bottom)
            ? 0.0
            : (row.bottom < line.bottom ? row.bottom : line.bottom) - (row.top > line.top ? row.top : line.top);
        if (overlapY > maxOverlapY) {
          maxOverlapY = overlapY;
          matchedRowIdx = r;
        }
      }
      if (matchedRowIdx == null && rows.isNotEmpty) {
        for (int r = 0; r < rows.length; r++) {
          if (rows[r].containsY(centerY)) {
            matchedRowIdx = r;
            break;
          }
        }
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
          isDaysAsRows: grid.isDaysAsRows,
        ));
      }
    }

    if (kDebugMode) {
      for (final cell in cells) {
        if (cell.isNotEmpty) {
          debugPrint('[NextClass Grid] CELL ${cell.dayOfWeek} / Slot ${cell.timeSlotIndex}: ${cell.lines.map((l) => l.text.trim()).join(" | ")}');
        }
      }
    }

    return cells;
  }
}
