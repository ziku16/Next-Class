import '../../data/models/class_item.dart';

enum AiExtractionErrorCode {
  noInternet,
  parsingFailed,
  noClassesFound,
}

class AiExtractionException implements Exception {
  final AiExtractionErrorCode code;
  final String message;

  const AiExtractionException(this.code, this.message);

  @override
  String toString() => 'AiExtractionException($code): $message';
}

/// Service that ingests timetable photos and extracts structured class schedules.
class AiExtractionService {
  const AiExtractionService();

  /// Extracts classes from an image file path.
  Future<List<ClassItem>> extractClassesFromImage(
    String imagePath, {
    bool isOnline = true,
    bool simulateError = false,
    bool simulateEmpty = false,
    Duration delay = const Duration(seconds: 4),
  }) async {
    if (!isOnline) {
      throw const AiExtractionException(
        AiExtractionErrorCode.noInternet,
        "We need a connection to read your photo. Your picture is safe, so come back when you're online.",
      );
    }

    // Simulate OCR / multimodal parsing delay
    await Future.delayed(delay);

    if (simulateError) {
      throw const AiExtractionException(
        AiExtractionErrorCode.parsingFailed,
        "We couldn't read your timetable this time. It didn't use up a scan, so please try again.",
      );
    }

    if (simulateEmpty) {
      throw const AiExtractionException(
        AiExtractionErrorCode.noClassesFound,
        "That doesn't look like a timetable. Try a clearer photo, or add your classes yourself.",
      );
    }

    // Return realistic extracted timetable matching the NextClass Design System
    return [
      // Monday
      const ClassItem(
        id: 'cls_mon_math',
        subject: 'Mathematics',
        subjectColorIndex: 0,
        dayOfWeek: 'Monday',
        startTime: '08:30',
        endTime: '09:20',
        room: 'A-04',
        teacher: 'Mr. Raza',
      ),
      const ClassItem(
        id: 'cls_mon_physics',
        subject: 'Physics',
        subjectColorIndex: 1,
        dayOfWeek: 'Monday',
        startTime: '09:30',
        endTime: '10:20',
        room: 'B-12',
        teacher: 'Ms. Sara',
      ),
      const ClassItem(
        id: 'cls_mon_chem_lab',
        subject: 'Chemistry Lab',
        subjectColorIndex: 2,
        dayOfWeek: 'Monday',
        startTime: '11:00',
        endTime: '12:40',
        room: 'Lab 2',
        teacher: 'Ms. Sara',
        isAiUnsure: true, // Flagged for AI review in Flow 3
      ),

      // Tuesday
      const ClassItem(
        id: 'cls_tue_eng',
        subject: 'English',
        subjectColorIndex: 3,
        dayOfWeek: 'Tuesday',
        startTime: '08:30',
        endTime: '09:20',
        room: 'A-01',
        teacher: 'Mr. John',
      ),
      const ClassItem(
        id: 'cls_tue_cs',
        subject: 'Computer Science',
        subjectColorIndex: 4,
        dayOfWeek: 'Tuesday',
        startTime: '10:30',
        endTime: '11:20',
        room: 'C-07',
        teacher: 'Ms. Sara Ahmed Khan',
      ),

      // Wednesday
      const ClassItem(
        id: 'cls_wed_eng',
        subject: 'English',
        subjectColorIndex: 3,
        dayOfWeek: 'Wednesday',
        startTime: '08:30',
        endTime: '09:20',
        room: 'A-01',
      ),
      const ClassItem(
        id: 'cls_wed_math',
        subject: 'Mathematics',
        subjectColorIndex: 0,
        dayOfWeek: 'Wednesday',
        startTime: '09:30',
        endTime: '10:20',
        room: 'A-04',
      ),

      // Thursday
      const ClassItem(
        id: 'cls_thu_math',
        subject: 'Mathematics',
        subjectColorIndex: 0,
        dayOfWeek: 'Thursday',
        startTime: '08:30',
        endTime: '09:20',
        room: 'A-04',
        teacher: 'Mr. Raza',
      ),
      const ClassItem(
        id: 'cls_thu_physics',
        subject: 'Physics',
        subjectColorIndex: 1,
        dayOfWeek: 'Thursday',
        startTime: '09:30',
        endTime: '10:20',
        room: 'B-12',
        teacher: 'Ms. Sara',
      ),
      const ClassItem(
        id: 'cls_thu_chem_lab',
        subject: 'Chemistry Lab',
        subjectColorIndex: 2,
        dayOfWeek: 'Thursday',
        startTime: '11:00',
        endTime: '12:40',
        room: 'Lab 2',
      ),

      // Friday
      const ClassItem(
        id: 'cls_fri_cs',
        subject: 'Computer Science',
        subjectColorIndex: 4,
        dayOfWeek: 'Friday',
        startTime: '09:00',
        endTime: '10:30',
        room: 'C-07',
      ),
    ];
  }
}
