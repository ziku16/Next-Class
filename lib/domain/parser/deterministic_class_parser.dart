import '../../data/models/class_item.dart';
import 'class_deduplicator.dart';
import 'field_classifiers.dart';
import 'grid_cell_assigner.dart';
import 'ocr_models.dart';
import 'time_detector.dart';

/// Extracted candidate class representation during cell-level parsing.
class ParsedClassCandidate {
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String subject;
  final String? room;
  final String? teacher;
  final bool isAiUnsure;
  final double confidence;
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
    this.confidence = 1.0,
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
    double? confidence,
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
      confidence: confidence ?? this.confidence,
      columnIndex: columnIndex ?? this.columnIndex,
      rowIndex: rowIndex ?? this.rowIndex,
      startSlotIndex: startSlotIndex ?? this.startSlotIndex,
      endSlotIndex: endSlotIndex ?? this.endSlotIndex,
    );
  }
}

/// Production-grade deterministic parser for university timetable cells.
///
/// Principles:
/// - Semantic multi-signal classification replaces positional order assumptions.
/// - Time NEVER becomes teacher, room, or subject.
/// - Room NEVER becomes subject or teacher.
/// - Teacher NEVER becomes subject or room.
/// - Header, footer, and day metadata are strictly rejected.
/// - Zero hallucinations: missing fields remain null.
/// - Stacked dual lab entries partitioned cleanly without data leakage.
/// - Final canonical deduplication merges true duplicates without losing legitimate repeated classes.
class DeterministicClassParser {
  final TimeDetector timeDetector;

  const DeterministicClassParser({
    this.timeDetector = const TimeDetector(),
  });

