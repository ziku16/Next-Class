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
  final List<OcrTextLine> lines;
  final Rect boundingBox;

  const TimetableCell({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.columnIndex,
    required this.rowIndex,
    required this.lines,
    required this.boundingBox,
  });

  bool get isEmpty => lines.isEmpty || lines.every((l) => l.text.trim().isEmpty);
  bool get isNotEmpty => !isEmpty;

  String get text => lines.map((l) => l.text.trim()).where((t) => t.isNotEmpty).join('\n');

  @override
  String toString() => 'Cell($dayOfWeek $startTime-$endTime, lines: ${lines.length})';
}

/// Assigns OCR text elements and lines into spatial timetable grid cells.
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

    // Assign each line to the best cell
    for (final line in ocrResult.lines) {
      final cleanText = line.text.trim();
      if (cleanText.isEmpty) continue;

      // Skip lines in header area or left time column
      if (line.bottom <= grid.headerBottomY && grid.headerBottomY > 0) {
        continue;
      }
      if (line.right <= grid.timeColumnRightX + 15 && grid.timeColumnRightX > 0) {
        continue;
      }

      // Check center point of line
      final centerX = line.center.dx;
      final centerY = line.center.dy;

      // Find column
      int? matchedCol;
      for (int c = 0; c < cols.length; c++) {
        if (cols[c].containsX(centerX)) {
          matchedCol = c;
          break;
        }
      }
      // Fallback column by overlap
      if (matchedCol == null) {
        for (int c = 0; c < cols.length; c++) {
          if (line.left < cols[c].right && line.right > cols[c].left) {
            matchedCol = c;
            break;
          }
        }
      }

      // Find row
      int? matchedRow;
      for (int r = 0; r < rows.length; r++) {
        if (rows[r].containsY(centerY)) {
          matchedRow = r;
          break;
        }
      }
      // Fallback row by overlap
      if (matchedRow == null) {
        for (int r = 0; r < rows.length; r++) {
          if (line.top < rows[r].bottom && line.bottom > rows[r].top) {
            matchedRow = r;
            break;
          }
        }
      }

      if (matchedCol != null && matchedRow != null) {
        cellBuckets[matchedCol]![matchedRow]!.add(line);
      }
    }

    // Build list of TimetableCell objects
    final List<TimetableCell> cells = [];
    for (int c = 0; c < cols.length; c++) {
      for (int r = 0; r < rows.length; r++) {
        final lines = cellBuckets[c]![r]!;
        // Sort cell lines top-to-bottom
        lines.sort((a, b) => a.top.compareTo(b.top));

        Rect bounds = Rect.fromLTRB(cols[c].left, rows[r].top, cols[c].right, rows[r].bottom);
        if (lines.isNotEmpty) {
          final l = lines.map((l) => l.left).reduce((a, b) => a < b ? a : b);
          final t = lines.map((l) => l.top).reduce((a, b) => a < b ? a : b);
          final ri = lines.map((l) => l.right).reduce((a, b) => a > b ? a : b);
          final bo = lines.map((l) => l.bottom).reduce((a, b) => a > b ? a : b);
          bounds = Rect.fromLTRB(l, t, ri, bo);
        }

        cells.add(TimetableCell(
          dayOfWeek: cols[c].dayName,
          startTime: rows[r].startTime,
          endTime: rows[r].endTime,
          columnIndex: c,
          rowIndex: r,
          lines: lines,
          boundingBox: bounds,
        ));
      }
    }

    return cells;
  }
}
