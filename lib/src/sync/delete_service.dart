import 'package:drift/drift.dart';

import '../helpers/record_helper.dart';

/// Service for handling delete operations
///
/// Provides soft delete (syncs to server) operations.
/// Users can perform normal DELETE operations directly; triggers will handle change tracking.
///
/// **Soft Delete Workflow:**
/// 1. Client calls `softDelete()` which sets `mtds_delete_ts` to current `mtds_client_ts`
/// 2. Trigger logs change to `mtds_change_log`
/// 3. Change syncs to server
/// 4. Server updates `mtds_delete_ts` and `mtds_server_ts`
/// 5. Server broadcasts update back to clients
/// 6. Client receives update and performs hard delete (DELETE FROM table)
/// 7. Other devices also receive update and perform hard delete
class DeleteService {
  final GeneratedDatabase db;
  final RecordHelper _recordHelper;

  DeleteService({
    required this.db,
    required RecordHelper recordHelper,
  }) : _recordHelper = recordHelper;

  /// Soft delete: Mark record for deletion and sync to server
  ///
  /// Sets `mtds_delete_ts` to the same value as `mtds_client_ts` to mark the record as deleted.
  /// The record remains in the database and will be synced to the server.
  ///
  /// **How it works:**
  /// 1. Gets next client timestamp (monotonic, atomic)
  /// 2. Sets `mtds_delete_ts` to the same value as `mtds_client_ts`
  /// 3. Sets `mtds_device_id` and `mtds_client_ts` via RecordHelper
  /// 4. Trigger logs the change to `mtds_change_log`
  /// 5. Change syncs to server on next sync
  /// 6. After server confirms, hard delete is performed automatically
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
    // Prepare record for update (gets client timestamp and sets MTDS columns)
    final record = <String, dynamic>{};
    final prepared = await _recordHelper.prepareForUpdate(record);
    
    // Get the client timestamp that was set
    final clientTs = prepared['mtds_client_ts'] as int;
    
    // Set mtds_delete_ts to the same value as mtds_client_ts
    // This marks the record as deleted while keeping it in the database
    await db.customStatement(
      '''
      UPDATE $tableName 
      SET 
        mtds_delete_ts = ?,
        mtds_device_id = ?,
        mtds_client_ts = ?
      WHERE $primaryKeyColumn = ?
      ''',
      [clientTs, prepared['mtds_device_id'], clientTs, primaryKeyValue],
    );

    print(
      '🗑️ Soft delete: $tableName[$primaryKeyColumn=$primaryKeyValue] '
      'marked with mtds_delete_ts=$clientTs',
    );
  }
}
