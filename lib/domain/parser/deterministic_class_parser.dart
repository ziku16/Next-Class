import '../../data/models/class_item.dart';
import 'grid_cell_assigner.dart';
import 'time_detector.dart';

/// Extracted intermediate class details before finalizing into [ClassItem].
class ParsedClassCandidate {
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String subject;
  final String? room;
  final String? teacher;
  final bool isAiUnsure;
  final int columnIndex;
  final int startRowIndex;
  final int endRowIndex;

  const ParsedClassCandidate({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.subject,
    this.room,
    this.teacher,
    this.isAiUnsure = false,
    required this.columnIndex,
    required this.startRowIndex,
    required this.endRowIndex,
  });

  ParsedClassCandidate copyWith({
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    String? subject,
    String? room,
    String? teacher,
    bool? isAiUnsure,
    int? columnIndex,
    int? startRowIndex,
    int? endRowIndex,
  }) {
    return ParsedClassCandidate(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      subject: subject ?? this.subject,
      room: room ?? this.room,
      teacher: teacher ?? this.teacher,
      isAiUnsure: isAiUnsure ?? this.isAiUnsure,
      columnIndex: columnIndex ?? this.columnIndex,
      startRowIndex: startRowIndex ?? this.startRowIndex,
      endRowIndex: endRowIndex ?? this.endRowIndex,
    );
  }
}

/// Deterministic parser that analyzes lines within timetable cells, extracting
/// subject, teacher, room, time, merging multi-row classes, and validating confidence.
class DeterministicClassParser {
  final TimeDetector timeDetector;

  const DeterministicClassParser({
    this.timeDetector = const TimeDetector(),
  });

  // Regex patterns for Teacher identification
  static final RegExp _teacherPrefixRegex = RegExp(
    r'^(?:Dr\.?|Prof\.?|Professor|Mr\.?|Ms\.?|Mrs\.?|Engr\.?|Sir|Madam|Lecturer|Instructor)\s+([A-Za-z\s\.\-]+)$',
    caseSensitive: false,
  );

  static final RegExp _teacherLabeledRegex = RegExp(
    r'^(?:Teacher|Faculty|Instructor|Prof|Lecturer)\s*[:\-]\s*(.+)$',
    caseSensitive: false,
  );

  // Regex patterns for Room identification
  static final RegExp _roomLabeledRegex = RegExp(
    r'^(?:Room|Rm\.?|Lab|Laboratory|Hall|LH|LT|CR)\s*[:\-]?\s*([A-Za-z0-9\s\-]+)$',
    caseSensitive: false,
  );

  static final RegExp _roomCodeRegex = RegExp(
    r'^(?:(?:Room|Rm\.?|Lab|Hall|LH|LT|CR)\s*[-:]?\s*)?([A-Z]{1,2}[-\s]?\d{1,3}[A-Z]?|Lab\s*[-:]?\s*\d+|Hall\s*[-:]?\s*\d+)$',
    caseSensitive: false,
  );

