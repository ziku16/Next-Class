import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/platform/app_update_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nextclass.app/app_updates');
  final calls = <MethodCall>[];
  late AndroidAppUpdatePlatform platform;

  setUp(() {
    calls.clear();
    platform = AndroidAppUpdatePlatform(channel: channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'getInstalledVersion':
              return '1.0.2';
            case 'canRequestPackageInstalls':
              return false;
            case 'consumeInstallStatus':
              return {'status': 'cancelled', 'message': 'Install cancelled.'};
            case 'launchSupportEmail':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'reads the installed version and installation permission through Android',
    () async {
      expect(await platform.getInstalledVersion(), '1.0.2');
      expect(await platform.canRequestPackageInstalls(), isFalse);
      expect(calls.map((call) => call.method), [
        'getInstalledVersion',
        'canRequestPackageInstalls',
      ]);
    },
  );

  test('opens source permission settings and asks Android to install the cached APK', () async {
    await platform.openInstallPermissionSettings();
    await platform.startPackageInstall(
      '/data/user/0/com.nextclass.app/cache/updates.apk',
    );

    expect(calls[0].method, 'openInstallPermissionSettings');
    expect(calls[1].method, 'startPackageInstall');
    expect(
      calls[1].arguments,
      '/data/user/0/com.nextclass.app/cache/updates.apk',
    );
  });

  test(
    'consumes package installer cancellation and launches support email',
    () async {
      final status = await platform.consumeInstallerStatus();

      expect(status?.code, 'cancelled');
      expect(status?.message, 'Install cancelled.');
      expect(
        await platform.launchSupportEmail('muhammadzakriaawan237@gmail.com'),
        isTrue,
      );
      expect(calls.last.method, 'launchSupportEmail');
      expect(calls.last.arguments, 'muhammadzakriaawan237@gmail.com');
    },
  );
}
