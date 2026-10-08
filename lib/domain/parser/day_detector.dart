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
  String toString() => 'DayCandidate($dayName, bounds: $boundingBox)';
}

/// Day orientation within a timetable
enum DayOrientation {
  horizontal, // Days are columns along the top (Format A)
  vertical,   // Days are rows stacked down the left (Format B / D)
  unknown,
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

  /// Scans OCR lines or elements to find all candidate day matches.
  List<DayCandidate> findAllRawDayCandidates(List<OcrTextLine> lines) {
    final List<DayCandidate> candidates = [];

    for (final line in lines) {
      final tokens = line.text.split(RegExp(r'[\s\-,/|]+'));
      for (final token in tokens) {
        final day = matchDay(token);
        if (day != null) {
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
          break; // One match per line
        }
      }
    }

    return candidates;
  }

  /// Scans OCR lines to find horizontal day headers (arranged left-to-right across the top).
  List<DayCandidate> findDayCandidates(List<OcrTextLine> lines) {
    final raw = findAllRawDayCandidates(lines);
    if (raw.isEmpty) return [];

    // Group candidates by Y proximity
    raw.sort((a, b) => a.top.compareTo(b.top));

    final clusters = <List<DayCandidate>>[];
    for (final cand in raw) {
      bool added = false;
      for (final cluster in clusters) {
        final avgTop = cluster.map((c) => c.top).reduce((a, b) => a + b) / cluster.length;
        if ((cand.top - avgTop).abs() < 60) {
          cluster.add(cand);
          added = true;
          break;
        }
      }
      if (!added) {
        clusters.add([cand]);
      }
    }

    // Pick cluster with most unique days
    clusters.sort((a, b) {
      final uA = a.map((c) => c.dayName).toSet().length;
      final uB = b.map((c) => c.dayName).toSet().length;
      return uB.compareTo(uA);
    });

    final bestCluster = clusters.first;
    final Map<String, DayCandidate> uniqueDays = {};
    for (final cand in bestCluster) {
      uniqueDays.putIfAbsent(cand.dayName, () => cand);
    }

    final result = uniqueDays.values.toList();
    result.sort((a, b) => a.left.compareTo(b.left));
    return result;
  }

  /// Scans OCR lines to find vertical day headers (arranged top-to-bottom down a column).
  List<DayCandidate> findVerticalDayCandidates(List<OcrTextLine> lines, {double? maxLeft}) {
    final raw = findAllRawDayCandidates(lines);
    if (raw.isEmpty) return [];

    final filtered = maxLeft != null
        ? raw.where((c) => c.center.dx <= maxLeft).toList()
        : raw;

    if (filtered.isEmpty) return [];

    // Group by X proximity
    filtered.sort((a, b) => a.left.compareTo(b.left));

    final clusters = <List<DayCandidate>>[];
    for (final cand in filtered) {
      bool added = false;
      for (final cluster in clusters) {
        final avgLeft = cluster.map((c) => c.left).reduce((a, b) => a + b) / cluster.length;
        if ((cand.left - avgLeft).abs() < 80) {
          cluster.add(cand);
          added = true;
          break;
        }
      }
      if (!added) {
        clusters.add([cand]);
      }
    }

    clusters.sort((a, b) {
      final uA = a.map((c) => c.dayName).toSet().length;
      final uB = b.map((c) => c.dayName).toSet().length;
      return uB.compareTo(uA);
    });

    final bestCluster = clusters.first;
    final Map<String, DayCandidate> uniqueDays = {};
    for (final cand in bestCluster) {
      uniqueDays.putIfAbsent(cand.dayName, () => cand);
    }

    final result = uniqueDays.values.toList();
    result.sort((a, b) => a.top.compareTo(b.top));
    return result;
  }

  /// Determines whether days are arranged as rows (vertical on left) or columns (horizontal on top).
  DayOrientation detectOrientation(List<OcrTextLine> lines, double imgWidth, double imgHeight) {
    final horizontal = findDayCandidates(lines);
    final vertical = findVerticalDayCandidates(lines, maxLeft: imgWidth * 0.4);

    final uHoriz = horizontal.map((c) => c.dayName).toSet().length;
    final uVert = vertical.map((c) => c.dayName).toSet().length;

    if (uVert >= 3 && uVert >= uHoriz) {
      return DayOrientation.vertical;
    }
    if (uHoriz >= 3) {
      return DayOrientation.horizontal;
    }
    if (uVert >= 2) return DayOrientation.vertical;
    if (uHoriz >= 2) return DayOrientation.horizontal;

    return DayOrientation.unknown;
  }
}