  /// Parses a collection of grid cells into structured [ClassItem]s.
  List<ClassItem> parseCells(List<TimetableCell> cells) {
    if (cells.isEmpty) return [];

    // 1. Group cells by day / column index
    final Map<int, List<TimetableCell>> columnMap = {};
    for (final cell in cells) {
      columnMap.putIfAbsent(cell.columnIndex, () => []).add(cell);
    }

    final List<ParsedClassCandidate> rawCandidates = [];

    // 2. Parse individual cell contents
    for (final colIndex in columnMap.keys) {
      final colCells = columnMap[colIndex]!;
      colCells.sort((a, b) => a.rowIndex.compareTo(b.rowIndex));

      for (final cell in colCells) {
        if (cell.isEmpty) continue;

        final candidate = _parseSingleCell(cell);
        if (candidate != null) {
          rawCandidates.add(candidate);
        }
      }
    }

    // 3. Merge consecutive / multi-row classes in the same column
    final mergedCandidates = _mergeMultiRowClasses(rawCandidates);

    // 4. Convert to domain ClassItem with color indices and unique IDs
    final List<ClassItem> result = [];
    final Map<String, int> subjectColorMap = {};
    int colorCounter = 0;

    for (int i = 0; i < mergedCandidates.length; i++) {
      final cand = mergedCandidates[i];
      final normSubject = cand.subject.trim();
      final key = normSubject.toLowerCase();

      final colorIndex = subjectColorMap.putIfAbsent(key, () {
        final c = colorCounter % 8;
        colorCounter++;
        return c;
      });

      result.add(ClassItem(
        id: 'scanned_cls_${cand.dayOfWeek.substring(0, 3).toLowerCase()}_$i',
        subject: normSubject,
        subjectColorIndex: colorIndex,
        dayOfWeek: cand.dayOfWeek,
        startTime: cand.startTime,
        endTime: cand.endTime,
        room: cand.room?.trim().isEmpty ?? true ? null : cand.room!.trim(),
        teacher: cand.teacher?.trim().isEmpty ?? true ? null : cand.teacher!.trim(),
        isAiUnsure: cand.isAiUnsure,
      ));
    }

    // Sort by day order, then start time
    result.sort((a, b) {
      final d = a.dayIndex.compareTo(b.dayIndex);
      if (d != 0) return d;
      return a.startMinutes.compareTo(b.startMinutes);
    });

    return result;
  }

  /// Parses text lines of a single cell into a [ParsedClassCandidate].
  ParsedClassCandidate? _parseSingleCell(TimetableCell cell) {
    String? subject;
    String? teacher;
    String? room;
    String startTime = cell.startTime;
    String endTime = cell.endTime;
    bool isAiUnsure = false;

    final unassignedLines = <String>[];

    for (final lineObj in cell.lines) {
      String line = lineObj.text.trim();
      if (line.isEmpty) continue;

      // Filter out pure noise / separator artifacts (e.g. "---", "___", "|")
      if (RegExp(r'^[\-_=|\.]{2,}$').hasMatch(line)) continue;

      // Check if line contains internal time range (e.g. "09:30 - 10:20")
      final range = timeDetector.parseTimeRange(line);
      if (range != null && range.hasExplicitEndTime) {
        startTime = range.startTime;
        endTime = range.endTime;
        // Strip the time from the line to see if remaining text is useful
        final stripped = line
            .replaceAll(RegExp(r'\b\d{1,2}[:.]\d{2}\s*(am|pm)?\s*[-–—to~]+\s*\d{1,2}[:.]\d{2}\s*(am|pm)?', caseSensitive: false), '')
            .trim();
        if (stripped.length > 2) {
          line = stripped;
        } else {
          continue;
        }
      }

      // Check Teacher
      final teacherLabelMatch = _teacherLabeledRegex.firstMatch(line);
      if (teacherLabelMatch != null) {
        teacher = teacherLabelMatch.group(1)?.trim();
        continue;
      }

      final teacherPrefixMatch = _teacherPrefixRegex.firstMatch(line);
      if (teacherPrefixMatch != null) {
        teacher = line.trim();
        continue;
      }

      // Check Room
      final roomLabelMatch = _roomLabeledRegex.firstMatch(line);
      if (roomLabelMatch != null) {
        room = line.trim();
        continue;
      }

      final roomCodeMatch = _roomCodeRegex.firstMatch(line);
      if (roomCodeMatch != null && line.length <= 15) {
        room = line.trim();
        continue;
      }

      // Check if line is inline combination like "Physics (Room B-12)"
      final parenMatch = RegExp(r'^(.+?)\s*\(([^)]+)\)$').firstMatch(line);
      if (parenMatch != null) {
        final mainPart = parenMatch.group(1)!.trim();
        final inside = parenMatch.group(2)!.trim();

        // Check if inside is room or teacher
        if (_roomCodeRegex.hasMatch(inside) || _roomLabeledRegex.hasMatch(inside)) {
          room = inside;
          unassignedLines.add(mainPart);
          continue;
        } else if (_teacherPrefixRegex.hasMatch(inside)) {
          teacher = inside;
          unassignedLines.add(mainPart);
          continue;
        }
      }

      unassignedLines.add(line);
    }

    // Subject extraction from unassigned lines
    if (unassignedLines.isNotEmpty) {
      // Top line is usually the subject
      subject = unassignedLines.first.replaceAll(RegExp(r'^[|#\-\*\s]+|[|#\-\*\s]+$'), '').trim();

      // If secondary unassigned lines exist, check if one looks like teacher or room
      for (int i = 1; i < unassignedLines.length; i++) {
        final sec = unassignedLines[i].trim();
        if (teacher == null && _looksLikePersonName(sec)) {
          teacher = sec;
        } else if (room == null && _looksLikeRoom(sec)) {
          room = sec;
        } else if (subject != null && subject.length < 25) {
          // Append code if short (e.g. "Data Structures" + "CS201")
          subject = '$subject ($sec)';
        }
      }
    }

    if (subject == null || subject.isEmpty) {
      return null; // Empty cell
    }

    // Clean subject formatting
    subject = _cleanSubject(subject);
    if (subject.isEmpty) return null;

    // Validation & confidence scoring
    if (subject.length < 3) {
      isAiUnsure = true;
    }
    if (room == null || room.isEmpty) {
      // Room missing is common, but flag for user review
      isAiUnsure = true;
    }
    if (teacher == null || teacher.isEmpty) {
      // Teacher missing can also be noted
    }

    return ParsedClassCandidate(
      dayOfWeek: cell.dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      subject: subject,
      room: room,
      teacher: teacher,
      isAiUnsure: isAiUnsure,
      columnIndex: cell.columnIndex,
      startRowIndex: cell.rowIndex,
      endRowIndex: cell.rowIndex,
    );
  }

