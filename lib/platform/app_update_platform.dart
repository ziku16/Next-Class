import 'package:flutter/services.dart';

abstract interface class AppUpdatePlatform {
  Future<String> getInstalledVersion();

  Future<bool> canRequestPackageInstalls();

  Future<void> openInstallPermissionSettings();

  Future<void> startPackageInstall(String apkPath);

  Future<PackageInstallStatus?> consumeInstallerStatus();

  Future<bool> launchSupportEmail(String email);
}

class PackageInstallStatus {
  const PackageInstallStatus({required this.code, this.message});

  final String code;
  final String? message;
}

class AndroidAppUpdatePlatform implements AppUpdatePlatform {
  AndroidAppUpdatePlatform({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.nextclass.app/app_updates');

  final MethodChannel _channel;

  @override
  Future<String> getInstalledVersion() async {
    final version = await _channel.invokeMethod<String>('getInstalledVersion');
    if (version == null || version.trim().isEmpty) {
      throw PlatformException(
        code: 'VERSION_UNAVAILABLE',
        message: 'The installed app version is unavailable.',
      );
    }
    return version;
  }

  @override
  Future<bool> canRequestPackageInstalls() async =>
      await _channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;

  @override
  Future<void> openInstallPermissionSettings() =>
      _channel.invokeMethod<void>('openInstallPermissionSettings');

  @override
  Future<void> startPackageInstall(String apkPath) =>
      _channel.invokeMethod<void>('startPackageInstall', apkPath);

  @override
  Future<PackageInstallStatus?> consumeInstallerStatus() async {
    final response = await _channel.invokeMapMethod<String, Object?>(
      'consumeInstallStatus',
    );
    final code = response?['status'];
    if (code is! String || code.isEmpty) return null;
    final message = response?['message'];
    return PackageInstallStatus(
      code: code,
      message: message is String ? message : null,
    );
  }

  @override
  Future<bool> launchSupportEmail(String email) async =>
      await _channel.invokeMethod<bool>('launchSupportEmail', email) ?? false;
}
