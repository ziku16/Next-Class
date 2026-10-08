import 'dart:math';
import '../../data/models/class_item.dart';
import 'field_classifiers.dart';
import 'ocr_models.dart';

/// Multi-level deduplicator that merges redundant OCR fragments, overlapping blocks,
/// and duplicate classes while strictly protecting legitimate repeated classes (e.g. different times or lab groups).
class ClassDeduplicator {
  ClassDeduplicator._();

  /// Level 1: Deduplicates raw OCR lines with high spatial overlap and identical/similar text.
  static List<OcrTextLine> deduplicateOcrLines(List<OcrTextLine> lines) {
    if (lines.length <= 1) return lines;

    final List<OcrTextLine> result = [];
    for (final line in lines) {
      bool isDuplicate = false;
      for (int i = 0; i < result.length; i++) {
        final existing = result[i];
        final normA = FieldClassifiers.normalizeForComparison(line.text);
        final normB = FieldClassifiers.normalizeForComparison(existing.text);

        if (normA == normB && normA.isNotEmpty) {
          // Check spatial overlap (Intersection over Union)
          final intersectLeft = max(line.left, existing.left);
          final intersectTop = max(line.top, existing.top);
          final intersectRight = min(line.right, existing.right);
          final intersectBottom = min(line.bottom, existing.bottom);

          final w = max(0.0, intersectRight - intersectLeft);
          final h = max(0.0, intersectBottom - intersectTop);
          final intersectArea = w * h;

          final areaA = line.width * line.height;
          final areaB = existing.width * existing.height;
          final minArea = min(areaA, areaB);

          if (minArea > 0 && (intersectArea / minArea) > 0.5) {
            isDuplicate = true;
            break;
          }
        }
      }
      if (!isDuplicate) {
        result.add(line);
      }
    }
    return result;
  }

  /// Level 3: Final canonical timetable deduplication.
  /// Merges classes that represent the exact same lecture/lab entry.
  /// Preserves classes that have different start times, different days, or different lab groups.
  static List<ClassItem> deduplicateClasses(List<ClassItem> classes) {
    if (classes.length <= 1) return classes;

    final List<ClassItem> deduplicated = [];

    for (final candidate in classes) {
      int matchIndex = -1;
      for (int i = 0; i < deduplicated.length; i++) {
        final existing = deduplicated[i];
        if (_isSameCanonicalClass(existing, candidate)) {
          matchIndex = i;
          break;
        }
      }

      if (matchIndex >= 0) {
        // Merge the two entries into one superior canonical entry
        final existing = deduplicated[matchIndex];
        deduplicated[matchIndex] = _mergeTwoClasses(existing, candidate);
      } else {
        deduplicated.add(candidate);
      }
    }

    return deduplicated;
  }

  /// Checks if two [ClassItem] instances refer to the same canonical class.
  static bool _isSameCanonicalClass(ClassItem a, ClassItem b) {
    // 1. Must be on the exact same day
    if (a.dayOfWeek.toLowerCase() != b.dayOfWeek.toLowerCase()) return false;

    // 2. Must share overlapping or identical start time
    if (!_isMatchingTime(a.startTime, b.startTime)) return false;

    // 3. Must share the same normalized subject
    final subjA = FieldClassifiers.normalizeForComparison(a.subject);
    final subjB = FieldClassifiers.normalizeForComparison(b.subject);
    if (subjA != subjB) return false;

    // 4. Must NOT be distinct lab groups (e.g. Group 1 vs Group 2 are NOT duplicates)
    final groupA = _extractGroupNumber(a.room ?? '');
    final groupB = _extractGroupNumber(b.room ?? '');
    if (groupA != null && groupB != null && groupA != groupB) {
      return false; // Distinct lab groups!
    }

    // 5. Must NOT be distinct rooms if both are confidently specified
    final roomA = FieldClassifiers.normalizeForComparison(a.room ?? '');
    final roomB = FieldClassifiers.normalizeForComparison(b.room ?? '');
    if (roomA.isNotEmpty && roomB.isNotEmpty && roomA != roomB) {
      // If neither room contains the other, they are distinct
      if (!roomA.contains(roomB) && !roomB.contains(roomA)) {
        return false;
      }
    }

    return true;
  }

  static bool _isMatchingTime(String t1, String t2) {
    final norm1 = _normalizeTime(t1);
    final norm2 = _normalizeTime(t2);
    if (norm1 == norm2) return true;

    // If within 15 minutes of each other, consider matching start slot
    final min1 = _toMinutes(t1);
    final min2 = _toMinutes(t2);
    if (min1 != null && min2 != null) {
      return (min1 - min2).abs() <= 15;
    }
    return false;
  }

  static String _normalizeTime(String t) {
    final parts = t.trim().replaceAll('.', ':').split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1].substring(0, 2)) ?? 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    return t.trim();
  }

  static int? _toMinutes(String t) {
    final parts = t.trim().replaceAll('.', ':').split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1].substring(0, 2));
      if (h != null && m != null) {
        return h * 60 + m;
      }
    }
    return null;
  }

  static String? _extractGroupNumber(String text) {
    final m = RegExp(r'\b(?:Group|Grp)\s*([0-9A-Za-z]+)\b', caseSensitive: false).firstMatch(text);
    return m?.group(1)?.toLowerCase();
  }

  /// Merges two canonical entries, picking the most complete information.
  static ClassItem _mergeTwoClasses(ClassItem a, ClassItem b) {
    // Choose cleaner subject
    final subject = a.subject.length >= b.subject.length ? a.subject : b.subject;

    // Merge room
    String? room = a.room;
    if (room == null || room.isEmpty) {
      room = b.room;
    } else if (b.room != null && b.room!.isNotEmpty && !room.contains(b.room!)) {
      if (b.room!.length > room.length) room = b.room;
    }

    // Merge teacher
    String? teacher = a.teacher;
    if (teacher == null || teacher.isEmpty) {
      teacher = b.teacher;
    } else if (b.teacher != null && b.teacher!.isNotEmpty && !teacher.contains(b.teacher!)) {
      if (b.teacher!.length > teacher.length) teacher = b.teacher;
    }

    // Longer end time if available
    final endTime = a.endMinutes >= b.endMinutes ? a.endTime : b.endTime;

    return a.copyWith(
      subject: subject,
      room: room,
      teacher: teacher,
      endTime: endTime,
      isAiUnsure: a.isAiUnsure && b.isAiUnsure,
    );
  }
}
