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
}
