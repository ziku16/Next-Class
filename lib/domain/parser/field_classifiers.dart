import 'day_detector.dart';

/// Semantic field classifier for timetable text extraction.
///
/// Ensures:
/// - Time strings NEVER become teacher, room, or subject.
/// - Room strings NEVER become subject or teacher.
/// - Teacher strings NEVER become subject or room.
/// - Days, lecture labels, headers, and footers NEVER become classes.
/// - No hallucinations or invented data.
class FieldClassifiers {
  FieldClassifiers._();

  // ==========================================
  // 1. TIME CLASSIFICATION
  // ==========================================

  /// Matches explicit time ranges like:
  /// "8:30 - 10:00", "08:30-10:00", "8:30–10:00", "8:30 to 10:00", "08:30 – 10:00",
  /// "8:30am - 10:00am", "11:30 - 1:15"
  static final RegExp timeRangePattern = RegExp(
    r'^\s*\(?\s*(\d{1,2}[:.]\d{2})\s*(?:am|pm)?\s*[-–—~to/]+\s*(\d{1,2}[:.]\d{2})\s*(?:am|pm)?\s*\)?\s*$',
    caseSensitive: false,
  );

  /// Matches a single time string like "8:30", "08:30", "10:00", "13:15", "15:00", "8:30 AM"
  static final RegExp singleTimePattern = RegExp(
    r'^\s*\(?\s*(\d{1,2}[:.]\d{2})\s*(?:am|pm)?\s*\)?\s*$',
    caseSensitive: false,
  );

  /// Checks if [text] is primarily a time or time range representation.
  static bool isTime(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (timeRangePattern.hasMatch(t)) return true;
    if (singleTimePattern.hasMatch(t)) return true;
    // Check if after stripping whitespace and punctuation it's predominantly time
    final stripped = t.replaceAll(RegExp(r'[\s\-–—~to/:.apmAPM\(\)]'), '');
    if (stripped.isNotEmpty && RegExp(r'^\d+$').hasMatch(stripped)) {
      if (t.contains(':') || t.contains('.') && RegExp(r'\d{1,2}\.\d{2}').hasMatch(t)) {
        return true;
      }
    }
    return false;
  }

  // ==========================================
  // 2. LOCATION / ROOM CLASSIFICATION
  // ==========================================

  /// Explicit room labeled prefix like "Room: 101", "Lab - 3", "LT: 2", "CR: 2"
  static final RegExp roomLabeledPattern = RegExp(
    r'^\s*(?:Room|Rm\.?|Lab|Laboratory|Hall|LH|LT|CR)\s*[:\-]?\s*([A-Za-z0-9\s\.\(\)\-]+)$',
    caseSensitive: false,
  );

  /// Standard university room codes:
  /// "LT 1", "LT 2", "LT-4", "CR 2", "CR-1", "LH 3", "Room 101", "Lab 3",
  /// "CS C.Lab 7", "CS C.Lab 2", "EE C.Lab (U)", "EE DLD Lab", "Hall A", "Hall-3",
  /// "A-04", "B-12", "C-07", "Block B", "Auditorium"
  static final RegExp roomCodePattern = RegExp(
    r'^\s*(?:(?:Room|Rm\.?|Lab|Hall|LH|LT|CR)\s*[-:]?\s*)?(?:[A-Z]{1,2}[-\s]?\d{1,3}[A-Z]?|Lab\s*[-:]?\s*\d+|Hall\s*[-:]?\s*[A-Za-z0-9]+|(?:CS|EE)\s+(?:C\.?Lab|DLD\s+Lab)(?:\s*[0-9A-Za-z\(\)]+)?)\s*$',
    caseSensitive: false,
  );

  /// Specific known room keywords
  static final RegExp roomKeywordsPattern = RegExp(
    r'\b(?:C\.?Lab|DLD\s*Lab|Lab\b|Room\b|Rm\b|Hall\b|LT\b|CR\b|LH\b|Auditorium\b|Block\s+[A-Z0-9])',
    caseSensitive: false,
  );

