import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/models/class_item.dart';

enum TimetableScanFailure {
  configuration,
  authentication,
  modelUnavailable,
  apiQuotaExceeded,
  invalidRequest,
  serviceUnavailable,
  timeout,
  network,
  unreadableImage,
  malformedResponse,
  invalidSchema,
  emptyResult,
}

class TimetableScanException implements Exception {
  final TimetableScanFailure failure;
  final int? statusCode;

  const TimetableScanException(this.failure, {this.statusCode});

  @override
  String toString() =>
      'TimetableScanException: ${failure.name}${statusCode == null ? '' : ' (HTTP $statusCode)'}';
}

class TimetableParserService {
  static const String _workerBaseUrl = String.fromEnvironment(
    'NEXTCLASS_WORKER_URL',
  );

  /// Downscales and compresses the timetable image before sending over the network.
  /// - Format: JPEG
  /// - Maximum bounds: 1600px width, 1200px height (preserving aspect ratio)
  /// - Quality: 80% (sharp text, ~200-300 KB file size)
  /// - Writes output to application's temporary cache directory.
  static Future<File> preprocessImage(File originalFile) async {
    try {
      if (!await originalFile.exists()) return originalFile;
      final bytes = await originalFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return originalFile;
      int targetWidth = decoded.width;
      int targetHeight = decoded.height;
      const maxW = 1600;
      const maxH = 1200;
      if (targetWidth > maxW || targetHeight > maxH) {
        final scale = min(maxW / targetWidth, maxH / targetHeight);
        targetWidth = (targetWidth * scale).round();
        targetHeight = (targetHeight * scale).round();
      }
      final resized =
          targetWidth != decoded.width || targetHeight != decoded.height
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
      final compressedFile = File(
        '${tempDir.path}/timetable_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await compressedFile.writeAsBytes(compressedBytes, flush: true);
      return compressedFile;
    } catch (_) {
      debugPrint('[TimetableAI] category=image_preprocess_failed');
      return originalFile;
    }
  }

  /// Sends a timetable image through the configured NextClass Worker.
  static Future<Map<String, dynamic>> parseTimetable(
    File imageFile, {
    http.Client? httpClient,
    String? workerBaseUrlOverride,
    Duration requestTimeout = const Duration(seconds: 40),
  }) async {
    final baseUrl = (workerBaseUrlOverride ?? _workerBaseUrl).trim();
    if (baseUrl.isEmpty) {
      throw const TimetableScanException(TimetableScanFailure.configuration);
    }
    final client = httpClient ?? http.Client();
    final ownsClient = httpClient == null;
    File? preprocessedFile;
    try {
      preprocessedFile = await preprocessImage(imageFile);
      final imageBytes = await preprocessedFile.readAsBytes();
      if (imageBytes.isEmpty) {
        throw const TimetableScanException(
          TimetableScanFailure.unreadableImage,
        );
      }
      final response = await client
          .post(
            Uri.parse(
              '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/v1/extract/timetable',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Idempotency-Key': const Uuid().v4(),
            },
            body: jsonEncode({
              'image': {
                'mimeType': _mimeTypeForImage(preprocessedFile),
                'data': base64Encode(imageBytes),
              },
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TimetableScanException(
          _failureForHttpStatus(response.statusCode),
          statusCode: response.statusCode,
        );
      }
      final envelope = jsonDecode(response.body);
      if (envelope is! Map<String, dynamic> ||
          envelope['ok'] != true ||
          envelope['data'] is! Map) {
        throw const TimetableScanException(
          TimetableScanFailure.malformedResponse,
        );
      }
      return decodeTimetableResponse(jsonEncode(envelope['data']));
    } on TimetableScanException catch (error) {
      _logFailure(error.failure, statusCode: error.statusCode);
      rethrow;
    } on TimeoutException {
      const error = TimetableScanException(TimetableScanFailure.timeout);
      _logFailure(error.failure);
      throw error;
    } on FormatException {
      const error = TimetableScanException(
        TimetableScanFailure.malformedResponse,
      );
      _logFailure(error.failure);
      throw error;
    } on SocketException {
      const error = TimetableScanException(TimetableScanFailure.network);
      _logFailure(error.failure);
      throw error;
    } on http.ClientException {
      const error = TimetableScanException(TimetableScanFailure.network);
      _logFailure(error.failure);
      throw error;
    } finally {
      if (ownsClient) client.close();
      if (preprocessedFile != null && preprocessedFile.path != imageFile.path) {
        try {
          if (await preprocessedFile.exists()) await preprocessedFile.delete();
        } catch (_) {}
      }
    }
  }

  static TimetableScanFailure _failureForHttpStatus(int statusCode) =>
      switch (statusCode) {
        400 || 422 => TimetableScanFailure.invalidRequest,
        408 || 504 => TimetableScanFailure.timeout,
        401 || 403 => TimetableScanFailure.authentication,
        404 => TimetableScanFailure.modelUnavailable,
        429 => TimetableScanFailure.apiQuotaExceeded,
        >= 500 => TimetableScanFailure.serviceUnavailable,
        _ => TimetableScanFailure.serviceUnavailable,
      };
  static Map<String, dynamic> decodeTimetableResponse(String responseText) {
    final jsonText = _extractJsonObject(responseText);
    if (jsonText == null) {
      throw const TimetableScanException(
        TimetableScanFailure.malformedResponse,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      throw const TimetableScanException(
        TimetableScanFailure.malformedResponse,
      );
    }
    if (decoded is! Map<String, dynamic> || decoded['entries'] is! List) {
      throw const TimetableScanException(TimetableScanFailure.invalidSchema);
    }
    final entries = decoded['entries'] as List;
    if (entries.isEmpty) {
      throw const TimetableScanException(TimetableScanFailure.emptyResult);
    }
    for (final entry in entries) {
      if (entry is! Map<String, dynamic> || !_isValidEntry(entry)) {
        throw const TimetableScanException(TimetableScanFailure.invalidSchema);
      }
    }
    return decoded;
  }

  static String? _extractJsonObject(String response) {
    var source = response.trim();
    if (source.startsWith('```')) {
      final firstNewline = source.indexOf('\n');
      if (firstNewline < 0) return null;
      source = source.substring(firstNewline + 1).trim();
      if (source.endsWith('```')) {
        source = source.substring(0, source.length - 3).trim();
      }
    }
    final start = source.indexOf('{');
    if (start < 0) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var index = start; index < source.length; index++) {
      final code = source.codeUnitAt(index);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (code == 0x5c) {
          escaped = true;
        } else if (code == 0x22) {
          inString = false;
        }
        continue;
      }
      if (code == 0x22) {
        inString = true;
      } else if (code == 0x7b) {
        depth++;
      } else if (code == 0x7d && --depth == 0) {
        return source.substring(start, index + 1);
      }
    }
    return null;
  }

  static bool _isValidEntry(Map<String, dynamic> entry) {
    const requiredFields = [
      'day',
      'subject',
      'group',
      'start',
      'end',
      'room',
      'teacher',
    ];
    if (requiredFields.any((field) => !entry.containsKey(field))) return false;
    final day = entry['day'];
    final subject = entry['subject'];
    final start = entry['start'];
    final end = entry['end'];
    if (day is! String || !ClassItem.daysOfWeek.contains(day)) return false;
    if (subject is! String || subject.trim().isEmpty) return false;
    if (start is! String ||
        end is! String ||
        !_isValid24HourTime(start) ||
        !_isValid24HourTime(end)) {
      return false;
    }
    if (_minutesFromTime(end) <= _minutesFromTime(start)) return false;
    for (final field in ['group', 'room', 'teacher']) {
      if (entry[field] != null && entry[field] is! String) return false;
    }
    return true;
  }

  static bool _isValid24HourTime(String value) =>
      RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

  static int _minutesFromTime(String value) {
    final parts = value.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  static String _mimeTypeForImage(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => throw const TimetableScanException(
        TimetableScanFailure.unreadableImage,
      ),
    };
  }

  static void _logFailure(
    TimetableScanFailure failure, {
    int? statusCode,
    int? attempt,
    bool retrying = false,
  }) {
    debugPrint(
      '[TimetableAI] category=${statusCode == null ? failure.name : 'http_$statusCode'} '
      'failure=${failure.name} attempt=${attempt ?? 1} retrying=$retrying',
    );
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
        if (group != null &&
            group.isNotEmpty &&
            !subject.toLowerCase().contains(group.toLowerCase())) {
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
        final subject =
            lecture['subject']?.toString().trim() ?? 'Untitled Class';
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
