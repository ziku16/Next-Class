import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/models/class_item.dart';

class TimetableParserService {
  static const String _workerUrl = "https://nextclass-parser.muhammadzakriaawan237.workers.dev/";

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString("DEVICE_ID");
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString("DEVICE_ID", deviceId);
    }
    return deviceId;
  }

  static Future<Map<String, dynamic>> parseTimetable(File imageFile) async {
    final deviceId = await _getOrCreateDeviceId();

    final request = http.MultipartRequest('POST', Uri.parse(_workerUrl))
      ..headers['X-Device-ID'] = deviceId
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 429) {
      throw Exception("RATE_LIMIT_EXCEEDED");
    } else {
      throw Exception("SERVER_ERROR_${response.statusCode}");
    }
  }

  /// Converts the raw Cloudflare JSON response into a list of [ClassItem] domain models.
  static List<ClassItem> jsonToClassItems(Map<String, dynamic> json) {
    final rawSchedule = json['schedule'] as List<dynamic>? ?? [];
    final List<ClassItem> items = [];
    final Map<String, int> subjectColorMap = {};

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
    if (timeStr.isEmpty) return ('09:00', '10:30');

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
    if (numMatch == null) return '09:00';

    int hour = int.tryParse(numMatch.group(1) ?? '9') ?? 9;
    final int minute = int.tryParse(numMatch.group(2) ?? '00') ?? 0;

    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static String _addDefaultDuration(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final newHour = (hour + 1) % 24;
    return '${newHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
