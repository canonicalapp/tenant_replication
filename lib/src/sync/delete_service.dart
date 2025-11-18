import 'package:drift/drift.dart';
import '../utils/mtds_utils.dart';

/// Service for handling delete operations
///
/// Provides soft delete (syncs to server) and hard delete (local only) operations.
class DeleteService {
  final GeneratedDatabase db;
  final int deviceId;

  DeleteService({required this.db, required this.deviceId});

  /// Soft delete: Mark record for deletion and sync to server
  ///
  /// Sets `mtds_deleted_txid` to mark the record as deleted.
  /// The record remains in the database and will be synced to the server.
  ///
  /// Parameters:
  /// - `tableName`: Name of the table
  /// - `primaryKeyColumn`: Name of the primary key column
  /// - `primaryKeyValue`: Value of the primary key
  ///
  /// Example:
  /// ```dart
  /// await deleteService.softDelete(
  ///   tableName: 'users',
  ///   primaryKeyColumn: 'id',
  ///   primaryKeyValue: 123,
  /// );
  /// ```
  Future<void> softDelete({
    required String tableName,
    required String primaryKeyColumn,
    required dynamic primaryKeyValue,
  }) async {
    final deletedTxid = MtdsUtils.generateTxid();

    await db.customStatement(
      '''
      UPDATE $tableName 
      SET 
        mtds_deleted_txid = ?,
        mtds_device_id = ?,
        mtds_last_updated_txid = ?
      WHERE $primaryKeyColumn = ?
      ''',
      [deletedTxid, deviceId, deletedTxid, primaryKeyValue],
    );

    print(
      '🗑️ Soft delete: $tableName[$primaryKeyColumn=$primaryKeyValue] '
      'marked with DeletedTXID=$deletedTxid',
    );
  }

  /// Hard delete: Permanently remove record from local database (local only)
  ///
  /// Immediately deletes the record without syncing to server.
  /// Use this for local-only data that doesn't need to be synced (e.g., cache, temporary data).
  ///
  /// ⚠️ WARNING: This operation is permanent and will NOT be synced to the server!
  ///
  /// Parameters:
  /// - `tableName`: Name of the table
  /// - `primaryKeyColumn`: Name of the primary key column
  /// - `primaryKeyValue`: Value of the primary key
  ///
  /// Example:
  /// ```dart
  /// await deleteService.hardDelete(
  ///   tableName: 'cache',
  ///   primaryKeyColumn: 'id',
  ///   primaryKeyValue: 456,
  /// );
  /// ```
  Future<void> hardDelete({
    required String tableName,
    required String primaryKeyColumn,
    required dynamic primaryKeyValue,
  }) async {
    await db.customStatement(
      'DELETE FROM $tableName WHERE $primaryKeyColumn = ?',
      [primaryKeyValue],
    );

    print(
      '⚠️ Hard delete: $tableName[$primaryKeyColumn=$primaryKeyValue] '
      'permanently removed (local only, no sync)',
    );
  }
}
