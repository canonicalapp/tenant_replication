import 'dart:math';

import 'package:drift/drift.dart';

/// Service for managing the `mtds_state` table.
///
/// Provides methods to upsert and retrieve state values using Drift's
/// custom SQL methods for type safety where possible.
class StateTableService {
  final GeneratedDatabase db;

  StateTableService({required this.db});

  /// Upsert a numeric value for an attribute.
  ///
  /// If the attribute exists, updates its numValue.
  /// If the attribute doesn't exist, inserts a new row with the provided numValue.
  ///
  /// Parameters:
  /// - `attribute`: The attribute name/key
  /// - `numValue`: The numeric value to set
  ///
  /// Example:
  /// ```dart
  /// await service.upsertNumValue('mtds:DeviceID', 12345);
  /// ```
  Future<void> upsertNumValue(String attribute, int numValue) async {
    await db.customStatement(
      '''
      INSERT INTO mtds_state (attribute, numValue)
      VALUES (?, ?)
      ON CONFLICT(attribute) DO UPDATE SET numValue = excluded.numValue;
      ''',
      [attribute, numValue],
    );
  }

  /// Upsert a text value for an attribute.
  ///
  /// If the attribute exists, updates its textValue.
  /// If the attribute doesn't exist, inserts a new row with the provided textValue.
  ///
  /// Parameters:
  /// - `attribute`: The attribute name/key
  /// - `textValue`: The text value to set (nullable)
  ///
  /// Example:
  /// ```dart
  /// await service.upsertTextValue('mtds:lastSyncTS', '2025-01-01T00:00:00Z');
  /// ```
  Future<void> upsertTextValue(String attribute, String? textValue) async {
    await db.customStatement(
      '''
      INSERT INTO mtds_state (attribute, textValue)
      VALUES (?, ?)
      ON CONFLICT(attribute) DO UPDATE SET textValue = excluded.textValue;
      ''',
      [attribute, textValue],
    );
  }

  /// Get the numeric value for an attribute.
  ///
  /// Returns the numValue if the attribute exists, otherwise returns 0.
  ///
  /// Parameters:
  /// - `attribute`: The attribute name/key
  ///
  /// Returns:
  /// - The numeric value (int) or 0 if not found
  ///
  /// Example:
  /// ```dart
  /// final deviceId = await service.getNumValue('mtds:DeviceID');
  /// ```
  Future<int> getNumValue(String attribute) async {
    final result =
        await db
            .customSelect(
              'SELECT numValue FROM mtds_state WHERE attribute = ?',
              variables: [Variable.withString(attribute)],
            )
            .get();

    if (result.isEmpty) return 0;
    return result.first.data['numValue'] as int? ?? 0;
  }

  /// Get the text value for an attribute.
  ///
  /// Returns the textValue if the attribute exists, otherwise returns null.
  ///
  /// Parameters:
  /// - `attribute`: The attribute name/key
  ///
  /// Returns:
  /// - The text value (String?) or null if not found
  ///
  /// Example:
  /// ```dart
  /// final lastSync = await service.getTextValue('mtds:lastSyncTS');
  /// ```
  Future<String?> getTextValue(String attribute) async {
    final result =
        await db
            .customSelect(
              'SELECT textValue FROM mtds_state WHERE attribute = ?',
              variables: [Variable.withString(attribute)],
            )
            .get();

    if (result.isEmpty) return null;
    return result.first.data['textValue'] as String?;
  }

