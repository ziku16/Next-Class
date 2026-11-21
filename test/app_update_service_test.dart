import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nextclass/domain/services/app_update_service.dart';

typedef RequestHandler = Future<http.StreamedResponse> Function(
  http.BaseRequest request,
);

class HandlerClient extends http.BaseClient {
  HandlerClient(this.handler);

  final RequestHandler handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

http.StreamedResponse _jsonResponse(
  http.BaseRequest request,
  Map<String, Object?> body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    statusCode,
    headers: headers,
    request: request,
  );
}

Map<String, Object?> _release({
  String tagName = 'v1.0.2',
  bool draft = false,
  bool prerelease = false,
  List<Map<String, Object?>>? assets,
}) {
  return {
    'tag_name': tagName,
    'draft': draft,
    'prerelease': prerelease,
    'body': '## What\'s New\n- Update test notes.',
    'assets':
        assets ??
        [
          {
            'name': 'NextClass-v1.0.2.apk',
            'state': 'uploaded',
            'size': 8,
            'content_type': 'application/vnd.android.package-archive',
            'browser_download_url': 'https://github.com/ziku16/Next-Class/releases/download/v1.0.2/NextClass-v1.0.2.apk',
            'digest': null,
          },
        ],
  };
}

AppUpdateRelease _downloadRelease({int sizeBytes = 8, String? sha256Digest}) {
  return AppUpdateRelease(
    version: '1.0.2',
    tagName: 'v1.0.2',
    notes: 'Update test notes.',
    assetName: 'NextClass-v1.0.2.apk',
    downloadUrl: 'https://github.com/ziku16/Next-Class/releases/download/v1.0.2/NextClass-v1.0.2.apk',
    sizeBytes: sizeBytes,
    sha256Digest: sha256Digest,
  );
}

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'nextclass-update-test-',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('reports the latest stable release as already up to date', () async {
    final service = AppUpdateService(
      client: HandlerClient(
        (request) async => _jsonResponse(request, _release(tagName: 'v1.0.1')),
      ),
      updateDirectoryProvider: () async => tempDirectory,
    );

    final result = await service.checkForUpdate(installedVersion: '1.0.1+2');

    expect(result.isUpToDate, isTrue);
    expect(result.release, isNull);
  });

  test('returns the exact new APK asset and release notes when a stable update exists', () async {
    final service = AppUpdateService(
      client: HandlerClient(
        (request) async => _jsonResponse(request, _release()),
      ),
      updateDirectoryProvider: () async => tempDirectory,
    );

    final result = await service.checkForUpdate(installedVersion: '1.0.1+2');

    expect(result.isUpToDate, isFalse);
    expect(result.release?.version, '1.0.2');
    expect(result.release?.assetName, 'NextClass-v1.0.2.apk');
    expect(result.release?.notes, contains('Update test notes.'));
  });

  test('ignores draft and prerelease GitHub results', () async {
    for (final release in [
      _release(draft: true),
      _release(prerelease: true),
      _release(tagName: 'v1.0.2-rc.1'),
    ]) {
      final service = AppUpdateService(
        client: HandlerClient(
          (request) async => _jsonResponse(request, release),
        ),
        updateDirectoryProvider: () async => tempDirectory,
      );

      final result = await service.checkForUpdate(installedVersion: '1.0.1+2');

      expect(result.isUpToDate, isTrue);
      expect(result.release, isNull);
    }
  });

  test('reports a missing version-matched APK asset', () async {
    final service = AppUpdateService(
      client: HandlerClient(
        (request) async => _jsonResponse(
          request,
          _release(
            assets: [
              {
                'name': 'NextClass-v1.0.1.apk',
                'state': 'uploaded',
                'size': 8,
                'browser_download_url': 'https://github.com/ziku16/Next-Class/releases/download/v1.0.2/NextClass-v1.0.1.apk',
              },
            ],
          ),
        ),
      ),
      updateDirectoryProvider: () async => tempDirectory,
    );

    await expectLater(
      service.checkForUpdate(installedVersion: '1.0.1'),
      throwsA(
        isA<AppUpdateException>().having(
          (error) => error.kind,
          'kind',
          AppUpdateFailure.missingApk,
        ),
      ),
    );
  });

  test('distinguishes GitHub API rate limits and service errors', () async {
    final rateLimited = AppUpdateService(
      client: HandlerClient(
        (request) async => _jsonResponse(
          request,
          {'message': 'API rate limit exceeded'},
          statusCode: 403,
          headers: {'x-ratelimit-remaining': '0'},
        ),
      ),
      updateDirectoryProvider: () async => tempDirectory,
    );
    final unavailable = AppUpdateService(
      client: HandlerClient(
        (request) async => _jsonResponse(request, {
          'message': 'temporary failure',
        }, statusCode: 503),
      ),
      updateDirectoryProvider: () async => tempDirectory,
    );

    await expectLater(
      rateLimited.checkForUpdate(installedVersion: '1.0.1'),
      throwsA(
        isA<AppUpdateException>().having(
          (error) => error.kind,
          'kind',
          AppUpdateFailure.rateLimited,
        ),
      ),
    );
    await expectLater(
      unavailable.checkForUpdate(installedVersion: '1.0.1'),
      throwsA(
        isA<AppUpdateException>().having(
          (error) => error.kind,
          'kind',
          AppUpdateFailure.apiUnavailable,
        ),
      ),
    );
  });

  test(
    'downloads a complete APK, checks its digest, and reports progress',
    () async {
      final bytes = Uint8List.fromList([0x50, 0x4b, 0x03, 0x04, 1, 2, 3, 4]);
      final digest = sha256.convert(bytes).toString();
      final service = AppUpdateService(
        client: HandlerClient(
          (request) async => http.StreamedResponse(
            Stream.fromIterable([bytes.sublist(0, 4), bytes.sublist(4)]),
            200,
            contentLength: bytes.length,
            request: request,
          ),
        ),
        updateDirectoryProvider: () async => tempDirectory,
      );
      final progress = <(int, int)>[];

      final file = await service.downloadUpdate(
        _downloadRelease(sha256Digest: digest),
        onProgress: (received, total) => progress.add((received, total)),
      );

      expect(file.path, endsWith('NextClass-v1.0.2.apk'));
      expect(await file.readAsBytes(), bytes);
      expect(progress.last, (bytes.length, bytes.length));
    },
  );

  test(
    'deletes partial files when downloads fail or the checksum is wrong',
    () async {
      final bytes = Uint8List.fromList([0x50, 0x4b, 0x03, 0x04, 1, 2, 3, 4]);
      final service = AppUpdateService(
        client: HandlerClient(
          (request) async => http.StreamedResponse(
            Stream.value(bytes),
            200,
            contentLength: bytes.length,
            request: request,
          ),
        ),
        updateDirectoryProvider: () async => tempDirectory,
      );

      await expectLater(
        service.downloadUpdate(_downloadRelease(sha256Digest: '0' * 64)),
        throwsA(
          isA<AppUpdateException>().having(
            (error) => error.kind,
            'kind',
            AppUpdateFailure.integrityFailure,
          ),
        ),
      );
      expect(await tempDirectory.list().isEmpty, isTrue);
    },
  );

  test('handles server errors and interrupted APK streams', () async {
    final serverError = AppUpdateService(
      client: HandlerClient(
        (request) async => http.StreamedResponse(
          const Stream<List<int>>.empty(),
          503,
          request: request,
        ),
      ),
      updateDirectoryProvider: () async => tempDirectory,
    );
    final interrupted = AppUpdateService(
      client: HandlerClient(
        (request) async => http.StreamedResponse(
          Stream<List<int>>.error(const SocketException('connection lost')),
          200,
          request: request,
        ),
      ),
      updateDirectoryProvider: () async => tempDirectory,
    );

    await expectLater(
      serverError.downloadUpdate(_downloadRelease()),
      throwsA(
        isA<AppUpdateException>().having(
          (error) => error.kind,
          'kind',
          AppUpdateFailure.downloadFailed,
        ),
      ),
    );
    await expectLater(
      interrupted.downloadUpdate(_downloadRelease()),
      throwsA(
        isA<AppUpdateException>().having(
          (error) => error.kind,
          'kind',
          AppUpdateFailure.networkUnavailable,
        ),
      ),
    );
    expect(await tempDirectory.list().isEmpty, isTrue);
  });

  test(
    'reports insufficient temporary storage with a student-friendly error',
    () async {
      final bytes = Uint8List.fromList([0x50, 0x4b, 0x03, 0x04, 1, 2, 3, 4]);
      final service = AppUpdateService(
        client: HandlerClient(
          (request) async => http.StreamedResponse(
            Stream.value(bytes),
            200,
            contentLength: bytes.length,
            request: request,
          ),
        ),
        updateDirectoryProvider: () async =>
            throw const FileSystemException('No space left on device'),
      );

      await expectLater(
        service.downloadUpdate(_downloadRelease()),
        throwsA(
          isA<AppUpdateException>().having(
            (error) => error.kind,
            'kind',
            AppUpdateFailure.insufficientStorage,
          ),
        ),
      );
    },
  );
}
