import 'dart:convert';
import 'package:crypto/crypto.dart';

/// MTDS Protocol Utilities
///
/// Core utilities for Multi-Tenant Data Synchronization protocol:
/// - Database name generation
class MtdsUtils {
  // ============================================================================
  // Utilities
  // ============================================================================

  /// Get current UTC timestamp as ISO 8601 string (for debugging)
  static String getUtcTimestampString() {
    return DateTime.now().toUtc().toIso8601String();
  }

  // ============================================================================
  // Deprecated Device ID Methods (removed - use StateTableService instead)
  // ============================================================================
  // Device ID management has been moved to mtds_state table.
  // The SDK now uses 64-bit device IDs stored in StateTableService.
  // These methods are no longer needed.

  // ============================================================================
  // Database Name Generation (SHA256)
  // ============================================================================
  /// Generate database name using SHA256('sub:tid:app')
  /// Format: XXXX-XXXX-XXXX-...-XXXX.db (64 hex chars + hyphens)
  static String generateDatabaseName({
    required String subjectId,
    required String tenantId,
    required String appName,
  }) {
    // Validate inputs
    if (subjectId.isEmpty || tenantId.isEmpty || appName.isEmpty) {
      throw ArgumentError('subjectId, tenantId, and appName must not be empty');
    }

    // Create the string: 'sub:tid:app'
    final input = '$subjectId:$tenantId:$appName';

    // Generate SHA256 hash
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);

    // Convert to uppercase hex string (64 characters)
    final hexString = digest.toString().toUpperCase();

    // Format with hyphens every 4 characters
    final buffer = StringBuffer();

    for (int i = 0; i < hexString.length; i += 4) {
      if (i > 0) buffer.write('-');

      buffer.write(hexString.substring(i, i + 4));
    }

    return '${buffer.toString()}.db';
  }
}
