import 'package:drift/drift.dart';

/// Service for managing the change log.
///
/// Handles operations related to the `mtds_change_log` table,
/// including retrieving pending changes and clearing processed changes.
class ChangeLogService {
  final GeneratedDatabase db;

  ChangeLogService({required this.db});

  /// Get all pending changes from the change log.
  ///
  /// Returns a list of change records ordered by txid (ascending).
  Future<List<Map<String, dynamic>>> getChangeLogs() async {
    final result =
        await db
            .customSelect('SELECT * FROM mtds_change_log ORDER BY txid ASC')
            .get();

    return result.map((row) => row.data).toList();
  }

  /// Clear all changes from the change log.
  ///
  /// Use this when all changes have been successfully synced.
  Future<void> clearChangeLog() async {
    await db.customStatement('DELETE FROM mtds_change_log');
  }

  /// Remove specific processed changes from the change log.
  ///
  /// Parameters:
  /// - `txids`: List of transaction IDs to remove
  ///
  /// This is used for partial sync success scenarios where only some
  /// changes were successfully processed.
  Future<void> removeProcessedChanges(List<int> txids) async {
    if (txids.isEmpty) {
      return;
    }

    final placeholders = List.filled(txids.length, '?').join(',');
    await db.customStatement(
      'DELETE FROM mtds_change_log WHERE txid IN ($placeholders)',
      txids,
    );
  }
}

