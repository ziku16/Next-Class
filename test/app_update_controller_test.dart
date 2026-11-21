import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nextclass/domain/services/app_update_service.dart';
import 'package:nextclass/platform/app_update_platform.dart';
import 'package:nextclass/state/app_update_controller.dart';

class HandlerClient extends http.BaseClient {
  HandlerClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

class FakeAppUpdatePlatform implements AppUpdatePlatform {
  String installedVersion = '1.0.1+2';
  bool canInstall = true;
  String? installPath;
  int permissionSettingsOpened = 0;
  final List<PackageInstallStatus> statuses = [];

  @override
  Future<bool> canRequestPackageInstalls() async => canInstall;

  @override
  Future<bool> launchSupportEmail(String email) async => true;

  @override
  Future<String> getInstalledVersion() async => installedVersion;

  @override
  Future<void> openInstallPermissionSettings() async {
    permissionSettingsOpened++;
  }

  @override
  Future<PackageInstallStatus?> consumeInstallerStatus() async =>
      statuses.isEmpty ? null : statuses.removeAt(0);

  @override
  Future<void> startPackageInstall(String apkPath) async {
    installPath = apkPath;
  }
}

Map<String, Object?> _release() => {
  'tag_name': 'v1.0.2',
  'draft': false,
  'prerelease': false,
  'body': '## What\'s New\n- Easier timetable scanning.',
  'assets': [
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

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'nextclass-update-controller-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  AppUpdateService serviceFor({required String latestTag}) {
    final apkBytes = Uint8List.fromList([0x50, 0x4b, 0x03, 0x04, 1, 2, 3, 4]);
    final digest = sha256.convert(apkBytes).toString();
    return AppUpdateService(
      client: HandlerClient((request) async {
        if (request.url.path.endsWith('/releases/latest')) {
          final release = _release()..['tag_name'] = latestTag;
          final assets = release['assets'] as List<Map<String, Object?>>;
          assets[0]['name'] =
              'NextClass-v${latestTag.replaceFirst(RegExp(r'^[vV]'), '')}.apk';
          assets[0]['browser_download_url'] =
              'https://github.com/ziku16/Next-Class/releases/download/$latestTag/${assets[0]['name']}';
          assets[0]['size'] = apkBytes.length;
          assets[0]['digest'] = 'sha256:$digest';
          final body = utf8.encode(jsonEncode(release));
          return http.StreamedResponse(
            Stream.value(body),
            200,
            request: request,
          );
        }
        return http.StreamedResponse(
          Stream.value(apkBytes),
          200,
          contentLength: apkBytes.length,
          request: request,
        );
      }),
      updateDirectoryProvider: () async => temporaryDirectory,
    );
  }

  test('shows the up-to-date message after an explicit check', () async {
    final platform = FakeAppUpdatePlatform();
    final controller = AppUpdateController(
      updateService: serviceFor(latestTag: 'v1.0.1'),
      platform: platform,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.checkForUpdates();

    expect(controller.installedVersion, '1.0.1+2');
    expect(controller.state, AppUpdateState.upToDate);
    expect(controller.message, "You're using the latest version.");
  });

  test('downloads a confirmed update only after source-install permission is granted', () async {
    final platform = FakeAppUpdatePlatform()..canInstall = false;
    final controller = AppUpdateController(
      updateService: serviceFor(latestTag: 'v1.0.2'),
      platform: platform,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.checkForUpdates();
    expect(controller.state, AppUpdateState.updateAvailable);
    expect(controller.availableRelease?.assetName, 'NextClass-v1.0.2.apk');

    await controller.downloadAndInstall();
    expect(controller.state, AppUpdateState.permissionRequired);
    expect(platform.permissionSettingsOpened, 1);
    expect(platform.installPath, isNull);

    platform.canInstall = true;
    await controller.continueAfterPermission();
    expect(controller.state, AppUpdateState.installing);
    expect(platform.installPath, endsWith('NextClass-v1.0.2.apk'));
    expect(controller.message, contains('Android'));
  });

  test(
    'reports package-installer cancellation and successful installation',
    () async {
      final platform = FakeAppUpdatePlatform();
      final controller = AppUpdateController(
        updateService: serviceFor(latestTag: 'v1.0.2'),
        platform: platform,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.checkForUpdates();
      await controller.downloadAndInstall();
      expect(controller.state, AppUpdateState.installing);

      platform.statuses.add(const PackageInstallStatus(code: 'cancelled'));
      await controller.onAppResumed();
      expect(controller.state, AppUpdateState.updateAvailable);
      expect(controller.message, contains('cancelled'));

      platform.installedVersion = '1.0.2+3';
      platform.statuses.add(const PackageInstallStatus(code: 'success'));
      await controller.onAppResumed();
      expect(controller.state, AppUpdateState.upToDate);
      expect(controller.installedVersion, '1.0.2+3');
    },
  );

  test('keeps network errors visible with a retryable state', () async {
    final platform = FakeAppUpdatePlatform();
    final controller = AppUpdateController(
      updateService: AppUpdateService(
        client: HandlerClient(
          (request) async => http.StreamedResponse(
            Stream.value(utf8.encode('{}')),
            503,
            request: request,
          ),
        ),
      ),
      platform: platform,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.checkForUpdates();

    expect(controller.state, AppUpdateState.error);
    expect(controller.message, contains('try again later'));
  });
}
