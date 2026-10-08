import '../../data/models/class_item.dart';
import 'grid_cell_assigner.dart';
import 'ocr_models.dart';
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
  final int rowIndex;
  final int startSlotIndex;
  final int endSlotIndex;

  const ParsedClassCandidate({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.subject,
    this.room,
    this.teacher,
    this.isAiUnsure = false,
    required this.columnIndex,
    required this.rowIndex,
    required this.startSlotIndex,
    required this.endSlotIndex,
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
    int? rowIndex,
    int? startSlotIndex,
    int? endSlotIndex,
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
      rowIndex: rowIndex ?? this.rowIndex,
      startSlotIndex: startSlotIndex ?? this.startSlotIndex,
      endSlotIndex: endSlotIndex ?? this.endSlotIndex,
    );
  }
}

/// Deterministic parser that analyzes lines within timetable cells, extracting
/// subject, teacher, room, splitting dual labs within a single cell, and merging multi-period classes.
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
    r'^(?:Room|Rm\.?|Lab|Laboratory|Hall|LH|LT|CR)\s*[:\-]?\s*([A-Za-z0-9\s\.\(\)\-]+)$',
    caseSensitive: false,
  );

  static final RegExp _roomCodeRegex = RegExp(
    r'^(?:(?:Room|Rm\.?|Lab|Hall|LH|LT|CR)\s*[-:]?\s*)?([A-Z]{1,2}[-\s]?\d{1,3}[A-Z]?|Lab\s*[-:]?\s*\d+|Hall\s*[-:]?\s*\d+|[A-Z]{1,3}\s+C\.Lab\s*[0-9A-Za-z\(\)\s]*)$',
    caseSensitive: false,
  );

  // Lab Group identification (e.g. "Lab Group 1", "Lab Group 2", "Group 1")
  static final RegExp _labGroupRegex = RegExp(
    r'\b(?:Lab\s*Group|Group)\s*([0-9A-Za-z]+)\b',
    caseSensitive: false,
  );

  /// Parses a collection of grid cells into structured [ClassItem]s.
  List<ClassItem> parseCells(List<TimetableCell> cells) {
    if (cells.isEmpty) return [];

    final List<ParsedClassCandidate> rawCandidates = [];

    // Parse each cell, splitting multiple stacked class/lab blocks if present
    for (final cell in cells) {
      if (cell.isEmpty) continue;

      // Filter pure noise lines before splitting
      final validLines = cell.lines.where((l) {
        final t = l.text.trim();
        return t.isNotEmpty && !RegExp(r'^[\-_=|\.]{2,}$').hasMatch(t);
      }).toList();

      if (validLines.isEmpty) continue;

      final blocks = _splitLinesIntoClassBlocks(validLines);
      for (final blockLines in blocks) {
        final candidate = _parseBlock(blockLines, cell);
        if (candidate != null) {
          rawCandidates.add(candidate);
        }
      }
    }

    // Merge consecutive classes spanning multiple slots on the same day
    final mergedCandidates = _mergeConsecutiveClasses(rawCandidates);

    // Convert to domain ClassItem with color indices and unique IDs
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

    // Sort chronologically by day order, then start time
    result.sort((a, b) {
      final d = a.dayIndex.compareTo(b.dayIndex);
      if (d != 0) return d;
      return a.startMinutes.compareTo(b.startMinutes);
    });

    return result;
  }

  /// Splits a cell's lines into 1 or 2 distinct class blocks if multiple stacked classes/labs exist.
  List<List<OcrTextLine>> _splitLinesIntoClassBlocks(List<OcrTextLine> lines) {
    if (lines.length <= 1) return [lines];

    final avgLineHeight = lines.map((l) => l.height).reduce((a, b) => a + b) / lines.length;
    final List<List<OcrTextLine>> blocks = [];
    List<OcrTextLine> currentBlock = [lines.first];

    bool currentBlockHasLabHeading = _isLabHeading(lines.first.text);
    bool currentBlockHasTeacherPrefix = _hasTeacherPrefix(lines.first.text);
    bool currentBlockHasLabGroup = _labGroupRegex.hasMatch(lines.first.text);

    for (int i = 1; i < lines.length; i++) {
      final currentLine = lines[i];
      final prevLine = lines[i - 1];
      final text = currentLine.text.trim();

      final gap = currentLine.top - prevLine.bottom;
      final isLargeGap = gap > (avgLineHeight * 1.3).clamp(18.0, 50.0);

      final isLabHeading = _isLabHeading(text);
      final hasTeacherPrefix = _hasTeacherPrefix(text);
      final hasLabGroup = _labGroupRegex.hasMatch(text);

      // Conditions indicating a new stacked class entry inside this cell:
      bool isNewBlock = false;

      // 1. A new lab heading (e.g. "DS(Lab)") when current block already has a lab heading or teacher
      if (isLabHeading && (currentBlockHasLabHeading || currentBlockHasTeacherPrefix || currentBlock.length >= 2)) {
        isNewBlock = true;
      }
      // 2. A second teacher prefix (e.g. Mr. Bilal Bukhari) when current block already has a teacher prefix
      else if (hasTeacherPrefix && currentBlockHasTeacherPrefix) {
        isNewBlock = true;
      }
      // 3. A second Lab Group (e.g. Lab Group 2) when current block already has a lab group
      else if (hasLabGroup && currentBlockHasLabGroup) {
        isNewBlock = true;
      }
      // 4. Large vertical gap and current block already has at least 3 lines
      else if (isLargeGap && currentBlock.length >= 3 && (isLabHeading || hasTeacherPrefix)) {
        isNewBlock = true;
      }

      if (isNewBlock) {
        blocks.add(currentBlock);
        currentBlock = [currentLine];
        currentBlockHasLabHeading = isLabHeading;
        currentBlockHasTeacherPrefix = hasTeacherPrefix;
        currentBlockHasLabGroup = hasLabGroup;
      } else {
        currentBlock.add(currentLine);
        if (isLabHeading) currentBlockHasLabHeading = true;
        if (hasTeacherPrefix) currentBlockHasTeacherPrefix = true;
        if (hasLabGroup) currentBlockHasLabGroup = true;
      }
    }

    if (currentBlock.isNotEmpty) {
      blocks.add(currentBlock);
    }

    return blocks;
  }

  /// Checks if text looks like a lab heading (e.g. "DBS(Lab)", "DS(Lab)", "DBS (Lab)", "CS(Lab)")
  bool _isLabHeading(String text) {
    return RegExp(r'\((?:Lab|lab)\)', caseSensitive: false).hasMatch(text) ||
        RegExp(r'\b[A-Za-z]{2,5}\s*\((?:Lab|lab)\)', caseSensitive: false).hasMatch(text);
  }

  /// Checks if text starts with an explicit teacher prefix or label
  bool _hasTeacherPrefix(String text) {
    return _teacherPrefixRegex.hasMatch(text) || _teacherLabeledRegex.hasMatch(text);
  }

  /// Parses text lines of a single class block within a cell into a [ParsedClassCandidate].
  ParsedClassCandidate? _parseBlock(List<OcrTextLine> lines, TimetableCell cell) {
    if (lines.isEmpty) return null;

    String? subject;
    String? teacher;
    String? room;
    String? labGroup;
    String startTime = cell.startTime;
    String endTime = cell.endTime;
    bool isAiUnsure = false;

    final unassignedLines = <String>[];

    for (final lineObj in lines) {
      String line = lineObj.text.trim();
      if (line.isEmpty) continue;
      if (RegExp(r'^[\-_=|\.]{2,}$').hasMatch(line)) continue;

      // 1. Check if line contains internal time range (e.g. "08:15 - 09:45")
      final range = timeDetector.parseTimeRange(line);
      if (range != null && range.hasExplicitEndTime) {
        startTime = range.startTime;
        endTime = range.endTime;
        final stripped = line
            .replaceAll(RegExp(r'\b\d{1,2}[:.]\d{2}\s*(am|pm)?\s*[-–—to~]+\s*\d{1,2}[:.]\d{2}\s*(am|pm)?', caseSensitive: false), '')
            .trim();
        if (stripped.length > 2) {
          line = stripped;
        } else {
          continue;
        }
      }

      // 2. Check Lab Group (e.g. "Lab Group 1", "Group 2")
      final labGroupMatch = _labGroupRegex.firstMatch(line);
      if (labGroupMatch != null) {
        labGroup = labGroupMatch.group(0)?.trim();
        // If line is ONLY the lab group, consume it
        if (line.replaceAll(_labGroupRegex, '').trim().length <= 2) {
          continue;
        }
      }

      // 3. Check Teacher (Prefix or Label)
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

      // 4. Check Room / Lab
      final roomLabelMatch = _roomLabeledRegex.firstMatch(line);
      if (roomLabelMatch != null) {
        room = line.trim();
        continue;
      }

      final roomCodeMatch = _roomCodeRegex.firstMatch(line);
      if (roomCodeMatch != null && line.length <= 22) {
        room = line.trim();
        continue;
      }

      // 5. Check if line is inline combination like "Physics (Room B-12)"
      final parenMatch = RegExp(r'^(.+?)\s*\(([^)]+)\)$').firstMatch(line);
      if (parenMatch != null && !_isLabHeading(line)) {
        final mainPart = parenMatch.group(1)!.trim();
        final inside = parenMatch.group(2)!.trim();

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

    // 6. Extract Subject and secondary unassigned lines
    if (unassignedLines.isNotEmpty) {
      // First unassigned line is the Subject
      subject = unassignedLines.first.replaceAll(RegExp(r'^[|#\-\*\s]+|[|#\-\*\s]+$'), '').trim();

      // Check remaining unassigned lines for teacher or room
      for (int i = 1; i < unassignedLines.length; i++) {
        final sec = unassignedLines[i].trim();
        if (teacher == null && _looksLikePersonName(sec)) {
          teacher = sec;
        } else if (room == null && _looksLikeRoom(sec)) {
          room = sec;
        } else if (subject != null && subject.length < 25 && !sec.startsWith('(')) {
          subject = '$subject ($sec)';
        }
      }
    }

    if (subject == null || subject.isEmpty) {
      return null; // Empty block
    }

    // 7. Clean and normalize Subject
    subject = _cleanSubject(subject);
    if (subject.isEmpty) return null;

    // 8. Combine Room and Lab Group
    if (labGroup != null && labGroup.isNotEmpty) {
      if (room != null && room.isNotEmpty) {
        if (!room.toLowerCase().contains(labGroup.toLowerCase())) {
          room = '$room ($labGroup)';
        }
      } else {
        room = labGroup;
      }
    }

    // 9. Validation
    if (subject.length < 3) {
      isAiUnsure = true;
    }
    if (room == null || room.isEmpty) {
      isAiUnsure = true;
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
      rowIndex: cell.rowIndex,
      startSlotIndex: cell.timeSlotIndex,
      endSlotIndex: cell.timeSlotIndex,
    );
  }

  /// Merges consecutive classes on the same day if they share the same subject (e.g. 3-hour lab).
  List<ParsedClassCandidate> _mergeConsecutiveClasses(List<ParsedClassCandidate> candidates) {
    if (candidates.length <= 1) return candidates;

    final List<ParsedClassCandidate> merged = [];

    // Group by day of week
    final Map<String, List<ParsedClassCandidate>> byDay = {};
    for (final cand in candidates) {
      byDay.putIfAbsent(cand.dayOfWeek, () => []).add(cand);
    }

    for (final day in byDay.keys) {
      final list = byDay[day]!;
      list.sort((a, b) => a.startSlotIndex.compareTo(b.startSlotIndex));

      int i = 0;
      while (i < list.length) {
        var current = list[i];

        while (i + 1 < list.length) {
          final next = list[i + 1];

          final isConsecutive = next.startSlotIndex == current.endSlotIndex + 1;
          final isSameSubject = _normalizeSubjectForComparison(current.subject) ==
              _normalizeSubjectForComparison(next.subject);

          if (isConsecutive && isSameSubject) {
            current = current.copyWith(
              endTime: next.endTime,
              endSlotIndex: next.endSlotIndex,
              room: current.room ?? next.room,
              teacher: current.teacher ?? next.teacher,
              isAiUnsure: current.isAiUnsure && next.isAiUnsure,
            );
            i++;
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
    if (RegExp(r'\d').hasMatch(s)) return false;
    final words = s.split(RegExp(r'\s+'));
    return words.length >= 2 && words.length <= 4 && words.every((w) => w.isNotEmpty && w[0] == w[0].toUpperCase());
  }

  bool _looksLikeRoom(String s) {
    if (_roomLabeledRegex.hasMatch(s)) return true;
    if (_roomCodeRegex.hasMatch(s)) return true;
    if (RegExp(r'\b(?:C\.Lab|Lab|LT|LH|Hall|CR)\b', caseSensitive: false).hasMatch(s)) return true;
    return RegExp(r'\d').hasMatch(s) && s.length <= 12;
  }

  String _cleanSubject(String s) {
    return s
        .replaceAll(RegExp(r'^[^\w\(\)]+|[^\w\(\)]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeSubjectForComparison(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