  /// Checks if [text] strongly indicates a classroom, laboratory, or hall location.
  static bool isLocation(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (isTime(t)) return false;
    if (isDayName(t)) return false;
    if (isLectureHeader(t)) return false;

    if (roomLabeledPattern.hasMatch(t)) return true;
    if (roomCodePattern.hasMatch(t)) return true;

    // Pattern like "LT 1", "LT 2", "CR 2", "LH 4"
    if (RegExp(r'^(?:LT|CR|LH)\s*\d+[A-Za-z]?$', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    // Pattern like "CS C.Lab 7", "EE C.Lab (U)", "EE DLD Lab"
    if (RegExp(r'^(?:CS|EE)\s+(?:C\.?Lab|DLD\s+Lab)\b', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    // Pattern like "A-04", "B-12", "C-07", "R-101"
    if (RegExp(r'^[A-Z][\-\s]\d{2,3}[A-Z]?$').hasMatch(t)) {
      return true;
    }
    // Short string (< 16 chars) with room keywords + digits (e.g. "Computer Lab 4")
    if (t.length <= 25 && roomKeywordsPattern.hasMatch(t) && RegExp(r'\d').hasMatch(t)) {
      return true;
    }

    return false;
  }

  // ==========================================
  // 3. TEACHER CLASSIFICATION
  // ==========================================

  /// Explicit honorific / title prefixes for faculty members
  static final RegExp teacherPrefixPattern = RegExp(
    r'^\s*(?:Dr\.?|Prof\.?|Professor|Mr\.?|Ms\.?|Mrs\.?|Engr\.?|Sir|Madam|Lecturer|Instructor)\s+([A-Za-z\s\.\-]+)$',
    caseSensitive: false,
  );

  /// Explicit labeled teacher prefix like "Teacher: Mr. Ali", "Instructor: Jane Doe"
  static final RegExp teacherLabeledPattern = RegExp(
    r'^\s*(?:Teacher|Faculty|Instructor|Prof|Lecturer)\s*[:\-]\s*(.+)$',
    caseSensitive: false,
  );

  /// Checks if [text] represents a teacher, instructor, or faculty member.
  static bool isTeacher(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (isTime(t)) return false;
    if (isLocation(t)) return false;
    if (isDayName(t)) return false;
    if (isLectureHeader(t)) return false;
    if (isFooterOrNoise(t)) return false;
    if (isLabHeading(t)) return false;

    if (teacherPrefixPattern.hasMatch(t)) return true;
    if (teacherLabeledPattern.hasMatch(t)) return true;

    // Exclude non-person academic concept terms from teacher heuristic
    final nonPersonWords = RegExp(
      r'\b(?:Learning|Computing|Development|Design|Security|Studies|Systems|Application|Applications|Methodology|Principles|Introduction|Advanced|Applied|Basic|Fundamentals|Concepts|Science|Engineering|Networks|Intelligence|Database)\b',
      caseSensitive: false,
    );
    if (nonPersonWords.hasMatch(t)) return false;

    // Multi-word name heuristic: 2 to 4 capitalized words with no digits, no course keywords
    final words = t.split(RegExp(r'\s+'));
    if (words.length >= 2 && words.length <= 4) {
      if (!RegExp(r'\d').hasMatch(t) && !hasAcademicCourseKeyword(t)) {
        final allTitleCase = words.every((w) => w.isNotEmpty && w[0] == w[0].toUpperCase());
        if (allTitleCase) {
          // Verify it's not a known multi-word subject like "Database Systems" or "Computer Science"
          if (!hasAcademicCourseKeyword(t) && !isCommonMultiWordSubject(t)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  // ==========================================
  // 4. LAB GROUP CLASSIFICATION
  // ==========================================

  static final RegExp labGroupPattern = RegExp(
    r'\b(?:Lab\s*Group|Group)\s*([0-9A-Za-z]+)\b',
    caseSensitive: false,
  );

  static bool isLabGroup(String text) {
    final t = text.trim();
    if (labGroupPattern.hasMatch(t)) {
      final stripped = t.replaceAll(labGroupPattern, '').trim();
      return stripped.length <= 3;
    }
    return false;
  }

  // ==========================================
  // 5. HEADERS, FOOTERS, DAYS & NOISE
  // ==========================================

  static final RegExp lectureHeaderPattern = RegExp(
    r'^\s*(?:Lecture|Lec|Period|Slot)[-\s]*\d+\s*$',
    caseSensitive: false,
  );

  static final RegExp footerPattern = RegExp(
    r'(?:timetable\s*generated|asc\s*timetables|generated\s*:\s*\d|asc\b|software\s*generated|page\s*\d+\s*(?:of\s*\d+)?)',
    caseSensitive: false,
  );

  static bool isDayName(String text) {
    final t = text.trim();
    return DayDetector.matchDay(t) != null;
  }

  static bool isLectureHeader(String text) {
    return lectureHeaderPattern.hasMatch(text.trim());
  }

  static bool isFooterOrNoise(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    if (RegExp(r'^[\-_=|\.]{2,}$').hasMatch(t)) return true;
    if (footerPattern.hasMatch(t)) return true;
    if (RegExp(r'^\d{1,2}/\d{1,2}/\d{2,4}$').hasMatch(t)) return true;
    if (RegExp(r'\b(?:semester|university\s*weekly|class\s*schedule|timetable)\b', caseSensitive: false).hasMatch(t) &&
        !t.contains(':') && t.length < 30) {
      return true;
    }
    return false;
  }

  // ==========================================
  // 6. SUBJECT CLASSIFICATION
  // ==========================================

  static final RegExp academicKeywords = RegExp(
    r'\b(?:Systems|Structures|Engineering|Design|Logic|Geometry|Calculus|Analytics|Analysis|Programming|Science|Networks|Intelligence|Database|Physics|Chemistry|Mathematics|Math|English|Lab|Management|Operating|Computer|Computing|Machine|Learning|Cloud|Security|Web|Mobile|Algorithms|Ethics|Economics|Accounting|Finance|History|Psychology|Algebra|Humanities|DBS|DS|DLD|SE|AI|CS|EE|MATH|ENG|PHY|CHEM|OOP|OS|IT|Software|Digital)\b',
    caseSensitive: false,
  );

  static final RegExp courseCodePattern = RegExp(
    r'\b(?:CS|SE|EE|MATH|ENG|PHY|CHEM|ME|CE|IT|AI|DS)[-\s]?\d{3}\b',
    caseSensitive: false,
  );

  static final List<String> commonMultiWordSubjects = [
    'Database Systems',
    'Data Structures',
    'Software Engineering',
    'Computer Science',
    'Information Technology',
    'Digital Logic Design',
    'Fundamentals of Digital Logic Design',
    'Calculus and Analytic Geometry',
    'Linear Algebra',
    'Artificial Intelligence',
    'Compiler Construction',
    'Operating Systems',
    'Computer Networks',
    'Machine Learning',
    'Cloud Computing',
    'Deep Learning',
    'Cyber Security',
    'Human Computer Interaction',
    'Discrete Mathematics',
    'Probability and Statistics',
    'Technical and Business Writing',
    'Communication Skills',
    'Professional Ethics',
    'Applied Physics',
  ];

  static bool isCommonMultiWordSubject(String text) {
    final clean = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final s in commonMultiWordSubjects) {
      if (clean == s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')) {
        return true;
      }
    }
    return false;
  }

  static bool hasAcademicCourseKeyword(String text) {
    return academicKeywords.hasMatch(text) || courseCodePattern.hasMatch(text);
  }

  static bool isLabHeading(String text) {
    return RegExp(r'\((?:Lab|lab)\)', caseSensitive: false).hasMatch(text) ||
        RegExp(r'\b[A-Za-z]{2,5}\s*\((?:Lab|lab)\)', caseSensitive: false).hasMatch(text);
  }

  /// Evaluates whether [text] is a valid course/subject title.
  static bool isValidSubject(String text) {
    final t = cleanSubject(text);
    if (t.length < 2) return false;
    if (!RegExp(r'[a-zA-Z]').hasMatch(t)) return false;

    // Disqualify any text that is definitely a different entity
    if (isTime(t)) return false;
    if (isLocation(t)) return false;
    if (isTeacher(t)) return false;
    if (isDayName(t)) return false;
    if (isLectureHeader(t)) return false;
    if (isLabGroup(t)) return false;
    if (isFooterOrNoise(t)) return false;

    // Lab headings like DBS(Lab) or DS(Lab) are explicitly valid subjects
    if (isLabHeading(t)) return true;

    // Course codes like CS-201, SE-301 are explicitly valid
    if (courseCodePattern.hasMatch(t)) return true;

    // Text containing academic keywords
    if (hasAcademicCourseKeyword(t)) return true;

    // General subjects: 1 to 6 words, not purely numeric
    final words = t.split(RegExp(r'\s+'));
    if (words.length <= 7 && !RegExp(r'^\d+$').hasMatch(t)) {
      return true;
    }

    return false;
  }

  /// Cleans and formats subject string.
  static String cleanSubject(String text) {
    var cleaned = text
        .replaceAll(RegExp(r'^[^\w\(\)]+|[^\w\(\)]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Normalize "DBS(Lab)" to "DBS(Lab)" or "DBS (Lab)"
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([A-Za-z0-9])\s*\((Lab|lab)\)', caseSensitive: false),
      (m) => '${m.group(1)}(${m.group(2)})',
    );
    return cleaned;
  }

  /// Normalizes a string for deduplication comparisons (case/whitespace/punctuation insensitive).
  static String normalizeForComparison(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
