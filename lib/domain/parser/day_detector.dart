import 'dart:ui';
import 'ocr_models.dart';

/// Represents a candidate weekday header detected in OCR with spatial bounds.
class DayCandidate {
  final String dayName; // 'Monday', 'Tuesday', etc.
  final Rect boundingBox;
  final String rawText;

  const DayCandidate({
    required this.dayName,
    required this.boundingBox,
    required this.rawText,
  });

  double get left => boundingBox.left;
  double get right => boundingBox.right;
  double get top => boundingBox.top;
  double get bottom => boundingBox.bottom;
  Offset get center => boundingBox.center;

  @override
  String toString() => 'DayCandidate($dayName, x: ${left.toStringAsFixed(1)}..${right.toStringAsFixed(1)})';
}

/// Robust deterministic weekday detection and spatial ordering for timetable parsing.
class DayDetector {
  const DayDetector();

  static const Map<String, String> _dayAliases = {
    'monday': 'Monday',
    'mon': 'Monday',
    'mnday': 'Monday',
    'mo': 'Monday',
    'tuesday': 'Tuesday',
    'tue': 'Tuesday',
    'tues': 'Tuesday',
    'tu': 'Tuesday',
    'wednesday': 'Wednesday',
    'wed': 'Wednesday',
    'wednes': 'Wednesday',
    'wends': 'Wednesday',
    'we': 'Wednesday',
    'thursday': 'Thursday',
    'thu': 'Thursday',
    'thurs': 'Thursday',
    'thur': 'Thursday',
    'th': 'Thursday',
    'friday': 'Friday',
    'fri': 'Friday',
    'fr': 'Friday',
    'saturday': 'Saturday',
    'sat': 'Saturday',
    'sa': 'Saturday',
    'sunday': 'Sunday',
    'sun': 'Sunday',
    'su': 'Sunday',
  };

  /// Normalizes a single word/token into a canonical day name if it matches a weekday.
  static String? matchDay(String word) {
    final clean = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '').trim();
    if (_dayAliases.containsKey(clean)) {
      return _dayAliases[clean];
    }
    return null;
  }

  /// Scans OCR lines or elements to find candidate day headers.
  List<DayCandidate> findDayCandidates(List<OcrTextLine> lines) {
    final List<DayCandidate> candidates = [];

    for (final line in lines) {
      // 1. Check whole line or tokens
      final tokens = line.text.split(RegExp(r'[\s\-,/|]+'));
      for (final token in tokens) {
        final day = matchDay(token);
        if (day != null) {
          // If line has element bounds, find matching element
          Rect bounds = line.boundingBox;
          for (final elem in line.elements) {
            if (matchDay(elem.text) == day) {
              bounds = elem.boundingBox;
              break;
            }
          }
          candidates.add(DayCandidate(
            dayName: day,
            boundingBox: bounds,
            rawText: line.text,
          ));
          break; // Avoid duplicate day for same line
        }
      }
    }

    if (candidates.isEmpty) return [];

    // Filter to retain the primary header row:
    // Timetable day headers usually share a similar Y coordinate near the top of the table.
    // Group candidates by Y proximity
    candidates.sort((a, b) => a.top.compareTo(b.top));

    // Find the horizontal cluster with the most days
    final clusters = <List<DayCandidate>>[];
    for (final cand in candidates) {
      bool added = false;
      for (final cluster in clusters) {
        final avgTop = cluster.map((c) => c.top).reduce((a, b) => a + b) / cluster.length;
        if ((cand.top - avgTop).abs() < 60) { // within 60px vertically
          cluster.add(cand);
          added = true;
          break;
        }
      }
      if (!added) {
        clusters.add([cand]);
      }
    }

    // Pick the cluster with the largest number of unique days
    clusters.sort((a, b) {
      final uniqueA = a.map((c) => c.dayName).toSet().length;
      final uniqueB = b.map((c) => c.dayName).toSet().length;
      return uniqueB.compareTo(uniqueA);
    });

    final bestCluster = clusters.first;

    // Deduplicate days by taking the leftmost or best bounds
    final Map<String, DayCandidate> uniqueDays = {};
    for (final cand in bestCluster) {
      if (!uniqueDays.containsKey(cand.dayName)) {
        uniqueDays[cand.dayName] = cand;
      }
    }

    final result = uniqueDays.values.toList();
    // Sort left to right horizontally
    result.sort((a, b) => a.left.compareTo(b.left));

    return result;
  }
}
