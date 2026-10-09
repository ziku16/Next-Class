import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/scan_quota.dart';
import '../models/user_settings.dart';

/// Central SQLite Database Manager for NextClass.
/// Enforces foreign key constraints for cascade deletions.
class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase({String dbName = 'nextclass.db'}) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    return await openDatabase(
      path,
      version: 2,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// In-memory database factory for fast, isolated unit and widget tests
  static Future<AppDatabase> createInMemory() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    final dbManager = AppDatabase._internal();
    _database = await openDatabase(
      inMemoryDatabasePath,
      version: 2,
      onConfigure: dbManager._onConfigure,
      onCreate: dbManager._onCreate,
      onUpgrade: dbManager._onUpgrade,
    );
    return dbManager;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE quizzes ADD COLUMN reminderTime TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE quizzes ADD COLUMN reminderType TEXT;');
      } catch (_) {}
    }
  }

  Future<void> _onConfigure(Database db) async {
    // Enforce foreign key constraints so that deleting a class cascades to its quizzes
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE classes (
        id TEXT PRIMARY KEY,
        subject TEXT NOT NULL,
        subjectColorIndex INTEGER NOT NULL,
        dayOfWeek TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        room TEXT,
        teacher TEXT,
        isAiUnsure INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE quizzes (
        id TEXT PRIMARY KEY,
        classId TEXT NOT NULL,
        subject TEXT NOT NULL,
        title TEXT NOT NULL,
        dueDate TEXT NOT NULL,
        note TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        reminderTime TEXT,
        reminderType TEXT,
        FOREIGN KEY (classId) REFERENCES classes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY,
        classReminderMinutes INTEGER,
        quizReminderEnabled INTEGER NOT NULL,
        quizReminderTime TEXT NOT NULL,
        exactAlarmsGranted INTEGER NOT NULL,
        hideEmptyDays INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE quota (
        id INTEGER PRIMARY KEY,
        dailyScansUsed INTEGER NOT NULL,
        lastDailyReset TEXT NOT NULL,
        weeklyScansUsed INTEGER NOT NULL,
        lastWeeklyReset TEXT NOT NULL
      )
    ''');

    // Insert default settings and quota rows
    final defaultSettings = UserSettings.defaults();
    await db.insert('settings', defaultSettings.toMap());

    final initialQuota = ScanQuota.initial();
    await db.insert('quota', initialQuota.toMap());
  }

  /// Closes database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Deletes and resets all data across all tables
  Future<void> clearAllTables() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('quizzes');
      await txn.delete('classes');
      await txn.delete('settings');
      await txn.delete('quota');

      await txn.insert('settings', UserSettings.defaults().toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('quota', ScanQuota.initial().toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Completely resets the database, wiping all user classes and quizzes.
  /// Used for clean installs, QA testing, and development data clearing.
  Future<void> debugResetDatabase() async {
    await clearAllTables();
  }
}
