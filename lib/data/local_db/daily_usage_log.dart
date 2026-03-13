// ─────────────────────────────────────────────────────────────────────────────
// DailyUsageLog — Isar collection schema
// ─────────────────────────────────────────────────────────────────────────────
//
// This file defines the on-disk structure of a single app-usage record.
// Isar generates the companion `.g.dart` file from the annotations below.
//
// HOW TO OPEN THE ISAR INSTANCE (do this once, e.g. in a service locator):
//
//   import 'package:isar/isar.dart';
//   import 'package:path_provider/path_provider.dart';
//   import 'daily_usage_log.dart';           // this file
//
//   Future<Isar> openIsar() async {
//     final dir = await getApplicationDocumentsDirectory();
//     return Isar.open(
//       [DailyUsageLogSchema],   // register every collection you need here
//       directory: dir.path,
//       name: 'megahack_db',     // optional: name the instance
//     );
//   }
//
// ─────────────────────────────────────────────────────────────────────────────

import 'package:isar/isar.dart';

// The build_runner tool generates this file.
// Run: flutter pub run build_runner build --delete-conflicting-outputs
part 'daily_usage_log.g.dart';

/// Represents one usage-data entry for a single application on a given date.
///
/// A composite unique index on [packageName] + [date] ensures that
/// re-fetching data for the same app on the same day performs an upsert
/// rather than creating duplicate rows.
@Collection()
@CompositeIndex(['packageName', 'date'], unique: true, replace: true)
class DailyUsageLog {
  /// Auto-incremented primary key managed by Isar.
  /// Do NOT set this manually — Isar assigns it on insert.
  Id id = Isar.autoIncrement;

  /// Human-readable application label (e.g. "Instagram").
  ///
  /// Note: on some platforms (Android ≥ 12) the system may return an empty
  /// string here; fall back to [packageName] when displaying to the user.
  late String appName;

  /// Fully-qualified package / bundle identifier
  /// (e.g. "com.instagram.android" / "com.burbn.instagram").
  ///
  /// Indexed individually so single-app queries stay fast.
  @Index()
  late String packageName;

  /// Total screen-on duration for this app on [date], expressed in
  /// **fractional minutes** (e.g. 90 seconds → 1.5).
  late double durationMinutes;

  /// The calendar date this log entry belongs to.
  ///
  /// Always stored as midnight UTC (00:00:00.000Z) so that date comparisons
  /// work correctly regardless of the device's local timezone.
  ///
  /// Example: an entry captured on 13 March 2026 is stored as
  ///   `DateTime.utc(2026, 3, 13)`.
  @Index()
  late DateTime date;
}
