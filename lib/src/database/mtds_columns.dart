import 'package:drift/drift.dart';

/// Mixin that injects the four MTDS-required columns into a Drift [Table].
///
/// Usage:
/// ```dart
/// import 'package:mtds/index.dart';
///
/// class Users extends Table with MtdsColumns {
///   IntColumn get id => integer().autoIncrement()();
///   // ...
/// }
/// ```
mixin MtdsColumns on Table {
  /// Client-generated timestamp in milliseconds since client epoch.
  /// Always present with a default of 0 so change detection never hits NULL.
  Int64Column get mtdsClientTs =>
      int64().named('mtds_client_ts').withDefault(Constant(BigInt.from(0)))();

  /// Server-assigned authoritative timestamp in nanoseconds since epoch (NodeJS HR based).
  /// NULL until the record is synced to server.
  Int64Column get mtdsServerTs => int64().nullable().named('mtds_server_ts')();

  /// 64-bit device identifier used for replication guardrails.
  /// Always present with a default of 0; SDK overwrites it on each write.
  Int64Column get mtdsDeviceId =>
      int64().named('mtds_device_id').withDefault(Constant(BigInt.from(0)))();

  /// Soft-delete marker (NULL = active, non-null = deleted at timestamp in milliseconds since client epoch)
  Int64Column get mtdsDeleteTs => int64().nullable().named('mtds_delete_ts')();
}
