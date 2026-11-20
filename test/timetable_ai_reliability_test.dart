import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:nextclass/services/timetable_parser_service.dart';

const _validEntry = {
  'day': 'Monday',
  'subject': 'Computer Science',
  'group': null,
  'start': '09:00',
  'end': '10:30',
  'room': 'Lab 2',
  'teacher': null,
};

void main() {
  late File image;
  setUp(() async {
    final raw = img.Image(width: 32, height: 24);
    img.fill(raw, color: img.ColorRgb8(255, 255, 255));
    image = File('${Directory.systemTemp.path}/nextclass-ai-test.png');
    await image.writeAsBytes(img.encodePng(raw));
  });
  tearDown(() async {
    if (await image.exists()) await image.delete();
  });

  group('Timetable Worker response validation', () {
    test('decodes flat timetable entries', () {
      final decoded = TimetableParserService.decodeTimetableResponse(
        jsonEncode({
          'entries': [_validEntry],
        }),
      );
      expect(decoded['entries'], hasLength(1));
      expect(decoded['entries'].first['subject'], 'Computer Science');
    });
    test('rejects malformed, invalid and empty results', () {
      expect(
        () => TimetableParserService.decodeTimetableResponse('{bad}'),
        throwsA(isA<TimetableScanException>()),
      );
      expect(
        () => TimetableParserService.decodeTimetableResponse('{"classes":[]}'),
        throwsA(isA<TimetableScanException>()),
      );
      expect(
        () => TimetableParserService.decodeTimetableResponse('{"entries":[]}'),
        throwsA(isA<TimetableScanException>()),
      );
      for (final entry in [
        {..._validEntry}..remove('subject'),
        {..._validEntry, 'day': 'Someday'},
        {..._validEntry, 'start': '29:88'},
        {..._validEntry, 'end': '09:00'},
      ]) {
        expect(
          () => TimetableParserService.decodeTimetableResponse(
            jsonEncode({
              'entries': [entry],
            }),
          ),
          throwsA(isA<TimetableScanException>()),
        );
      }
    });
  });

  group('Timetable Worker HTTP handling', () {
    test(
      'sends one idempotent image request and parses validated Worker data',
      () async {
        var requests = 0;
        final client = MockClient((request) async {
          requests++;
          expect(
            request.url.toString(),
            'https://worker.test/v1/extract/timetable',
          );
          expect(request.headers['content-type'], 'application/json');
          expect(
            request.headers['idempotency-key'],
            matches(RegExp(r'^[0-9a-f-]{36}$')),
          );
          expect(request.headers.containsKey('x-goog-api-key'), isFalse);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['image']['mimeType'], 'image/jpeg');
          expect(base64Decode(body['image']['data']), isNotEmpty);
          return http.Response(
            jsonEncode({
              'ok': true,
              'requestId': 'worker-id',
              'data': {
                'entries': [_validEntry],
              },
            }),
            200,
          );
        });
        final result = await TimetableParserService.parseTimetable(
          image,
          httpClient: client,
          workerBaseUrlOverride: 'https://worker.test/',
        );
        expect(result['entries'], hasLength(1));
        expect(requests, 1);
      },
    );

    test('maps Worker auth, invalid document, quota, timeout and server errors without retries', () async {
      for (final status in [401, 403, 404, 422, 429, 503, 504]) {
        var requests = 0;
        final client = MockClient((_) async {
          requests++;
          return http.Response('{"ok":false}', status);
        });
        await expectLater(
          TimetableParserService.parseTimetable(
            image,
            httpClient: client,
            workerBaseUrlOverride: 'https://worker.test',
          ),
          throwsA(isA<TimetableScanException>()),
        );
        expect(
          requests,
          1,
          reason: 'HTTP $status must not trigger a duplicate scan',
        );
      }
    });

    test('maps offline and timeout failures for students', () async {
      final offline = MockClient(
        (_) async => throw http.ClientException('offline'),
      );
      await expectLater(
        TimetableParserService.parseTimetable(
          image,
          httpClient: offline,
          workerBaseUrlOverride: 'https://worker.test',
        ),
        throwsA(
          isA<TimetableScanException>().having(
            (error) => error.failure,
            'failure',
            TimetableScanFailure.network,
          ),
        ),
      );
      final slow = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        return http.Response('', 200);
      });
      await expectLater(
        TimetableParserService.parseTimetable(
          image,
          httpClient: slow,
          workerBaseUrlOverride: 'https://worker.test',
          requestTimeout: const Duration(milliseconds: 5),
        ),
        throwsA(
          isA<TimetableScanException>().having(
            (error) => error.failure,
            'failure',
            TimetableScanFailure.timeout,
          ),
        ),
      );
    });
  });
}
