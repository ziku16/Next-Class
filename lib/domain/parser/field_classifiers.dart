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
  /// "8:30am - 10:00am", "11:30 - 1:15", "9am - 10:50", "10am - 11:50", "1pm - 2:50"
  static final RegExp timeRangePattern = RegExp(
    r'^\s*\(?\s*(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?\s*(?:[-–—~]|to|\/)\s*(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?\s*\)?\s*$',
    caseSensitive: false,
  );

  /// Matches a single time string like "8:30", "08:30", "10:00", "13:15", "15:00", "8:30 AM", "9am", "1pm"
  static final RegExp singleTimePattern = RegExp(
    r'^\s*\(?\s*(?:(\d{1,2})[:.](\d{2})\s*(?:am|pm)?|(\d{1,2})\s*(?:am|pm))\s*\)?\s*$',
    caseSensitive: false,
  );

  /// Checks if [text] is primarily a time or time range representation.
  static bool isTime(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (timeRangePattern.hasMatch(t)) return true;
    if (singleTimePattern.hasMatch(t)) return true;

    // Check if substring has explicit time range pattern
    if (RegExp(r'\b\d{1,2}[:.]\d{2}\s*(?:am|pm)?\s*[-–—~to/]+\s*\d{1,2}[:.]\d{2}\s*(?:am|pm)?\b', caseSensitive: false).hasMatch(t)) {
      final stripped = t.replaceAll(RegExp(r'\b\d{1,2}[:.]\d{2}\s*(?:am|pm)?\s*[-–—~to/]+\s*\d{1,2}[:.]\d{2}\s*(?:am|pm)?\b', caseSensitive: false), '').trim();
      if (stripped.isEmpty || RegExp(r'^[\(\)\s\-–—]+$').hasMatch(stripped)) {
        return true;
      }
    }

    // Check if after stripping whitespace and punctuation it's predominantly time
    final stripped = t.replaceAll(RegExp(r'[\s\-–—~to/:.apmAPM\(\)]'), '');
    if (stripped.isNotEmpty && RegExp(r'^\d+$').hasMatch(stripped)) {
      if (t.contains(':') || (t.contains('.') && RegExp(r'\d{1,2}\.\d{2}').hasMatch(t))) {
        return true;
      }
    }
    return false;
  }

  // ==========================================
  // 2. LOCATION / ROOM CLASSIFICATION
  // ==========================================

  /// Explicit room labeled prefix like "Room: 101", "Lab - 3", "LT: 2", "CR: 2", "LLT: 1"
  static final RegExp roomLabeledPattern = RegExp(
    r'^\s*(?:Room|Rm\.?|Lab|Laboratory|Hall|LH|LT|LLT|CR|Seminar\s*Room|Auditorium|Audi)\s*[:\-#]?\s*([A-Za-z0-9\s\.\(\)\-]+)$',
    caseSensitive: false,
  );

  /// Standard university room codes:
  /// "LT 1", "LT 2", "LT-4", "LT1", "LLT 2", "LLT2", "CR 2", "CR-1", "CR10", "LH 3", "Room 101", "Lab 3",
  /// "CS C.Lab 7", "CS C.Lab 2", "EE C.Lab (U)", "EE C.Lab", "EE DLD Lab", "C.Lab 4", "CLab 2", "Hall A", "Hall-3",
  /// "A-04", "B-12", "C-07", "F-302", "A121", "F302", "B202", "R101", "Block B", "Auditorium", "Library"
  static final RegExp roomCodePattern = RegExp(
    r'^\s*(?:(?:Room|Rm\.?|Lab|Laboratory|Hall|LH|LT|LLT|CR)\s*[-:#]?\s*)?(?:[A-Z]{1,3}[-\s#]?\d{1,4}[A-Za-z]?|Lab\s*[-:#]?\s*\d+|Hall\s*[-:#]?\s*[A-Za-z0-9]+|(?:CS|EE|SE|IT)?\s*(?:C\.?Lab|DLD\s+Lab|CLab)(?:\s*[0-9A-Za-z\(\)]+)?)\s*$',
    caseSensitive: false,
  );

  /// Specific known room keywords
  static final RegExp roomKeywordsPattern = RegExp(
    r'\b(?:C\.?Lab|DLD\s*Lab|CLab\b|Lab\b|Room\b|Rm\b|Hall\b|LT\b|LLT\b|CR\b|LH\b|Auditorium\b|Audi\b|Library\b|Block\s+[A-Z0-9])',
    caseSensitive: false,
  );

  /// Specific known standalone location names
  static final Set<String> standaloneLocations = {
    'auditorium',
    'audi',
    'library',
    'seminar hall',
    'seminar room',
    'conference room',
    'main hall',
    'ee c.lab',
    'cs c.lab',
    'c.lab',
  };

  /// Checks if [text] strongly indicates a classroom, laboratory, or hall location.
  static bool isLocation(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (isTime(t)) return false;
    if (isDayName(t)) return false;
    if (isLectureHeader(t)) return false;
    if (isLabHeading(t)) return false; // "DBS(Lab)" or "DS(Lab)" are subjects, not rooms

    final lower = t.toLowerCase();
    if (standaloneLocations.contains(lower)) return true;

    if (roomLabeledPattern.hasMatch(t)) return true;
    if (roomCodePattern.hasMatch(t)) return true;

    // Pattern like "LT 1", "LT 2", "LT-4", "LT1", "LLT 2", "LLT2", "CR 2", "CR-2", "CR2", "LH 4", "LH-1"
    if (RegExp(r'^(?:LT|LLT|CR|LH)\s*[-:#]?\s*\d+[A-Za-z]?$', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    // Pattern like "CS C.Lab 7", "EE C.Lab (U)", "EE DLD Lab", "C.Lab 4", "CLab 2", "C.Lab"
    if (RegExp(r'^(?:(?:CS|EE|SE|IT)\s+)?(?:C\.?Lab|DLD\s+Lab|CLab)\b', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    // Pattern like "A-04", "B-12", "C-07", "F-302", "R-101", "A121", "B202", "F302", "L102"
    if (RegExp(r'^[A-Z][\-\s]?\d{2,4}[A-Z]?$').hasMatch(t)) {
      return true;
    }
    // Pattern like "Room 101", "Rm 104", "Lab 4", "Hall A"
    if (RegExp(r'^(?:Room|Rm\.?|Lab|Hall|Block|Building|Bld\.?)\s*[-:#]?\s*[A-Za-z0-9\-\.]+$', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    // Short string (< 25 chars) with room keywords + digits (e.g. "Computer Lab 4")
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
    if (RegExp(r'\b\d{1,2}[:.]\d{2}\b').hasMatch(t)) return false; // Time inside must NEVER be teacher
    if (isLocation(t)) return false;
    if (isDayName(t)) return false;
    if (isLectureHeader(t)) return false;
    if (isFooterOrNoise(t)) return false;
    if (isLabHeading(t)) return false;
    if (isLabGroup(t)) return false;

    if (teacherPrefixPattern.hasMatch(t)) return true;
    if (teacherLabeledPattern.hasMatch(t)) return true;

    // Exclude non-person academic concept terms from teacher heuristic
    final nonPersonWords = RegExp(
      r'\b(?:Learning|Computing|Development|Design|Security|Studies|Systems|Application|Applications|Methodology|Principles|Introduction|Advanced|Applied|Basic|Fundamentals|Concepts|Science|Engineering|Networks|Intelligence|Database)\b',
      caseSensitive: false,
    );
    if (nonPersonWords.hasMatch(t)) return false;

    // Exclude room tokens
    if (roomKeywordsPattern.hasMatch(t)) return false;

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

    // Room keywords without academic subject keywords must never be a subject
    if (roomKeywordsPattern.hasMatch(t) && !hasAcademicCourseKeyword(t)) {
      return false;
    }
    // Time indicators without academic subject keywords must never be a subject
    if (RegExp(r'\b\d{1,2}[:.]\d{2}\b').hasMatch(t) && !hasAcademicCourseKeyword(t)) {
      return false;
    }

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
