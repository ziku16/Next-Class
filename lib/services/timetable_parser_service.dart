import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/models/class_item.dart';

/// Exception thrown when on-device scan rate limit is exceeded.
class ScanLimitException implements Exception {
  final String message;
  const ScanLimitException(this.message);

  @override
  String toString() => 'RATE_LIMIT_EXCEEDED: $message';
}

class TimetableParserService {
  static const String _geminiApiKey =
      'AQ.Ab8RN6JrQFmyYNWAeRh5xQngnwxWpO8IW_fnAyO3YyR4FWjDTg';
  static const List<String> _candidateModels = [
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3-flash-preview',
  ];

  static const String _scanHistoryKey = 'timetable_scan_timestamps';
  static const int maxScansPerDay = 2;
  static const int maxScansPerWeek = 3;

  /// Returns recent scan timestamps within the 7-day rolling window.
  static Future<List<DateTime>> getRecentScanTimestamps([SharedPreferences? testPrefs]) async {
    final prefs = testPrefs ?? await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_scanHistoryKey) ?? [];
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7));

    final List<DateTime> valid = [];
    for (final s in raw) {
      final dt = DateTime.tryParse(s);
      if (dt != null && dt.isAfter(cutoff)) {
        valid.add(dt);
      }
    }
    return valid;
  }

  /// Checks on-device scan quota before initiating a scan.
  /// Throws [ScanLimitException] if daily or weekly limits are exceeded.
  static Future<void> checkScanQuota([SharedPreferences? testPrefs]) async {
    final prefs = testPrefs ?? await SharedPreferences.getInstance();
    final history = await getRecentScanTimestamps(prefs);
    final now = DateTime.now();

    final dailyScans = history.where((dt) =>
        dt.year == now.year && dt.month == now.month && dt.day == now.day).length;
    final weeklyScans = history.length;

    if (dailyScans >= maxScansPerDay) {
      throw ScanLimitException(
        'Daily scan limit reached ($maxScansPerDay/$maxScansPerDay). You can scan again tomorrow.',
      );
    }
    if (weeklyScans >= maxScansPerWeek) {
      throw ScanLimitException(
        'Weekly scan limit reached ($maxScansPerWeek/$maxScansPerWeek). Please wait for rolling scans to reset.',
      );
    }
  }

  /// Records successful scan timestamp and prunes records older than 7 days.
  static Future<void> recordSuccessfulScan([SharedPreferences? testPrefs]) async {
    final prefs = testPrefs ?? await SharedPreferences.getInstance();
    final history = await getRecentScanTimestamps(prefs);
    history.add(DateTime.now());

    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7));
    final pruned = history.where((dt) => dt.isAfter(cutoff)).toList();

    await prefs.setStringList(
      _scanHistoryKey,
      pruned.map((dt) => dt.toIso8601String()).toList(),
    );
  }

  /// Clears scan history (useful for tests and clean install reset).
  static Future<void> clearScanHistory([SharedPreferences? testPrefs]) async {
    final prefs = testPrefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_scanHistoryKey);
  }

  /// Downscales and compresses the timetable image before sending over the network.
  /// - Format: JPEG
  /// - Maximum bounds: 1600px width, 1200px height (preserving aspect ratio)
  /// - Quality: 80% (sharp text, ~200-300 KB file size)
  /// - Writes output to application's temporary cache directory.
  static Future<File> preprocessImage(File originalFile) async {
    try {
      if (!await originalFile.exists()) {
        return originalFile;
      }

      final bytes = await originalFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return originalFile;
      }

      int targetWidth = decoded.width;
      int targetHeight = decoded.height;
      const int maxW = 1600;
      const int maxH = 1200;

      if (targetWidth > maxW || targetHeight > maxH) {
        final double widthRatio = maxW / targetWidth;
        final double heightRatio = maxH / targetHeight;
        final double scale = widthRatio < heightRatio ? widthRatio : heightRatio;
        targetWidth = (targetWidth * scale).round();
        targetHeight = (targetHeight * scale).round();
      }

      final resized = (targetWidth != decoded.width || targetHeight != decoded.height)
          ? img.copyResize(
              decoded,
              width: targetWidth,
              height: targetHeight,
              interpolation: img.Interpolation.linear,
            )
          : decoded;

      final compressedBytes = img.encodeJpg(resized, quality: 80);

      Directory tempDir;
      try {
        tempDir = await getTemporaryDirectory();
      } catch (_) {
        tempDir = Directory.systemTemp;
      }

      final tempPath =
          '${tempDir.path}/timetable_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = File(tempPath);
      await compressedFile.writeAsBytes(compressedBytes, flush: true);

      return compressedFile;
    } catch (e) {
      // ignore: avoid_print
      print("IMAGE PREPROCESSING ERROR: $e");
      return originalFile;
    }
  }

  /// Parses timetable directly via Gemini 1.5 Flash.
  static Future<Map<String, dynamic>> parseTimetable(
    File imageFile, {
    GenerativeModel? customModel,
    SharedPreferences? customPrefs,
  }) async {
    // 1. Enforce on-device rate limiting
    await checkScanQuota(customPrefs);

    File? preprocessedFile;

    try {
      preprocessedFile = await preprocessImage(imageFile);
      final imageBytes = await preprocessedFile.readAsBytes();

      const prompt = '''
You are an expert university timetable extractor.
Analyze the timetable image and extract all lecture / class sessions into a valid JSON object.
Return JSON with this exact schema:
{
  "entries": [
    {
      "day": "Monday",
      "subject": "Course Name",
      "group": "Section / Group if specified",
      "start": "HH:MM",
      "end": "HH:MM",
      "room": "Room / Hall / Lab number",
      "teacher": "Instructor or Professor Name"
    }
  ]
}
Rules:
- Strictly output ONLY valid JSON matching the schema above.
- Ensure 24-hour time formats (HH:MM).
- Day must be Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, or Sunday.
- If teacher, room, or group is absent or unreadable, set to null.
''';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];

      GenerateContentResponse? response;
      Object? lastError;

      if (customModel != null) {
        response = await customModel
            .generateContent(content)
            .timeout(const Duration(seconds: 40));
      } else {
        for (final modelName in _candidateModels) {
          try {
            final model = GenerativeModel(
              model: modelName,
              apiKey: _geminiApiKey,
              generationConfig: GenerationConfig(
                responseMimeType: 'application/json',
                temperature: 0.0,
              ),
            );
            final candidateRes = await model
                .generateContent(content)
                .timeout(const Duration(seconds: 35));
            if (candidateRes.text != null && candidateRes.text!.trim().isNotEmpty) {
              response = candidateRes;
              break;
            }
          } catch (e) {
            lastError = e;
            // ignore: avoid_print
            print("Model $modelName attempt failed: $e. Trying next candidate...");
          }
        }
      }

      if (response == null || response.text == null || response.text!.trim().isEmpty) {
        if (lastError != null) {
          throw lastError;
        }
        throw const FormatException("Empty response received from AI scanner.");
      }

      final text = response.text!;

      // Isolate outermost JSON object
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) {
        throw const FormatException("No JSON object detected in response body.");
      }

      final jsonString = jsonMatch.group(0)!;
      final Map<String, dynamic> decoded = jsonDecode(jsonString);

      if (!decoded.containsKey("entries") && !decoded.containsKey("schedule")) {
        throw const FormatException("Missing both 'entries' and 'schedule' keys in response.");
      }

      // Record successful scan upon successful receipt and decoding
      await recordSuccessfulScan(customPrefs);

      return decoded;
    } on ScanLimitException {
      rethrow;
    } on TimeoutException catch (e) {
      // ignore: avoid_print
      print("REQUEST TIMEOUT: $e");
      throw Exception("NETWORK_TIMEOUT: Request timed out. The server took too long to respond.");
    } on SocketException catch (e) {
      // ignore: avoid_print
      print("SOCKET ERROR: $e");
      throw Exception("NETWORK_ERROR: Unable to connect to timetable server. Please check your internet.");
    } on FormatException catch (e) {
      // ignore: avoid_print
      print("JSON PARSE ERROR: $e");
      throw Exception("PARSER_FORMAT_ERROR: Failed to parse schedule from AI response: $e");
    } catch (e) {
      // ignore: avoid_print
      print("GEMINI INFERENCE ERROR: $e");
      final errStr = e.toString();
      if (errStr.contains('429') || errStr.contains('quota') || errStr.contains('QUOTA')) {
        throw const ScanLimitException("Daily or weekly scan limit reached.");
      }
      throw Exception("PARSER_ERROR: AI parsing failed: $e");
    } finally {
      if (preprocessedFile != null && preprocessedFile.path != imageFile.path) {
        try {
          if (await preprocessedFile.exists()) {
            await preprocessedFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  /// Converts either flat `entries` or legacy nested `schedule` into [ClassItem] models.
  static List<ClassItem> jsonToClassItems(Map<String, dynamic> json) {
    final List<ClassItem> items = [];
    final Map<String, int> subjectColorMap = {};

    // 1. Support for flat 'entries' schema
    if (json.containsKey('entries') && json['entries'] is List) {
      final rawEntries = json['entries'] as List<dynamic>;

      for (final raw in rawEntries) {
        if (raw is! Map<String, dynamic>) continue;

        String subject = raw['subject']?.toString().trim() ?? 'Untitled Class';
        final group = raw['group']?.toString().trim();
        if (group != null && group.isNotEmpty && !subject.toLowerCase().contains(group.toLowerCase())) {
          subject = "$subject ($group)";
        }

        final rawDay = raw['day']?.toString().trim() ?? 'Monday';
        final dayOfWeek = _normalizeDay(rawDay);

        final start = raw['start']?.toString().trim() ?? '08:30';
        final end = raw['end']?.toString().trim() ?? '10:00';

        final teacher = raw['teacher']?.toString().trim();
        final room = raw['room']?.toString().trim();

        final colorIndex = subjectColorMap.putIfAbsent(
          subject.toLowerCase(),
          () => subjectColorMap.length % 8,
        );

        items.add(
          ClassItem(
            id: const Uuid().v4(),
            subject: subject,
            subjectColorIndex: colorIndex,
            dayOfWeek: dayOfWeek,
            startTime: start,
            endTime: end,
            room: (room != null && room.isNotEmpty) ? room : null,
            teacher: (teacher != null && teacher.isNotEmpty) ? teacher : null,
          ),
        );
      }
      return items;
    }

    // 2. Fallback for legacy nested 'schedule' schema
    final rawSchedule = json['schedule'] as List<dynamic>? ?? [];

    for (final dayEntry in rawSchedule) {
      if (dayEntry is! Map<String, dynamic>) continue;
      final rawDay = dayEntry['day']?.toString().trim() ?? '';
      final normalizedDay = _normalizeDay(rawDay);
      final rawClasses = dayEntry['classes'] as List<dynamic>? ?? [];

      for (final lecture in rawClasses) {
        if (lecture is! Map<String, dynamic>) continue;
        final subject = lecture['subject']?.toString().trim() ?? 'Untitled Class';
        final timeStr = lecture['time']?.toString().trim() ?? '';
        final room = lecture['room']?.toString().trim();
        final teacher = lecture['teacher'] as String?;

        final colorIndex = subjectColorMap.putIfAbsent(
          subject.toLowerCase(),
          () => subjectColorMap.length % 8,
        );

        final parsedTimes = _parseTimeRange(timeStr);

        items.add(
          ClassItem(
            id: const Uuid().v4(),
            subject: subject,
            subjectColorIndex: colorIndex,
            dayOfWeek: normalizedDay,
            startTime: parsedTimes.$1,
            endTime: parsedTimes.$2,
            room: (room != null && room.isNotEmpty) ? room : null,
            teacher: (teacher != null && teacher.isNotEmpty) ? teacher : null,
          ),
        );
      }
    }

    return items;
  }

  static String _normalizeDay(String input) {
    final lower = input.toLowerCase();
    for (final day in ClassItem.daysOfWeek) {
      if (day.toLowerCase() == lower || day.toLowerCase().startsWith(lower)) {
        return day;
      }
    }
    return 'Monday';
  }

  static (String, String) _parseTimeRange(String timeStr) {
    if (timeStr.isEmpty) return ('08:30', '10:00');

    final separator = RegExp(r'\s*[-–—to]+\s*', caseSensitive: false);
    final parts = timeStr.split(separator);

    if (parts.length >= 2) {
      final start = _normalizeTime(parts[0]);
      final end = _normalizeTime(parts[1]);
      return (start, end);
    }

    final single = _normalizeTime(parts.first);
    return (single, _addDefaultDuration(single));
  }

  static String _normalizeTime(String raw) {
    final clean = raw.trim().toUpperCase();
    final isPm = clean.contains('PM');
    final isAm = clean.contains('AM');

    final numMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?').firstMatch(clean);
    if (numMatch == null) return '08:30';

    int hour = int.tryParse(numMatch.group(1) ?? '8') ?? 8;
    final int minute = int.tryParse(numMatch.group(2) ?? '30') ?? 30;

    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static String _addDefaultDuration(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '30') ?? 30;
    final newHour = (hour + 1) % 24;
    return '${newHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}