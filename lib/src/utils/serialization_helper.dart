import 'dart:convert';
import 'dart:typed_data';

/// Helper class for serializing data for sync operations.
///
/// Handles:
/// - Base64 encoding for binary (BLOB) fields
/// - BigInt serialization (converts to strings for JSON compatibility)
/// - Proper JSON number formatting (unquoted numbers for json-bigint compatibility)
class SerializationHelper {
  /// Serialize a row/record to JSON-compatible format.
  ///
  /// This method:
  /// 1. Detects binary (BLOB) fields and encodes them as Base64
  /// 2. Converts BigInt values to strings for JSON compatibility
  /// 3. Ensures numeric values are proper JSON numbers (not quoted)
  ///
  /// **Note**: Binary field detection is based on value type (Uint8List, List<int>).
  /// For more accurate detection, use [serializeRowWithSchema] which checks
  /// the actual column types from the database schema.
  ///
  /// Parameters:
  /// - `row`: Map of column names to values
  /// - `binaryFields`: Optional list of column names that are binary (BLOB) fields
  ///
  /// Returns:
  /// - Map with binary fields Base64-encoded and BigInt values as strings
  ///
  /// Example:
  /// ```dart
  /// final row = {'id': 1, 'name': 'John', 'avatar': Uint8List.fromList([1,2,3])};
  /// final serialized = SerializationHelper.serializeRow(row, binaryFields: ['avatar']);
  /// // serialized['avatar'] is now a Base64 string
  /// ```
  static Map<String, dynamic> serializeRow(
    Map<String, dynamic> row, {
    List<String>? binaryFields,
  }) {
    final result = <String, dynamic>{};

    for (final entry in row.entries) {
      final key = entry.key;
      final value = entry.value;

      // Handle null values
      if (value == null) {
        result[key] = null;
        continue;
      }

      // Handle binary fields (BLOB columns)
      if (binaryFields != null && binaryFields.contains(key)) {
        result[key] = _encodeBinary(value);
        continue;
      }

      // Auto-detect binary data (Uint8List, List<int>)
      if (value is Uint8List ||
          (value is List && value.isNotEmpty && value.first is int)) {
        // Check if it's actually binary data (not a regular list of integers)
        if (value is Uint8List || _isBinaryList(value)) {
          result[key] = _encodeBinary(value);
          continue;
        }
      }

      // Handle BigInt values (convert to string for JSON compatibility)
      if (value is BigInt) {
        result[key] = value.toString();
        continue;
      }

      // Handle int values (ensure they're JSON numbers, not strings)
      if (value is int) {
        result[key] = value;
        continue;
      }

      // Handle double values
      if (value is double) {
        result[key] = value;
        continue;
      }

      // Handle other types as-is (String, bool, etc.)
      result[key] = value;
    }

    return result;
  }

  /// Serialize a row with schema information for accurate binary detection.
  ///
  /// This method uses column type information from the database schema
  /// to accurately identify BLOB columns.
  ///
  /// Parameters:
  /// - `row`: Map of column names to values
  /// - `columnTypes`: Map of column names to their SQLite types (e.g., 'BLOB', 'INTEGER', 'TEXT')
  ///
  /// Returns:
  /// - Map with binary fields Base64-encoded and BigInt values as strings
  ///
  /// Example:
  /// ```dart
  /// final columnTypes = {'id': 'INTEGER', 'name': 'TEXT', 'avatar': 'BLOB'};
  /// final serialized = SerializationHelper.serializeRowWithSchema(row, columnTypes);
  /// ```
  static Map<String, dynamic> serializeRowWithSchema(
    Map<String, dynamic> row,
    Map<String, String> columnTypes,
  ) {
    // Extract binary field names from column types
    final binaryFields =
        columnTypes.entries
            .where((e) => e.value.toUpperCase() == 'BLOB')
            .map((e) => e.key)
            .toList();

    return serializeRow(row, binaryFields: binaryFields);
  }

  /// Deserialize a row from JSON format.
  ///
  /// This method:
  /// 1. Decodes Base64 strings back to binary data (if binaryFields provided)
  /// 2. Converts string representations of BigInt back to BigInt
  /// 3. Handles all data types correctly
  ///
  /// Parameters:
  /// - `row`: Map of column names to values (from JSON)
  /// - `binaryFields`: Optional list of column names that are binary (BLOB) fields
  ///
  /// Returns:
  /// - Map with binary fields decoded and BigInt values restored
  ///
  /// Example:
  /// ```dart
  /// final jsonRow = {'id': 1, 'name': 'John', 'avatar': 'AQID'}; // Base64
  /// final deserialized = SerializationHelper.deserializeRow(jsonRow, binaryFields: ['avatar']);
  /// // deserialized['avatar'] is now Uint8List
  /// ```
  static Map<String, dynamic> deserializeRow(
    Map<String, dynamic> row, {
    List<String>? binaryFields,
  }) {
    final result = <String, dynamic>{};

    for (final entry in row.entries) {
      final key = entry.key;
      final value = entry.value;

      // Handle null values
      if (value == null) {
        result[key] = null;
        continue;
      }

      // Handle binary fields (decode Base64)
      if (binaryFields != null &&
          binaryFields.contains(key) &&
          value is String) {
        try {
          result[key] = base64Decode(value);
        } catch (e) {
          // If decoding fails, keep original value
          result[key] = value;
        }
        continue;
      }

      // Handle BigInt strings (convert back to BigInt)
      if (value is String) {
        final bigInt = BigInt.tryParse(value);
        if (bigInt != null && value.length > 15) {
          // Likely a BigInt if string is long and parses as BigInt
          // (regular ints are usually shorter)
          result[key] = bigInt;
          continue;
        }
      }

      // Handle other types as-is
      result[key] = value;
    }

    return result;
  }

  /// Encode binary data to Base64 string.
  ///
  /// Handles Uint8List, List<int>, and other binary formats.
  static String _encodeBinary(dynamic value) {
    if (value is Uint8List) {
      return base64Encode(value);
    }
    if (value is List<int>) {
      return base64Encode(value);
    }
    if (value is List && value.isNotEmpty) {
      // Try to convert to List<int>
      try {
        final intList = value.cast<int>();
        return base64Encode(intList);
      } catch (e) {
        // If conversion fails, return as string representation
        return value.toString();
      }
    }
    // Fallback: convert to string
    return value.toString();
  }

  /// Check if a list is binary data (list of integers representing bytes).
  static bool _isBinaryList(dynamic value) {
    if (value is! List || value.isEmpty) return false;

    // Check if all elements are integers in byte range (0-255)
    try {
      for (final item in value) {
        if (item is! int || item < 0 || item > 255) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Serialize a list of rows.
  ///
  /// Convenience method for serializing multiple rows at once.
  static List<Map<String, dynamic>> serializeRows(
    List<Map<String, dynamic>> rows, {
    List<String>? binaryFields,
  }) {
    return rows
        .map((row) => serializeRow(row, binaryFields: binaryFields))
        .toList();
  }

  /// Deserialize a list of rows.
  ///
  /// Convenience method for deserializing multiple rows at once.
  static List<Map<String, dynamic>> deserializeRows(
    List<Map<String, dynamic>> rows, {
    List<String>? binaryFields,
  }) {
    return rows
        .map((row) => deserializeRow(row, binaryFields: binaryFields))
        .toList();
  }
}
