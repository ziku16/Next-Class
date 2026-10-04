import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/scan_quota.dart';
import '../models/user_settings.dart';

/// Repository managing user preferences and scan quota persistence.
class SettingsRepository {
  final AppDatabase _dbManager;
  final _settingsStreamController = StreamController<UserSettings>.broadcast();
  final _quotaStreamController = StreamController<ScanQuota>.broadcast();

  SettingsRepository({AppDatabase? dbManager})
      : _dbManager = dbManager ?? AppDatabase.instance;

  Stream<UserSettings> get settingsStream => _settingsStreamController.stream;
  Stream<ScanQuota> get quotaStream => _quotaStreamController.stream;

  void dispose() {
    _settingsStreamController.close();
    _quotaStreamController.close();
  }

  /// Retrieves user preferences from SQLite.
  Future<UserSettings> getSettings() async {
    final db = await _dbManager.database;
    final maps = await db.query('settings', where: 'id = 1', limit: 1);

    if (maps.isEmpty) {
      final defaults = UserSettings.defaults();
      await db.insert('settings', defaults.toMap());
      return defaults;
    }

    return UserSettings.fromMap(maps.first);
  }

  /// Updates user preferences.
  Future<void> updateSettings(UserSettings settings) async {
    final db = await _dbManager.database;
    await db.update(
      'settings',
      settings.toMap(),
      where: 'id = 1',
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _settingsStreamController.add(settings);
  }

  /// Retrieves current scan quota, resetting daily or weekly counts if rollover has occurred.
  Future<ScanQuota> getScanQuota({DateTime? now}) async {
    final db = await _dbManager.database;
    final maps = await db.query('quota', where: 'id = 1', limit: 1);

    ScanQuota currentQuota;
    if (maps.isEmpty) {
      currentQuota = ScanQuota.initial();
      await db.insert('quota', currentQuota.toMap());
    } else {
      currentQuota = ScanQuota.fromMap(maps.first);
    }

    final refreshed = currentQuota.resetIfExpired(now: now);
    if (refreshed != currentQuota) {
      await db.update(
        'quota',
        refreshed.toMap(),
        where: 'id = 1',
      );
    }

    return refreshed;
  }

  /// Consumes one scan from the quota and persists it. Returns the updated quota.
  Future<ScanQuota> consumeScan({DateTime? now}) async {
    final current = await getScanQuota(now: now);
    final updated = current.consumeScan(now: now);

    final db = await _dbManager.database;
    await db.update(
      'quota',
      updated.toMap(),
      where: 'id = 1',
    );

    _quotaStreamController.add(updated);
    return updated;
  }
}
