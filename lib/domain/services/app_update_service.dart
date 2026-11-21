import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'semantic_version.dart';

enum AppUpdateFailure {
  noStableRelease,
  invalidRelease,
  missingApk,
  rateLimited,
  apiUnavailable,
  networkUnavailable,
  downloadFailed,
  integrityFailure,
  insufficientStorage,
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.kind, this.message);

  final AppUpdateFailure kind;
  final String message;

  @override
  String toString() => message;
}

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.version,
    required this.tagName,
    required this.notes,
    required this.assetName,
    required this.downloadUrl,
    required this.sizeBytes,
    this.sha256Digest,
  });

  final String version;
  final String tagName;
  final String notes;
  final String assetName;
  final String downloadUrl;
  final int sizeBytes;
  final String? sha256Digest;
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult.upToDate(this.installedVersion) : release = null;

  const AppUpdateCheckResult.available(this.installedVersion, this.release);

  final String installedVersion;
  final AppUpdateRelease? release;

  bool get isUpToDate => release == null;
}

class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    Future<Directory> Function()? updateDirectoryProvider,
    Uri? latestReleaseUri,
  }) : _client = client ?? http.Client(),
       _updateDirectoryProvider =
           updateDirectoryProvider ?? _defaultUpdateDirectory,
       _latestReleaseUri = latestReleaseUri ?? _defaultLatestReleaseUri;

  static const repositoryOwner = 'ziku16';
  static const repositoryName = 'Next-Class';
  static const packageName = 'com.nextclass.app';
  static const requestTimeout = Duration(seconds: 20);

  static final Uri _defaultLatestReleaseUri = Uri.https(
    'api.github.com',
    '/repos/$repositoryOwner/$repositoryName/releases/latest',
  );

  final http.Client _client;
  final Future<Directory> Function() _updateDirectoryProvider;
  final Uri _latestReleaseUri;

  static Future<Directory> _defaultUpdateDirectory() async {
    final temporaryDirectory = await getTemporaryDirectory();
    return Directory(path.join(temporaryDirectory.path, 'nextclass_updates'));
  }

  Future<AppUpdateCheckResult> checkForUpdate({
    required String installedVersion,
  }) async {
    final current = SemanticVersion.tryParse(installedVersion);
    if (current == null || current.prerelease != null) {
      throw const AppUpdateException(
        AppUpdateFailure.invalidRelease,
        'The installed app version could not be checked. Please try again later.',
      );
    }

    late http.Response response;
    try {
      response = await _client
          .get(
            _latestReleaseUri,
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(requestTimeout);
    } on SocketException {
      throw _networkException();
    } on http.ClientException {
      throw _networkException();
    } on TimeoutException {
      throw _networkException();
    }

    if (response.statusCode == 404) {
      throw const AppUpdateException(
        AppUpdateFailure.noStableRelease,
        'A stable update could not be found right now. Please try again later.',
      );
    }
    if (response.statusCode == 429 ||
        (response.statusCode == 403 &&
            response.headers['x-ratelimit-remaining'] == '0')) {
      throw const AppUpdateException(
        AppUpdateFailure.rateLimited,
        'Update checks are busy right now. Please try again in a little while.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AppUpdateException(
        AppUpdateFailure.apiUnavailable,
        'Could not check for updates right now. Please try again later.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw _invalidReleaseException();
    }
    if (decoded is! Map<String, dynamic>) {
      throw _invalidReleaseException();
    }
    if (decoded['draft'] == true || decoded['prerelease'] == true) {
      return AppUpdateCheckResult.upToDate(installedVersion);
    }

    final tagName = decoded['tag_name'];
    final latest = tagName is String ? SemanticVersion.tryParse(tagName) : null;
    if (latest == null) throw _invalidReleaseException();
    if (latest.prerelease != null) {
      return AppUpdateCheckResult.upToDate(installedVersion);
    }
    if (latest <= current) {
      return AppUpdateCheckResult.upToDate(installedVersion);
    }

    final version = latest.toString();
    final expectedName = apkNameForVersion(version);
    final assets = decoded['assets'];
    if (assets is! List) throw _invalidReleaseException();
    Map<String, dynamic>? asset;
    for (final item in assets) {
      if (item is Map<String, dynamic> && item['name'] == expectedName) {
        asset = item;
        break;
      }
    }
    if (asset == null ||
        (asset['state'] != null && asset['state'] != 'uploaded')) {
      throw const AppUpdateException(
        AppUpdateFailure.missingApk,
        'The update is listed, but its APK is not available yet. Please try again later.',
      );
    }

    final downloadUrl = asset['browser_download_url'];
    final sizeBytes = asset['size'];
    if (downloadUrl is! String || sizeBytes is! int || sizeBytes <= 0) {
      throw _invalidReleaseException();
    }
    final expectedDownloadUrl = Uri.https(
      'github.com',
      '/$repositoryOwner/$repositoryName/releases/download/$tagName/$expectedName',
    );
    if (Uri.tryParse(downloadUrl) != expectedDownloadUrl) {
      throw _invalidReleaseException();
    }

    String? digest;
    final rawDigest = asset['digest'];
    if (rawDigest != null) {
      if (rawDigest is! String) throw _invalidReleaseException();
      final match = RegExp(
        r'^sha256:([a-f0-9]{64})$',
        caseSensitive: false,
      ).firstMatch(rawDigest);
      if (match == null) throw _invalidReleaseException();
      digest = match.group(1)!.toLowerCase();
    }

    final notes = decoded['body'];
    return AppUpdateCheckResult.available(
      installedVersion,
      AppUpdateRelease(
        version: version,
        tagName: tagName,
        notes: notes is String ? notes : '',
        assetName: expectedName,
        downloadUrl: downloadUrl,
        sizeBytes: sizeBytes,
        sha256Digest: digest,
      ),
    );
  }

  Future<File> downloadUpdate(
    AppUpdateRelease release, {
    void Function(int receivedBytes, int totalBytes)? onProgress,
  }) async {
    final expectedName = apkNameForVersion(release.version);
    final expectedUrl = Uri.https(
      'github.com',
      '/$repositoryOwner/$repositoryName/releases/download/${release.tagName}/$expectedName',
    );
    if (release.assetName != expectedName ||
        Uri.tryParse(release.downloadUrl) != expectedUrl ||
        release.sizeBytes <= 0) {
      throw _invalidReleaseException();
    }

    final request = http.Request('GET', expectedUrl);
    late http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(requestTimeout);
    } on SocketException {
      throw _networkException();
    } on http.ClientException {
      throw _networkException();
    } on TimeoutException {
      throw _networkException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AppUpdateException(
        AppUpdateFailure.downloadFailed,
        'The update download could not be started. Please try again.',
      );
    }
    if (response.contentLength != null &&
        response.contentLength != release.sizeBytes) {
      throw _integrityException();
    }

    File? file;
    IOSink? sink;
    try {
      final directory = await _updateDirectoryProvider();
      await directory.create(recursive: true);
      file = File(path.join(directory.path, expectedName));
      if (await file.exists()) await file.delete();
      sink = file.openWrite();
      var receivedBytes = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        receivedBytes += chunk.length;
        if (receivedBytes > release.sizeBytes) throw _integrityException();
        sink.add(chunk);
        onProgress?.call(receivedBytes, release.sizeBytes);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (receivedBytes != release.sizeBytes) throw _integrityException();
      if (!await _hasApkZipHeader(file)) throw _integrityException();
      if (release.sha256Digest != null) {
        final digest = await sha256.bind(file.openRead()).first;
        if (digest.toString() != release.sha256Digest) {
          throw _integrityException();
        }
      }
      return file;
    } on AppUpdateException {
      await _removePartialFile(file, sink);
      rethrow;
    } on FileSystemException catch (error) {
      await _removePartialFile(file, sink);
      final noSpace =
          error.osError?.errorCode == 28 ||
          error.message.toLowerCase().contains('no space');
      if (noSpace) {
        throw const AppUpdateException(
          AppUpdateFailure.insufficientStorage,
          'There is not enough free space to download the update. Free some storage and try again.',
        );
      }
      throw const AppUpdateException(
        AppUpdateFailure.downloadFailed,
        'The update could not be saved. Check available storage and try again.',
      );
    } on SocketException {
      await _removePartialFile(file, sink);
      throw _networkException();
    } on http.ClientException {
      await _removePartialFile(file, sink);
      throw _networkException();
    } on TimeoutException {
      await _removePartialFile(file, sink);
      throw _networkException();
    } catch (_) {
      await _removePartialFile(file, sink);
      throw const AppUpdateException(
        AppUpdateFailure.downloadFailed,
        'The update download did not finish. Please check your connection and try again.',
      );
    }
  }

  void close() => _client.close();

  static String apkNameForVersion(String version) {
    final parsed = SemanticVersion.tryParse(version);
    if (parsed == null || parsed.prerelease != null) {
      throw _invalidReleaseException();
    }
    return 'NextClass-v$parsed.apk';
  }

  static Future<bool> _hasApkZipHeader(File file) async {
    final bytes = await file.openRead(0, 4).first;
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  static Future<void> _removePartialFile(File? file, IOSink? sink) async {
    try {
      await sink?.close();
    } catch (_) {
      // Keep the original update error.
    }
    try {
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {
      // Keep the original update error.
    }
  }

  static AppUpdateException _networkException() => const AppUpdateException(
    AppUpdateFailure.networkUnavailable,
    'No internet connection. Connect to the internet and try again.',
  );

  static AppUpdateException _invalidReleaseException() =>
      const AppUpdateException(
        AppUpdateFailure.invalidRelease,
        'The update details could not be verified. Please try again later.',
      );

  static AppUpdateException _integrityException() => const AppUpdateException(
    AppUpdateFailure.integrityFailure,
    'The downloaded update failed its integrity check and was discarded. Please try again.',
  );
}