  /// Merges consecutive classes in the same day column if they represent a single multi-row class.
  List<ParsedClassCandidate> _mergeMultiRowClasses(List<ParsedClassCandidate> candidates) {
    if (candidates.length <= 1) return candidates;

    final List<ParsedClassCandidate> merged = [];

    // Group by column / day
    final Map<int, List<ParsedClassCandidate>> byCol = {};
    for (final cand in candidates) {
      byCol.putIfAbsent(cand.columnIndex, () => []).add(cand);
    }

    for (final colIndex in byCol.keys) {
      final list = byCol[colIndex]!;
      list.sort((a, b) => a.startRowIndex.compareTo(b.startRowIndex));

      int i = 0;
      while (i < list.length) {
        var current = list[i];

        // Check if subsequent candidate is contiguous and shares the same subject or is a lab continuation
        while (i + 1 < list.length) {
          final next = list[i + 1];

          // Are they in consecutive rows?
          final isConsecutive = next.startRowIndex == current.endRowIndex + 1;
          // Do they have the same normalized subject or is next marked as continuation/lab?
          final isSameSubject = _normalizeSubjectForComparison(current.subject) ==
              _normalizeSubjectForComparison(next.subject);

          if (isConsecutive && isSameSubject) {
            // Merge into one longer class
            current = current.copyWith(
              endTime: next.endTime,
              endRowIndex: next.endRowIndex,
              room: current.room ?? next.room,
              teacher: current.teacher ?? next.teacher,
              // If either was verified, retain verification
              isAiUnsure: current.isAiUnsure && next.isAiUnsure,
            );
            i++; // Skip merged next
          } else {
            break;
          }
        }

        merged.add(current);
        i++;
      }
    }

    return merged;
  }

  bool _looksLikePersonName(String s) {
    // 2-3 capitalized words without digits (e.g. "Sara Ahmed", "Miller")
    if (RegExp(r'\d').hasMatch(s)) return false;
    final words = s.split(RegExp(r'\s+'));
    return words.isNotEmpty && words.length <= 4 && words.every((w) => w.isNotEmpty && w[0] == w[0].toUpperCase());
  }

  bool _looksLikeRoom(String s) {
    return RegExp(r'\d').hasMatch(s) && s.length <= 12;
  }

  String _cleanSubject(String s) {
    return s
        .replaceAll(RegExp(r'^[^\w]+|[^\w\)]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeSubjectForComparison(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
