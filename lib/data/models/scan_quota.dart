import 'dart:math';

/// Tracks timetable upload scanning quota (2 per day, 3 per week).
class ScanQuota {
  static const int maxDailyScans = 2;
  static const int maxWeeklyScans = 3;

  final int dailyScansUsed;
  final DateTime lastDailyReset;
  final int weeklyScansUsed;
  final DateTime lastWeeklyReset;

  const ScanQuota({
    required this.dailyScansUsed,
    required this.lastDailyReset,
    required this.weeklyScansUsed,
    required this.lastWeeklyReset,
  });

  /// Initial quota factory
  factory ScanQuota.initial() {
    final now = DateTime.now();
    return ScanQuota(
      dailyScansUsed: 0,
      lastDailyReset: now,
      weeklyScansUsed: 0,
      lastWeeklyReset: now,
    );
  }

  /// Number of daily scans remaining
  int get dailyScansLeft => max(0, maxDailyScans - dailyScansUsed);

  /// Number of weekly scans remaining
  int get weeklyScansLeft => max(0, maxWeeklyScans - weeklyScansUsed);

  /// True if daily limit of 2 is reached
  bool get isDailyLimitReached => dailyScansLeft <= 0;

  /// True if weekly limit of 3 is reached
  bool get isWeeklyLimitReached => weeklyScansLeft <= 0;

  /// Human-friendly quota string matching Design System specification:
  /// e.g. "1 of 2 left today · 2 of 3 this week"
  String get quotaLabel =>
      '$dailyScansLeft of $maxDailyScans left today · $weeklyScansLeft of $maxWeeklyScans this week';

  /// Evaluates whether a scan is permitted
  bool canScan({DateTime? now}) {
    final updated = resetIfExpired(now: now);
    return updated.dailyScansLeft > 0 && updated.weeklyScansLeft > 0;
  }

  /// Consumes one scan quota if available
  ScanQuota consumeScan({DateTime? now}) {
    final refreshed = resetIfExpired(now: now);
    if (!refreshed.canScan()) {
      return refreshed;
    }
    return refreshed.copyWith(
      dailyScansUsed: refreshed.dailyScansUsed + 1,
      weeklyScansUsed: refreshed.weeklyScansUsed + 1,
    );
  }

  /// Checks if calendar day or week has rolled over and resets counts accordingly
  ScanQuota resetIfExpired({DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    int newDailyUsed = dailyScansUsed;
    DateTime newDailyReset = lastDailyReset;

    int newWeeklyUsed = weeklyScansUsed;
    DateTime newWeeklyReset = lastWeeklyReset;

    // Check daily reset (different calendar day)
    final isNewDay = currentTime.year != lastDailyReset.year ||
        currentTime.month != lastDailyReset.month ||
        currentTime.day != lastDailyReset.day;

    if (isNewDay) {
      newDailyUsed = 0;
      newDailyReset = currentTime;
    }

    // Check weekly reset (more than 7 days, or passed into a new calendar week)
    final diffDays = currentTime.difference(lastWeeklyReset).inDays;
    if (diffDays >= 7 || (diffDays >= 1 && currentTime.weekday == DateTime.monday && lastWeeklyReset.weekday != DateTime.monday)) {
      newWeeklyUsed = 0;
      newWeeklyReset = currentTime;
    }

    return ScanQuota(
      dailyScansUsed: newDailyUsed,
      lastDailyReset: newDailyReset,
      weeklyScansUsed: newWeeklyUsed,
      lastWeeklyReset: newWeeklyReset,
    );
  }

  ScanQuota copyWith({
    int? dailyScansUsed,
    DateTime? lastDailyReset,
    int? weeklyScansUsed,
    DateTime? lastWeeklyReset,
  }) {
    return ScanQuota(
      dailyScansUsed: dailyScansUsed ?? this.dailyScansUsed,
      lastDailyReset: lastDailyReset ?? this.lastDailyReset,
      weeklyScansUsed: weeklyScansUsed ?? this.weeklyScansUsed,
      lastWeeklyReset: lastWeeklyReset ?? this.lastWeeklyReset,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'dailyScansUsed': dailyScansUsed,
      'lastDailyReset': lastDailyReset.toIso8601String(),
      'weeklyScansUsed': weeklyScansUsed,
      'lastWeeklyReset': lastWeeklyReset.toIso8601String(),
    };
  }

  factory ScanQuota.fromMap(Map<String, dynamic> map) {
    return ScanQuota(
      dailyScansUsed: (map['dailyScansUsed'] as num).toInt(),
      lastDailyReset: DateTime.parse(map['lastDailyReset'] as String),
      weeklyScansUsed: (map['weeklyScansUsed'] as num).toInt(),
      lastWeeklyReset: DateTime.parse(map['lastWeeklyReset'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanQuota &&
          runtimeType == other.runtimeType &&
          dailyScansUsed == other.dailyScansUsed &&
          lastDailyReset == other.lastDailyReset &&
          weeklyScansUsed == other.weeklyScansUsed &&
          lastWeeklyReset == other.lastWeeklyReset;

  @override
  int get hashCode =>
      dailyScansUsed.hashCode ^
      lastDailyReset.hashCode ^
      weeklyScansUsed.hashCode ^
      lastWeeklyReset.hashCode;

  @override
  String toString() {
    return 'ScanQuota(daily: $dailyScansLeft/$maxDailyScans, weekly: $weeklyScansLeft/$maxWeeklyScans)';
  }
}
