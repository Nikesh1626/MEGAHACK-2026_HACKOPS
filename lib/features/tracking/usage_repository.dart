// ─────────────────────────────────────────────────────────────────────────────
// UsageRepository — single source of truth for app-usage data
// ─────────────────────────────────────────────────────────────────────────────
//
// RESPONSIBILITIES
//  1. Fetch raw screen-time data from the OS via the `app_usage` package.
//  2. Persist / update that data inside an Isar database so it is available
//     offline and across app restarts.
//  3. Expose typed query helpers for the rest of the app to consume.
//
// INITIALISATION
//  UsageRepository expects a ready-to-use [Isar] instance injected through its
//  constructor.  Open the database once (e.g. in main.dart or a service
//  locator) and pass it here:
//
//   final isar = await Isar.open(
//     [DailyUsageLogSchema],
//     directory: (await getApplicationDocumentsDirectory()).path,
//   );
//   final repo = UsageRepository(isar: isar);
//
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer' as dev;

import 'package:app_usage/app_usage.dart';
import 'package:isar/isar.dart';

import '../../data/local_db/daily_usage_log.dart';

/// Custom exception thrown when fetching usage data fails.
class UsageFetchException implements Exception {
  const UsageFetchException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'UsageFetchException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Custom exception thrown when a database operation fails.
class UsagePersistException implements Exception {
  const UsagePersistException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'UsagePersistException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Repository that acts as the single source of truth for app-usage data.
///
/// All public methods are **asynchronous** and include comprehensive error
/// handling — they will throw a typed exception ([UsageFetchException] or
/// [UsagePersistException]) instead of leaking raw OS / Isar errors.
class UsageRepository {
  /// Creates a [UsageRepository] with an already-opened [Isar] instance.
  ///
  /// ```dart
  /// final repo = UsageRepository(isar: isar);
  /// ```
  UsageRepository({required Isar isar}) : _isar = isar;

  final Isar _isar;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetches app-usage data for the **last 24 hours** from the OS, then
  /// saves (or updates) every record in the local Isar database.
  ///
  /// Returns the list of [DailyUsageLog] objects that were written.
  ///
  /// Throws:
  ///  - [UsageFetchException] if the OS query fails.
  ///  - [UsagePersistException] if writing to the database fails.
  Future<List<DailyUsageLog>> fetchAndSaveLast24Hours() async {
    final now = DateTime.now();
    final since = now.subtract(const Duration(hours: 24));

    // ── Step 1: fetch from OS ───────────────────────────────────────────────
    final List<AppUsageInfo> rawUsages;
    try {
      rawUsages = await AppUsage().getAppUsage(since, now);
    } on AppUsageException catch (e, stack) {
      dev.log(
        'Failed to fetch app usage from OS',
        error: e,
        stackTrace: stack,
        name: 'UsageRepository',
      );
      throw UsageFetchException(
        'Could not retrieve app-usage stats from the OS.',
        cause: e,
      );
    } catch (e, stack) {
      dev.log(
        'Unexpected error while fetching app usage',
        error: e,
        stackTrace: stack,
        name: 'UsageRepository',
      );
      throw UsageFetchException(
        'An unexpected error occurred while fetching app-usage stats.',
        cause: e,
      );
    }

    if (rawUsages.isEmpty) {
      dev.log(
        'app_usage returned an empty list — no usage data available.',
        name: 'UsageRepository',
      );
      return [];
    }

    // ── Step 2: map raw data → Isar models ─────────────────────────────────
    // We use midnight UTC of *today* as the canonical date key so that the
    // composite unique index (packageName + date) deduplicates correctly.
    final today = _midnightUtc(now);

    final logs = rawUsages
        .where((info) => info.usage.inSeconds > 0) // skip truly unused apps
        .map((info) => _toLog(info, today))
        .toList(growable: false);

    // ── Step 3: persist to Isar ─────────────────────────────────────────────
    await _writeLogs(logs);

    dev.log(
      'Saved ${logs.length} usage records for $today.',
      name: 'UsageRepository',
    );

    return logs;
  }

  /// Returns all usage logs stored for a specific [date].
  ///
  /// [date] is normalised to midnight UTC before querying, so passing any
  /// [DateTime] on the desired day is safe.
  ///
  /// Throws [UsagePersistException] on database failure.
  Future<List<DailyUsageLog>> getLogsForDate(DateTime date) async {
    final targetDate = _midnightUtc(date);
    try {
      return await _isar.dailyUsageLogs
          .filter()
          .dateEqualTo(targetDate)
          .sortByDurationMinutesDesc()
          .findAll();
    } catch (e, stack) {
      dev.log(
        'Failed to query logs for $targetDate',
        error: e,
        stackTrace: stack,
        name: 'UsageRepository',
      );
      throw UsagePersistException(
        'Could not read usage logs for $targetDate from the database.',
        cause: e,
      );
    }
  }

  /// Returns the [DailyUsageLog] for a specific [packageName] on [date],
  /// or `null` if no record exists.
  ///
  /// Throws [UsagePersistException] on database failure.
  Future<DailyUsageLog?> getLogForPackage({
    required String packageName,
    required DateTime date,
  }) async {
    final targetDate = _midnightUtc(date);
    try {
      return await _isar.dailyUsageLogs
          .filter()
          .packageNameEqualTo(packageName)
          .and()
          .dateEqualTo(targetDate)
          .findFirst();
    } catch (e, stack) {
      dev.log(
        'Failed to query log for $packageName on $targetDate',
        error: e,
        stackTrace: stack,
        name: 'UsageRepository',
      );
      throw UsagePersistException(
        'Could not read usage log for package "$packageName" from the database.',
        cause: e,
      );
    }
  }

  /// Returns the total screen time (in minutes) across **all** apps for
  /// [date].
  ///
  /// Throws [UsagePersistException] on database failure.
  Future<double> getTotalMinutesForDate(DateTime date) async {
    final logs = await getLogsForDate(date);
    return logs.fold(0.0, (sum, log) => sum + log.durationMinutes);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Writes [logs] inside a single Isar write transaction.
  ///
  /// Because the collection has a composite unique index with `replace: true`,
  /// inserting a record whose (packageName, date) pair already exists will
  /// automatically overwrite the old row — i.e. this is an **upsert**.
  Future<void> _writeLogs(List<DailyUsageLog> logs) async {
    try {
      await _isar.writeTxn(() async {
        await _isar.dailyUsageLogs.putAll(logs);
      });
    } catch (e, stack) {
      dev.log(
        'Failed to persist usage logs',
        error: e,
        stackTrace: stack,
        name: 'UsageRepository',
      );
      throw UsagePersistException(
        'Could not save usage logs to the database.',
        cause: e,
      );
    }
  }

  /// Converts an [AppUsageInfo] record into a [DailyUsageLog] Isar model.
  DailyUsageLog _toLog(AppUsageInfo info, DateTime date) {
    return DailyUsageLog()
      // Use the package name as the app label when the OS returns an empty name.
      ..appName = info.appName.isNotEmpty ? info.appName : info.packageName
      ..packageName = info.packageName
      ..durationMinutes = info.usage.inSeconds / 60.0
      ..date = date;
  }

  /// Normalises [dt] to midnight UTC (00:00:00.000Z) for consistent
  /// date-keying regardless of device timezone.
  DateTime _midnightUtc(DateTime dt) =>
      DateTime.utc(dt.year, dt.month, dt.day);
}
