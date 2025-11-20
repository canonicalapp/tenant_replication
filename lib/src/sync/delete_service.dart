import 'package:drift/drift.dart';
import '../utils/tx.dart';

/// Service for handling delete operations
///
/// Provides soft delete (syncs to server) operations.
/// Users can perform normal DELETE operations directly; triggers will handle change tracking.
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
    final deletedTxid = TX.getId();

    await db.customStatement(
      '''
      UPDATE $tableName 
      SET 
        mtds_deleted_txid = ?,
        mtds_device_id = ?,
        mtds_last_updated_txid = ?
      WHERE $primaryKeyColumn = ?
      ''',
      [deletedTxid.toInt(), deviceId, deletedTxid.toInt(), primaryKeyValue],
    );

    print(
      '🗑️ Soft delete: $tableName[$primaryKeyColumn=$primaryKeyValue] '
      'marked with DeletedTXID=$deletedTxid',
    );
  }

}
