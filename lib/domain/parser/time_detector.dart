import 'dart:ui';
import 'ocr_models.dart';

/// Represents a parsed time range with normalized 24-hour 'HH:mm' values.
class ParsedTimeRange {
  final String startTime;
  final String endTime;
  final bool hasExplicitEndTime;

  const ParsedTimeRange({
    required this.startTime,
    required this.endTime,
    this.hasExplicitEndTime = true,
  });

  int get startMinutes {
    final parts = startTime.split(':');
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  int get endMinutes {
    final parts = endTime.split(':');
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  int get durationInMinutes => endMinutes - startMinutes;

  @override
  String toString() => '$startTime – $endTime';
}

/// Candidate time label detected in OCR output with spatial bounds.
class TimeSlotCandidate {
  final ParsedTimeRange range;
  final Rect boundingBox;
  final String rawText;

  const TimeSlotCandidate({
    required this.range,
    required this.boundingBox,
    required this.rawText,
  });

  double get top => boundingBox.top;
  double get bottom => boundingBox.bottom;
  double get left => boundingBox.left;
  double get right => boundingBox.right;
  Offset get center => boundingBox.center;

  @override
  String toString() => 'TimeSlot(${range.startTime}-${range.endTime}, y: ${top.toStringAsFixed(1)})';
}

/// Robust deterministic time detection and normalization for timetable parsing.
class TimeDetector {
  const TimeDetector();

  // Pattern for time range like "08:00 - 09:20", "8:30-10:00", "09:30 to 10:20", "8:00 AM - 9:00 AM"
  static final RegExp _rangeRegex = RegExp(
    r'(\b\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?\s*(?:[-–—~]|to|\/)\s*(\b\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?',
    caseSensitive: false,
  );

  // Pattern for single time like "08:00", "8:30 AM", "14:00"
  static final RegExp _singleTimeRegex = RegExp(
    r'(\b\d{1,2})[:.](\d{2})\s*(am|pm)?',
    caseSensitive: false,
  );

  // Pattern for simple hour like "8 AM", "9 PM", "Period 1 (8:00)"
  static final RegExp _hourWithAmPmRegex = RegExp(
    r'(\b\d{1,2})\s*(am|pm)\b',
    caseSensitive: false,
  );

  /// Normalizes hour, minute, and optional am/pm to 'HH:mm' 24-hour string.
  static String normalizeTime(int hour, int minute, [String? amPm]) {
    int h = hour;
    final m = minute.clamp(0, 59);

    if (amPm != null && amPm.isNotEmpty) {
      final period = amPm.toLowerCase().trim();
      if (period == 'pm' && h < 12) {
        h += 12;
      } else if (period == 'am' && h == 12) {
        h = 0;
      }
    } else {
      // University timetable heuristic: hours 1..6 without AM/PM are afternoon (13..18)
      if (h >= 1 && h <= 6) {
        h += 12;
      }
    }

    h = h.clamp(0, 23);
    final hStr = h.toString().padLeft(2, '0');
    final mStr = m.toString().padLeft(2, '0');
    return '$hStr:$mStr';
  }

  /// Parses a string for a time range (e.g. "08:30 - 09:20", "8:00-9:00", or single "09:00").
  ParsedTimeRange? parseTimeRange(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 1. Check for explicit range
    final rangeMatch = _rangeRegex.firstMatch(clean);
    if (rangeMatch != null) {
      final h1 = int.tryParse(rangeMatch.group(1) ?? '') ?? 0;
      final m1 = int.tryParse(rangeMatch.group(2) ?? '0') ?? 0;
      final amPm1 = rangeMatch.group(3);

      final h2 = int.tryParse(rangeMatch.group(4) ?? '') ?? 0;
      final m2 = int.tryParse(rangeMatch.group(5) ?? '0') ?? 0;
      var amPm2 = rangeMatch.group(6);

      // If only end has am/pm, inherit for start if consistent
      if (amPm1 == null && amPm2 != null) {
        final p2 = amPm2.toLowerCase();
        if (p2 == 'am' || (p2 == 'pm' && h1 >= 12)) {
          // both AM or both PM
        }
      }

      final start = normalizeTime(h1, m1, amPm1);
      final end = normalizeTime(h2, m2, amPm2 ?? amPm1);

      return ParsedTimeRange(
        startTime: start,
        endTime: end,
        hasExplicitEndTime: true,
      );
    }

    // 2. Check for single time with colon
    final singleMatch = _singleTimeRegex.firstMatch(clean);
    if (singleMatch != null) {
      final h = int.tryParse(singleMatch.group(1) ?? '') ?? 0;
      final m = int.tryParse(singleMatch.group(2) ?? '0') ?? 0;
      final amPm = singleMatch.group(3);

      final start = normalizeTime(h, m, amPm);
      // Default duration: 50 minutes
      final endMins = (h >= 1 && h <= 6 && (amPm == null || amPm.toLowerCase() == 'pm') ? h + 12 : h) * 60 + m + 50;
      final endH = (endMins ~/ 60).clamp(0, 23);
      final endM = (endMins % 60).clamp(0, 59);
      final end = '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';

      return ParsedTimeRange(
        startTime: start,
        endTime: end,
        hasExplicitEndTime: false,
      );
    }

    // 3. Check for single hour with AM/PM (e.g. "9 AM")
    final hourMatch = _hourWithAmPmRegex.firstMatch(clean);
    if (hourMatch != null) {
      final h = int.tryParse(hourMatch.group(1) ?? '') ?? 0;
      final amPm = hourMatch.group(2);

      final start = normalizeTime(h, 0, amPm);
      final end = normalizeTime(h + 1, 0, amPm);
      return ParsedTimeRange(
        startTime: start,
        endTime: end,
        hasExplicitEndTime: false,
      );
    }

    return null;
  }

  /// Extracts all candidate time slots from OCR lines with their bounding boxes.
  List<TimeSlotCandidate> findTimeCandidates(List<OcrTextLine> lines) {
    final List<TimeSlotCandidate> candidates = [];

    for (final line in lines) {
      final range = parseTimeRange(line.text);
      if (range != null) {
        // Validate sensible university hours (07:00 to 22:00)
        final sH = int.tryParse(range.startTime.split(':')[0]) ?? 0;
        if (sH >= 7 && sH <= 22) {
          candidates.add(TimeSlotCandidate(
            range: range,
            boundingBox: line.boundingBox,
            rawText: line.text,
          ));
        }
      }
    }

    // Sort top to bottom
    candidates.sort((a, b) => a.top.compareTo(b.top));
    return candidates;
  }
}
