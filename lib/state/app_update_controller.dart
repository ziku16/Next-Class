// The public dependency names are used by SettingsScreen and external tests.
// Initializing-formal linting would expose private parameter names instead.
// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/services/app_update_service.dart';
import '../platform/app_update_platform.dart';

enum AppUpdateState {
  loadingVersion,
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  permissionRequired,
  installing,
  error,
}

class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    required AppUpdateService updateService,
    required AppUpdatePlatform platform,
  }) : _updateService = updateService,
       _platform = platform;

  final AppUpdateService _updateService;
  final AppUpdatePlatform _platform;

  AppUpdateState state = AppUpdateState.loadingVersion;
  String installedVersion = '—';
  String? message;
  AppUpdateRelease? availableRelease;
  File? _downloadedApk;
  int downloadedBytes = 0;
  int totalBytes = 0;

  double? get downloadProgress =>
      totalBytes == 0 ? null : (downloadedBytes / totalBytes).clamp(0.0, 1.0);

  bool get isBusy =>
      state == AppUpdateState.checking ||
      state == AppUpdateState.downloading ||
      state == AppUpdateState.installing;

  Future<void> initialize() async {
    state = AppUpdateState.loadingVersion;
    message = 'Reading installed version…';
    notifyListeners();
    try {
      installedVersion = await _platform.getInstalledVersion();
      state = AppUpdateState.idle;
      message = null;
    } catch (_) {
      installedVersion = '—';
      state = AppUpdateState.error;
      message =
          'Could not read the installed version. Tap Update Now to try again.';
    }
    notifyListeners();
  }

  Future<bool> checkForUpdates() async {
    if (isBusy) return false;
    if (installedVersion == '—') {
      await initialize();
      if (installedVersion == '—') return false;
    }

    state = AppUpdateState.checking;
    message = 'Checking for updates…';
    availableRelease = null;
    _downloadedApk = null;
    notifyListeners();

    try {
      final result = await _updateService.checkForUpdate(
        installedVersion: installedVersion,
      );
      if (result.isUpToDate) {
        state = AppUpdateState.upToDate;
        message = "You're using the latest version.";
        return false;
      }
      availableRelease = result.release;
      state = AppUpdateState.updateAvailable;
      message = 'Version ${result.release!.version} is available.';
      return true;
    } on AppUpdateException catch (error) {
      state = AppUpdateState.error;
      message = error.message;
      return false;
    } catch (_) {
      state = AppUpdateState.error;
      message =
          'Could not check for updates right now. Please try again later.';
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> downloadAndInstall() async {
    final release = availableRelease;
    if (release == null || isBusy) return;

    state = AppUpdateState.downloading;
    message = 'Downloading version ${release.version}…';
    downloadedBytes = 0;
    totalBytes = release.sizeBytes;
    notifyListeners();

    try {
      _downloadedApk = await _updateService.downloadUpdate(
        release,
        onProgress: (received, total) {
          downloadedBytes = received;
          totalBytes = total;
          notifyListeners();
        },
      );
      if (!await _platform.canRequestPackageInstalls()) {
        state = AppUpdateState.permissionRequired;
        message = 'Allow NextClass to install updates in Android settings.';
        notifyListeners();
        await _platform.openInstallPermissionSettings();
        return;
      }
      await _startSystemInstaller();
    } on AppUpdateException catch (error) {
      state = AppUpdateState.error;
      message = error.message;
      notifyListeners();
    } on PlatformException catch (error) {
      state = error.code == 'INSTALL_PERMISSION_REQUIRED'
          ? AppUpdateState.permissionRequired
          : AppUpdateState.error;
      message = error.code == 'INSTALL_PERMISSION_REQUIRED'
          ? 'Allow NextClass to install updates in Android settings.'
          : error.message ?? 'Android could not open the update installer.';
      notifyListeners();
    } catch (_) {
      state = AppUpdateState.error;
      message = 'The update could not be installed. Please try again.';
      notifyListeners();
    }
  }

  Future<void> openInstallPermissionSettings() async {
    try {
      await _platform.openInstallPermissionSettings();
    } on PlatformException catch (error) {
      state = AppUpdateState.error;
      message = error.message ?? 'Could not open Android install settings.';
      notifyListeners();
    } catch (_) {
      state = AppUpdateState.error;
      message = 'Could not open Android install settings.';
      notifyListeners();
    }
  }

  Future<void> continueAfterPermission() async {
    if (state != AppUpdateState.permissionRequired || _downloadedApk == null) {
      return;
    }
    try {
      if (!await _platform.canRequestPackageInstalls()) {
        message = 'Allow installs from NextClass in Android settings, then return here.';
        notifyListeners();
        return;
      }
      await _startSystemInstaller();
    } on PlatformException catch (error) {
      state = error.code == 'INSTALL_PERMISSION_REQUIRED'
          ? AppUpdateState.permissionRequired
          : AppUpdateState.error;
      message = error.message ?? 'Android could not open the update installer.';
      notifyListeners();
    } catch (_) {
      state = AppUpdateState.error;
      message = 'Android could not open the update installer.';
      notifyListeners();
    }
  }

  Future<void> onAppResumed() async {
    try {
      final status = await _platform.consumeInstallerStatus();
      if (status != null) {
        await _handleInstallerStatus(status);
      } else if (state == AppUpdateState.permissionRequired) {
        await continueAfterPermission();
      }
    } catch (_) {
      // Android may not have a pending installer result to consume.
    }
  }

  Future<bool> launchSupportEmail(String email) async {
    try {
      return await _platform.launchSupportEmail(email);
    } catch (_) {
      return false;
    }
  }

  Future<void> _startSystemInstaller() async {
    final apk = _downloadedApk;
    if (apk == null) {
      state = AppUpdateState.error;
      message = 'The verified update file is no longer available. Check for updates again.';
      notifyListeners();
      return;
    }
    await _platform.startPackageInstall(apk.path);
    state = AppUpdateState.installing;
    message = 'Android will ask you to confirm the update. Your saved data stays on this device.';
    notifyListeners();
  }

  Future<void> _handleInstallerStatus(PackageInstallStatus status) async {
    switch (status.code) {
      case 'pending_user_action':
        state = AppUpdateState.installing;
        message = 'Confirm the update in Android’s installer to finish.';
      case 'success':
        installedVersion = await _platform.getInstalledVersion();
        availableRelease = null;
        _downloadedApk = null;
        state = AppUpdateState.upToDate;
        message = 'Update installed. You’re using the latest version.';
      case 'cancelled':
        state = availableRelease == null
            ? AppUpdateState.idle
            : AppUpdateState.updateAvailable;
        message = 'Installation was cancelled. You can continue using NextClass or try again.';
      case 'storage':
        state = AppUpdateState.error;
        message =
            'Android could not install the update because storage is low.';
      case 'incompatible':
      case 'invalid':
      case 'conflict':
        state = AppUpdateState.error;
        message = 'Android could not verify this update. Your installed app was not replaced.';
      case 'blocked':
        state = AppUpdateState.error;
        message = status.message ?? 'Android blocked the installation. Check install permission and try again.';
      default:
        state = AppUpdateState.error;
        message = status.message ?? 'Android could not install the update. Your existing app remains available.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _updateService.close();
    super.dispose();
  }
}
