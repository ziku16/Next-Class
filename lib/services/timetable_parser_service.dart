import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
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

  /// Downscales and compresses the timetable image before sending over the network.
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

  static Future<Map<String, dynamic>> parseTimetable(File imageFile) async {
    File? preprocessedFile;

    try {
      preprocessedFile = await preprocessImage(imageFile);
      final fileToUpload = preprocessedFile;

      final deviceId = await _getOrCreateDeviceId();

      final request = http.MultipartRequest('POST', Uri.parse(_workerUrl))
        ..headers['X-Device-ID'] = deviceId
        ..files.add(await http.MultipartFile.fromPath('image', fileToUpload.path));

      // 65-second client timeout provides ample headroom for Google inference
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 65));
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(const Duration(seconds: 65));

      if (response.statusCode == 200) {
        // ignore: avoid_print
        print("RAW CLOUDFLARE RESPONSE:\n${response.body}");

        try {
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response.body);

          if (jsonMatch == null) {
            throw const FormatException("No JSON object detected in response body.");
          }

          final jsonString = jsonMatch.group(0)!;
          final Map<String, dynamic> decoded = jsonDecode(jsonString);

          // Support both new 'entries' and legacy 'schedule' payload structures
          if (!decoded.containsKey("entries") && !decoded.containsKey("schedule")) {
            throw const FormatException("Missing both 'entries' and 'schedule' keys in response.");
          }

          return decoded;
        } on FormatException catch (e) {
          // ignore: avoid_print
          print("JSON PARSE ERROR: $e");
          throw Exception("PARSER_FORMAT_ERROR: Failed to parse schedule from AI response.");
        }
      } else if (response.statusCode == 429) {
        throw Exception("RATE_LIMIT_EXCEEDED: Daily or weekly scan limit reached.");
      } else if (response.statusCode == 500) {
        throw Exception("SERVER_ERROR_500: Server encountered an error processing your timetable.");
      } else if (response.statusCode == 504) {
        throw Exception("SERVER_ERROR_504: Gateway timeout from timetable parser backend.");
      } else {
        throw Exception("SERVER_ERROR_${response.statusCode}: Request failed with status code${response.statusCode}.");
      }
    } on TimeoutException catch (e) {
      // ignore: avoid_print
      print("REQUEST TIMEOUT: $e");
      throw Exception("NETWORK_TIMEOUT: Request timed out. The server took too long to respond.");
    } on SocketException catch (e) {
      // ignore: avoid_print
      print("SOCKET ERROR: $e");
      throw Exception("NETWORK_ERROR: Unable to connect to timetable server. Please check your internet.");
    } on http.ClientException catch (e) {
      // ignore: avoid_print
      print("HTTP CLIENT ERROR: $e");
      throw Exception("NETWORK_ERROR: Network connection failed: ${e.message}");
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

    // 1. Support for the new Worker's flat 'entries' schema
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