import 'dart:convert';

import 'package:drift/drift.dart';

import '../helpers/serialization_helper.dart';
import '../utils/bigint_utils.dart';
import 'table_schema_helper.dart';

/// Service for processing sync payloads.
///
/// Handles serialization/deserialization of change payloads,
/// updating local records with server timestamps, and processing
/// confirmed soft deletes.
class SyncPayloadProcessor {
  final GeneratedDatabase db;
  final TableSchemaHelper _schemaHelper;

  SyncPayloadProcessor({required this.db})
      : _schemaHelper = TableSchemaHelper(db: db);

  /// Serialize a change payload for sending to server.
  ///
  /// Handles binary fields (Base64 encoding) and BigInt conversion.
  Future<Map<String, dynamic>> serializePayload(
    Map<String, dynamic> payload,
    String tableName,
  ) async {
    final result = <String, dynamic>{};

    // Get column types for accurate binary detection
    final columnTypes = await _schemaHelper.getColumnTypes(tableName);

    // Serialize 'New' field if present
    if (payload.containsKey('New') && payload['New'] is Map) {
      final newData = payload['New'] as Map<String, dynamic>;
      result['New'] = SerializationHelper.serializeRowWithSchema(
        newData,
        columnTypes,
      );
    }

    // Serialize 'old' field if present
    if (payload.containsKey('old') && payload['old'] is Map) {
      final oldData = payload['old'] as Map<String, dynamic>;
      result['old'] = SerializationHelper.serializeRowWithSchema(
        oldData,
        columnTypes,
      );
    }

    return result;
  }

  /// Normalize changes for server transmission.
  ///
  /// This method:
  /// 1. Parses payload JSON if it's a string
  /// 2. Serializes payload data (binary + BigInt handling)
  /// 3. Renames `txid` to `clientTxid` and converts BigInt to string
  ///
  /// Returns a list of normalized change records ready for server.
  Future<List<Map<String, dynamic>>> normalizeChangesForServer(
    List<Map<String, dynamic>> changes,
  ) async {
    return await Future.wait(changes.map((change) async {
      final normalized = Map<String, dynamic>.from(change);

      // Parse payload if it's a string
      Map<String, dynamic>? payload;
      if (normalized['payload'] is String) {
        try {
          payload = jsonDecode(
            normalized['payload'] as String,
          ) as Map<String, dynamic>?;
        } catch (e) {
          print('⚠️ Failed to parse payload: $e');
          payload = null;
        }
      } else if (normalized['payload'] is Map) {
        payload = normalized['payload'] as Map<String, dynamic>?;
      }

      // Serialize payload data (handle binary fields and BigInt)
      if (payload != null) {
        final tableName = normalized['table_name'] as String? ?? '';
        final serializedPayload = await serializePayload(payload, tableName);
        normalized['payload'] = serializedPayload;
      }

      // Rename txid to clientTxid for server
      // Convert BigInt to string for JSON compatibility
      final txid = normalized['txid'];
      if (txid is BigInt) {
        normalized['clientTxid'] = txid.toString();
      } else {
        normalized['clientTxid'] = txid;
      }

      return normalized;
    }));
  }

  /// Update local records with server-assigned timestamps.
  ///
  /// For each server update, updates the local record's `mtds_server_ts`
  /// with the authoritative timestamp from the server.
  ///
  /// Also performs clock skew detection (warns if difference > 5 seconds).
  Future<void> updateLocalWithServerTimestamps(
    List<dynamic> serverUpdates,
  ) async {
    print('🔄 Updating local records with server timestamps...');

    for (final update in serverUpdates) {
      try {
        final clientTxid = BigIntUtils.toBigInt(update['clientTxid']);
        final serverTxid = BigIntUtils.toBigInt(update['serverTxid']);
        final tableName = update['tableName'] as String;
        final pk = update['pk'];

        if (clientTxid == null || serverTxid == null) {
          print('⚠️ Skipping update: missing clientTxid or serverTxid');
          continue;
        }

        // Clock skew detection
        final skew = serverTxid - clientTxid;
        if (skew.abs() > BigInt.from(5000000000)) {
          // More than 5 seconds difference
          print(
            '⚠️ Clock skew detected: ${skew ~/ BigInt.from(1000000)}ms '
            '(client: $clientTxid, server: $serverTxid)',
          );
        }

        // Get primary key column name
        final pkColumn = await _schemaHelper.getPrimaryKeyColumn(tableName);

        // Update local record with server timestamp
        // Convert BigInt to int for SQLite (SQLite INTEGER can handle 64-bit)
        await db.customStatement(
          'UPDATE $tableName SET mtds_server_ts = ? WHERE $pkColumn = ?',
          [serverTxid.toInt(), pk],
        );

        print('✅ Updated $tableName[$pkColumn=$pk]: $clientTxid → $serverTxid');
      } catch (e) {
        print('❌ Error updating local record: $e');
      }
    }
  }

  /// Process confirmed soft deletes.
  ///
  /// After server confirms sync, permanently remove soft-deleted records
  /// from the local database.
  ///
  /// Parameters:
  /// - `changes`: List of changes that were successfully synced
  Future<void> processConfirmedSoftDeletes(
    List<Map<String, dynamic>> changes,
  ) async {
    for (final change in changes) {
      try {
        final payload = change['payload'] as Map<String, dynamic>?;
        if (payload == null) continue;

        final newData = payload['New'] as Map<String, dynamic>?;
        if (newData == null) continue;

        final deletedTxid = newData['mtds_delete_ts'];
        if (deletedTxid != null) {
          final tableName = change['table_name'] as String;
          final pk = change['record_pk'];

          // Get primary key column name
          final pkColumn = await _schemaHelper.getPrimaryKeyColumn(tableName);

          // Permanently remove soft-deleted record
          await db.customStatement(
            'DELETE FROM $tableName WHERE $pkColumn = ?',
            [pk],
          );

          print(
            '🗑️ Permanently removed soft-deleted record: $tableName[$pkColumn=$pk]',
          );
        }
      } catch (e) {
        print('❌ Error processing soft delete: $e');
      }
    }
  }
}