  /// Get the next client timestamp with monotonic guarantee.
  ///
  /// Updates the `'mtds:client_ts'` attribute in the state table using:
  /// `MAX(numValue + 1, current_time_ms - 1735689600000)`
  ///
  /// This ensures:
  /// - Monotonic increment (always increases)
  /// - Never decreases even if system clock goes backwards
  /// - Returns timestamp in milliseconds since client epoch (January 1, 2025)
  ///
  /// Returns:
  /// - The updated client timestamp as BigInt (milliseconds since 2025 epoch)
  ///
  /// Example:
  /// ```dart
  /// final clientTs = await service.getNextClientTimestamp();
  /// ```
  Future<BigInt> getNextClientTimestamp() async {
    // Epoch start: January 1, 2025 (timestamp: 1735689600000 milliseconds)
    const int epochMs = 1735689600000;

    // Calculate current time since epoch in milliseconds
    final now = DateTime.now().millisecondsSinceEpoch;
    final currentTimeSinceEpoch = now - epochMs;

    // Get current value (or 0 if not exists)
    final currentValue = await getNumValue('mtds:client_ts');

    // Calculate new value: MAX(currentValue + 1, currentTimeSinceEpoch)
    final newValue = max(currentValue + 1, currentTimeSinceEpoch);

    // Update state table atomically
    await upsertNumValue('mtds:client_ts', newValue);

    return BigInt.from(newValue);
  }

  /// Get the maximum server timestamp for a table.
  ///
  /// This method:
  /// 1. First checks the state table (Attribute = 'table:' + tableName)
  /// 2. If not found, queries MAX(mtds_server_ts) from the user table
  /// 3. Caches the result in state table for future use
  ///
  /// This caching improves performance by avoiding repeated MAX queries,
  /// especially after hard deletes or when tables are large.
  ///
  /// Parameters:
  /// - `tableName`: Name of the table to get MAX timestamp for
  ///
  /// Returns:
  /// - BigInt representing the maximum mtds_server_ts, or BigInt.zero if no records exist
  ///
  /// Example:
  /// ```dart
  /// final maxTs = await service.getMaxServerTimestamp('users');
  /// ```
  Future<BigInt> getMaxServerTimestamp(String tableName) async {
    final attribute = 'table:$tableName';

    // First, check state table for cached value
    final cachedValue = await getNumValue(attribute);
    if (cachedValue > 0) {
      return BigInt.from(cachedValue);
    }

    // If not cached, query MAX(mtds_server_ts) from user table
    // Note: mtds_server_ts can be NULL, so we use COALESCE to handle that
    final result =
        await db.customSelect('''
      SELECT COALESCE(MAX(mtds_server_ts), 0) as max_ts
      FROM $tableName
      WHERE mtds_server_ts IS NOT NULL
      ''', readsFrom: {}).get();

    final maxTs =
        result.isEmpty
            ? BigInt.zero
            : BigInt.from(result.first.data['max_ts'] as int? ?? 0);

    // Cache the result in state table (even if 0, to avoid repeated queries)
    await upsertNumValue(attribute, maxTs.toInt());

    return maxTs;
  }

  /// Update the maximum server timestamp for a table.
  ///
  /// Called after sync operations to update the cached MAX timestamp.
  /// This ensures subsequent syncs use the correct starting point.
  ///
  /// Parameters:
  /// - `tableName`: Name of the table
  /// - `maxTimestamp`: The new maximum timestamp to cache
  ///
  /// Example:
  /// ```dart
  /// await service.updateMaxServerTimestamp('users', BigInt.from(1234567890));
  /// ```
  Future<void> updateMaxServerTimestamp(
    String tableName,
    BigInt maxTimestamp,
  ) async {
    final attribute = 'table:$tableName';
    await upsertNumValue(attribute, maxTimestamp.toInt());
  }

  /// Get MAX server timestamp for multiple tables.
  ///
  /// Returns a map of table names to their maximum server timestamps.
  /// Uses cached values from state table when available.
  ///
  /// Parameters:
  /// - `tableNames`: List of table names to get timestamps for
  ///
  /// Returns:
  /// - Map of table name to BigInt timestamp
  ///
  /// Example:
  /// ```dart
  /// final timestamps = await service.getMaxServerTimestamps(['users', 'products']);
  /// ```
  Future<Map<String, BigInt>> getMaxServerTimestamps(
    List<String> tableNames,
  ) async {
    final Map<String, BigInt> result = {};

    for (final tableName in tableNames) {
      result[tableName] = await getMaxServerTimestamp(tableName);
    }

    return result;
  }
}
