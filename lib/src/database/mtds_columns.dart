import 'package:drift/drift.dart';

/// Mixin that injects the three MTDS-required columns into a Drift [Table].
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
  /// UTC nanosecond timestamp of the last write (client-generated).
  /// Always present with a default of 0 so change detection never hits NULL.
  IntColumn get mtdsLastUpdatedTxid =>
      integer()
          .named('mtds_last_updated_txid')
          .withDefault(const Constant(0))();

  /// 48-bit device identifier used for replication guardrails.
  /// Always present with a default of 0; SDK overwrites it on each write.
  IntColumn get mtdsDeviceId =>
      integer().named('mtds_device_id').withDefault(const Constant(0))();

  /// Soft-delete marker (NULL = active, non-null = deleted at TXID)
  IntColumn get mtdsDeletedTxid =>
      integer().nullable().named('mtds_deleted_txid')();
}