  /// Parses a collection of grid cells into structured [ClassItem]s.
  List<ClassItem> parseCells(
    List<TimetableCell> cells, {
    bool? allowMultiPeriodMerge,
  }) {
    if (cells.isEmpty) return [];

    final List<ParsedClassCandidate> rawCandidates = [];

    for (final cell in cells) {
      if (cell.isEmpty) continue;

      // Filter noise lines
      final validLines = cell.lines.where((l) {
        final t = l.text.trim();
        return t.isNotEmpty &&
            !RegExp(r'^[\-_=|\.]{2,}$').hasMatch(t) &&
            !FieldClassifiers.isFooterOrNoise(t) &&
            !FieldClassifiers.isLectureHeader(t) &&
            !FieldClassifiers.isDayName(t);
      }).toList();

      if (validLines.isEmpty) continue;

      // Partition cell into class blocks (handles stacked labs e.g. DBS(Lab) + DS(Lab))
      final blocks = _splitLinesIntoClassBlocks(validLines);
      for (final blockLines in blocks) {
        final candidate = _parseBlock(blockLines, cell);
        if (candidate != null && FieldClassifiers.isValidSubject(candidate.subject)) {
          rawCandidates.add(candidate);
        }
      }
    }

    // Merge multi-period classes (e.g. 2-slot labs or lectures spanning consecutive periods)
    final shouldMerge = allowMultiPeriodMerge ?? true;
    final processedCandidates = shouldMerge
        ? _mergeConsecutiveClasses(rawCandidates)
        : rawCandidates;

    // Convert to domain ClassItem with color indices and unique IDs
    final List<ClassItem> result = [];
    final Map<String, int> subjectColorMap = {};
    int colorCounter = 0;

    for (int i = 0; i < processedCandidates.length; i++) {
      final cand = processedCandidates[i];
      final normSubject = FieldClassifiers.cleanSubject(cand.subject);

      // Final strict candidate validation
      if (!FieldClassifiers.isValidSubject(normSubject) ||
          FieldClassifiers.isLocation(normSubject) ||
          FieldClassifiers.isTeacher(normSubject) ||
          FieldClassifiers.isTime(normSubject)) {
        continue;
      }

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

    // Level 3: Canonical Timetable Deduplication
    final deduplicated = ClassDeduplicator.deduplicateClasses(result);

    // Sort chronologically by weekday, then start time
    deduplicated.sort((a, b) {
      final d = a.dayIndex.compareTo(b.dayIndex);
      if (d != 0) return d;
      return a.startMinutes.compareTo(b.startMinutes);
    });

    return deduplicated;
  }

  /// Partitions cell lines into separate blocks when stacked classes/labs exist.
  List<List<OcrTextLine>> _splitLinesIntoClassBlocks(List<OcrTextLine> lines) {
    if (lines.length <= 1) return [lines];

    // Pre-split lines that contain explicit delimiters like "|" or ";"
    final List<OcrTextLine> expandedLines = [];
    for (final l in lines) {
      final t = l.text.trim();
      if (t.contains('|') && !RegExp(r'^[\-_=|\.]{2,}$').hasMatch(t)) {
        final parts = t.split(RegExp(r'\s*\|\s*'));
        for (final p in parts) {
          if (p.trim().isNotEmpty) {
            expandedLines.add(OcrTextLine(
              text: p.trim(),
              boundingBox: l.boundingBox,
              elements: l.elements,
            ));
          }
        }
      } else {
        expandedLines.add(l);
      }
    }

    if (expandedLines.length <= 1) return [expandedLines];

    final avgLineHeight = expandedLines.map((l) => l.height).reduce((a, b) => a + b) / expandedLines.length;
    final List<List<OcrTextLine>> blocks = [];
    List<OcrTextLine> currentBlock = [expandedLines.first];

    final firstText = expandedLines.first.text.trim();
    bool currentHasSubject = FieldClassifiers.isValidSubject(firstText) && !FieldClassifiers.isLocation(firstText);
    bool currentHasLabHeading = FieldClassifiers.isLabHeading(firstText);
    bool currentHasTeacher = FieldClassifiers.isTeacher(firstText);
    bool currentHasRoom = FieldClassifiers.isLocation(firstText);
    bool currentHasLabGroup = FieldClassifiers.isLabGroup(firstText);

    for (int i = 1; i < expandedLines.length; i++) {
      final currentLine = expandedLines[i];
      final prevLine = expandedLines[i - 1];
      final text = currentLine.text.trim();

      final gap = currentLine.top - prevLine.bottom;
      final isLargeGap = gap > (avgLineHeight * 1.3).clamp(18.0, 50.0);

      final isLabHeading = FieldClassifiers.isLabHeading(text);
      final isTeacher = FieldClassifiers.isTeacher(text);
      final isRoom = FieldClassifiers.isLocation(text);
      final isLabGroup = FieldClassifiers.isLabGroup(text);
      final isSubject = FieldClassifiers.isValidSubject(text) && !isRoom && !isTeacher;

      bool isNewBlock = false;

      // 1. A new lab heading (e.g. "DS(Lab)") after another lab heading or teacher or subject
      if (isLabHeading && (currentHasLabHeading || currentHasTeacher || currentHasSubject || currentBlock.length >= 2)) {
        isNewBlock = true;
      }
      // 2. A second teacher prefix when current block already has one
      else if (isTeacher && currentHasTeacher) {
        isNewBlock = true;
      }
      // 3. A second subject when current block already has a subject and existing attributes
      else if (isSubject && currentHasSubject && (currentHasTeacher || currentHasRoom || currentHasLabGroup || isLargeGap)) {
        isNewBlock = true;
      }
      // 4. Substantial vertical spatial gap + new subject/teacher heading
      else if (isLargeGap && (isSubject || isTeacher) && currentBlock.length >= 2) {
        isNewBlock = true;
      }

      if (isNewBlock) {
        blocks.add(currentBlock);
        currentBlock = [currentLine];
        currentHasSubject = isSubject;
        currentHasLabHeading = isLabHeading;
        currentHasTeacher = isTeacher;
        currentHasRoom = isRoom;
        currentHasLabGroup = isLabGroup;
      } else {
        currentBlock.add(currentLine);
        if (isSubject) currentHasSubject = true;
        if (isLabHeading) currentHasLabHeading = true;
        if (isTeacher) currentHasTeacher = true;
        if (isRoom) currentHasRoom = true;
        if (isLabGroup) currentHasLabGroup = true;
      }
    }

    if (currentBlock.isNotEmpty) {
      blocks.add(currentBlock);
    }

    return blocks;
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

    final unassignedLines = <String>[];

    for (final lineObj in lines) {
      String line = lineObj.text.trim();
      if (line.isEmpty) continue;
      if (RegExp(r'^[\-_=|\.]{2,}$').hasMatch(line)) continue;
      if (FieldClassifiers.isFooterOrNoise(line) ||
          FieldClassifiers.isLectureHeader(line) ||
          FieldClassifiers.isDayName(line)) {
        continue;
      }

      // 1. Check if line contains internal time range (e.g. "08:15 - 09:45")
      final range = timeDetector.parseTimeRange(line);
      if (range != null && range.hasExplicitEndTime) {
        startTime = range.startTime;
        endTime = range.endTime;
        final stripped = line
            .replaceAll(RegExp(r'\b\d{1,2}[:.]\d{2}\s*(am|pm)?\s*[-–—to~]+\s*\d{1,2}[:.]\d{2}\s*(am|pm)?', caseSensitive: false), '')
            .trim();
        if (stripped.length > 2 && !_isExcludedFromSubject(stripped)) {
          line = stripped;
        } else {
          continue;
        }
      } else if (FieldClassifiers.isTime(line)) {
        // Pure time line - NEVER allow into teacher, room, or subject
        continue;
      }

      // 2. Check Lab Group (e.g. "Lab Group 1", "Group 2")
      if (FieldClassifiers.isLabGroup(line)) {
        final m = FieldClassifiers.labGroupPattern.firstMatch(line);
        labGroup = m?.group(0)?.trim() ?? line;
        continue;
      }

      // 3. Check Teacher (Prefix or Label or Person-Name structure)
      if (FieldClassifiers.isTeacher(line)) {
        final labelMatch = FieldClassifiers.teacherLabeledPattern.firstMatch(line);
        if (labelMatch != null) {
          teacher = labelMatch.group(1)?.trim();
        } else {
          teacher = line;
        }
        continue;
      }

      // 4. Check Room / Location (NEVER allows to become subject)
      if (FieldClassifiers.isLocation(line)) {
        room = line;
        continue;
      }

      // 5. Check inline parenthetical patterns like "Physics (Room B-12)" or "DLD (Mr. Ali)"
      final parenMatch = RegExp(r'^(.+?)\s*\(([^)]+)\)$').firstMatch(line);
      if (parenMatch != null && !FieldClassifiers.isLabHeading(line)) {
        final mainPart = parenMatch.group(1)!.trim();
        final inside = parenMatch.group(2)!.trim();

        if (FieldClassifiers.isLocation(inside)) {
          room = inside;
          if (FieldClassifiers.isValidSubject(mainPart)) {
            unassignedLines.add(mainPart);
          }
          continue;
        } else if (FieldClassifiers.isTeacher(inside)) {
          teacher = inside;
          if (FieldClassifiers.isValidSubject(mainPart)) {
            unassignedLines.add(mainPart);
          }
          continue;
        }
      }

      unassignedLines.add(line);
    }

    // 6. Semantic Subject Extraction from remaining lines
    if (unassignedLines.isNotEmpty) {
      int subjIdx = -1;
      for (int i = 0; i < unassignedLines.length; i++) {
        final cand = unassignedLines[i];
        if (FieldClassifiers.isValidSubject(cand) && !_isExcludedFromSubject(cand)) {
          subjIdx = i;
          break;
        }
      }

      if (subjIdx >= 0) {
        subject = FieldClassifiers.cleanSubject(unassignedLines[subjIdx]);

        // Evaluate remaining unassigned lines for secondary teacher or room
        for (int i = 0; i < unassignedLines.length; i++) {
          if (i == subjIdx) continue;
          final sec = unassignedLines[i].trim();
          if (teacher == null && FieldClassifiers.isTeacher(sec)) {
            teacher = sec;
          } else if (room == null && FieldClassifiers.isLocation(sec)) {
            room = sec;
          }
        }
      }
    }

    // A valid class MUST have a genuine, recognizable subject (never room, teacher, or time)
    if (subject == null ||
        !FieldClassifiers.isValidSubject(subject) ||
        FieldClassifiers.isLocation(subject) ||
        FieldClassifiers.isTeacher(subject) ||
        FieldClassifiers.isTime(subject) ||
        FieldClassifiers.isDayName(subject) ||
        FieldClassifiers.isLectureHeader(subject) ||
        FieldClassifiers.isFooterOrNoise(subject)) {
      return null;
    }

    // Strict validation: NEVER confuse time, room, day, or header with teacher
    if (teacher != null) {
      final t = teacher.trim();
      if (FieldClassifiers.isTime(t) ||
          RegExp(r'\b\d{1,2}[:.]\d{2}\b').hasMatch(t) ||
          FieldClassifiers.isLocation(t) ||
          FieldClassifiers.isDayName(t) ||
          FieldClassifiers.isLectureHeader(t) ||
          FieldClassifiers.isFooterOrNoise(t)) {
        teacher = null;
      }
    }

    // Strict validation: NEVER confuse time, teacher, day, or header with room
    if (room != null) {
      final r = room.trim();
      if (FieldClassifiers.isTime(r) ||
          FieldClassifiers.isDayName(r) ||
          FieldClassifiers.isTeacher(r) ||
          FieldClassifiers.isLectureHeader(r) ||
          FieldClassifiers.isFooterOrNoise(r)) {
        room = null;
      }
    }

    // Combine Room and Lab Group cleanly
    if (labGroup != null && labGroup.isNotEmpty) {
      if (room != null && room.isNotEmpty) {
        if (!room.toLowerCase().contains(labGroup.toLowerCase())) {
          room = '$room, $labGroup';
        }
      } else {
        room = labGroup;
      }
    }

    // Calculate confidence score and AI unsure flag
    double confidence = 1.0;
    bool isAiUnsure = false;

    if (room == null || room.isEmpty) {
      confidence -= 0.25;
      isAiUnsure = true;
    }
    if (teacher == null || teacher.isEmpty) {
      confidence -= 0.15;
    }

    return ParsedClassCandidate(
      dayOfWeek: cell.dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      subject: subject,
      room: room,
      teacher: teacher,
      isAiUnsure: isAiUnsure,
      confidence: confidence,
      columnIndex: cell.columnIndex,
      rowIndex: cell.rowIndex,
      startSlotIndex: cell.timeSlotIndex,
      endSlotIndex: cell.timeSlotIndex,
    );
  }

  /// Strictly checks whether a string must NOT be treated as a subject.
  bool _isExcludedFromSubject(String text) {
    final t = text.trim();
    if (FieldClassifiers.isTime(t)) return true;
    if (FieldClassifiers.isLocation(t)) return true;
    if (FieldClassifiers.isTeacher(t)) return true;
    if (FieldClassifiers.isDayName(t)) return true;
    if (FieldClassifiers.isLectureHeader(t)) return true;
    if (FieldClassifiers.isLabGroup(t)) return true;
    if (FieldClassifiers.isFooterOrNoise(t)) return true;
    return false;
  }

  /// Merges consecutive classes on the same day if they share the same subject (e.g. 3-hour lab).
  List<ParsedClassCandidate> _mergeConsecutiveClasses(List<ParsedClassCandidate> candidates) {
    if (candidates.length <= 1) return candidates;

    final List<ParsedClassCandidate> merged = [];
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

          final isConsecutive = next.startSlotIndex == current.endSlotIndex + 1 ||
              current.endTime == next.startTime;
          final isSameSubject = FieldClassifiers.normalizeForComparison(current.subject) ==
              FieldClassifiers.normalizeForComparison(next.subject);

          final normTeacherA = current.teacher?.toLowerCase().trim() ?? '';
          final normTeacherB = next.teacher?.toLowerCase().trim() ?? '';
          final teachersCompatible = normTeacherA.isEmpty ||
              normTeacherB.isEmpty ||
              normTeacherA == normTeacherB ||
              normTeacherA.contains(normTeacherB) ||
              normTeacherB.contains(normTeacherA);

          final normRoomA = current.room?.toLowerCase().trim() ?? '';
          final normRoomB = next.room?.toLowerCase().trim() ?? '';
          final roomsCompatible = normRoomA.isEmpty ||
              normRoomB.isEmpty ||
              normRoomA == normRoomB ||
              normRoomA.contains(normRoomB) ||
              normRoomB.contains(normRoomA);

          if (isConsecutive && isSameSubject && teachersCompatible && roomsCompatible) {
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
}
