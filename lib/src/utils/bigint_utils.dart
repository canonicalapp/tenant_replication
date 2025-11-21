/// Utility functions for handling BigInt conversions and comparisons.
///
/// These utilities handle conversion from various types (int, BigInt, String, num)
/// that may come from JSON payloads, database results, or API responses.
class BigIntUtils {
  /// Convert a value to BigInt, handling multiple input types.
  ///
  /// Supports:
  /// - `BigInt` - returns as-is
  /// - `int` - converts to BigInt
  /// - `String` - parses as BigInt
  /// - `num` (double/int) - converts to int then BigInt
  /// - `null` - returns null
  ///
  /// Parameters:
  /// - `value`: The value to convert (can be BigInt, int, String, num, or null)
  ///
  /// Returns:
  /// - `BigInt?` - The converted BigInt value, or null if value is null or cannot be parsed
  ///
  /// Example:
  /// ```dart
  /// final bigInt = BigIntUtils.toBigInt(12345); // BigInt.from(12345)
  /// final fromString = BigIntUtils.toBigInt('12345'); // BigInt.parse('12345')
  /// final fromNull = BigIntUtils.toBigInt(null); // null
  /// ```
  static BigInt? toBigInt(dynamic value) {
    if (value == null) return null;
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is String) return BigInt.tryParse(value);
    if (value is num) return BigInt.from(value.toInt());
    return null;
  }

  /// Convert a value to BigInt, throwing an exception if conversion fails.
  ///
  /// Similar to [toBigInt] but throws [ArgumentError] if value cannot be converted.
  ///
  /// Parameters:
  /// - `value`: The value to convert
  /// - `name`: Optional name for the value (used in error message)
  ///
  /// Returns:
  /// - `BigInt` - The converted BigInt value (never null)
  ///
  /// Throws:
  /// - `ArgumentError` if value is null or cannot be converted
  ///
  /// Example:
  /// ```dart
  /// final bigInt = BigIntUtils.toBigIntOrThrow(12345); // BigInt.from(12345)
  /// final invalid = BigIntUtils.toBigIntOrThrow('invalid'); // throws ArgumentError
  /// ```
  static BigInt toBigIntOrThrow(dynamic value, [String? name]) {
    final result = toBigInt(value);
    if (result == null) {
      throw ArgumentError(
        'Cannot convert ${name ?? 'value'} to BigInt: $value (type: ${value.runtimeType})',
      );
    }
    return result;
  }

  /// Compare two BigInt values, handling null cases.
  ///
  /// Returns:
  /// - `-1` if `a < b`
  /// - `0` if `a == b`
  /// - `1` if `a > b`
  /// - `null` if either value is null
  ///
  /// Parameters:
  /// - `a`: First BigInt value (nullable)
  /// - `b`: Second BigInt value (nullable)
  ///
  /// Example:
  /// ```dart
  /// final cmp = BigIntUtils.compare(BigInt.from(10), BigInt.from(20)); // -1
  /// final nullCmp = BigIntUtils.compare(null, BigInt.from(10)); // null
  /// ```
  static int? compare(BigInt? a, BigInt? b) {
    if (a == null || b == null) return null;
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
  }

  /// Check if `a` is greater than `b`, handling null cases.
  ///
  /// Returns:
  /// - `true` if `a > b` and both are non-null
  /// - `false` if either is null or `a <= b`
  ///
  /// Parameters:
  /// - `a`: First BigInt value (nullable)
  /// - `b`: Second BigInt value (nullable)
  ///
  /// Example:
  /// ```dart
  /// final isGreater = BigIntUtils.isGreater(BigInt.from(20), BigInt.from(10)); // true
  /// final nullCheck = BigIntUtils.isGreater(null, BigInt.from(10)); // false
  /// ```
  static bool isGreater(BigInt? a, BigInt? b) {
    if (a == null || b == null) return false;
    return a > b;
  }

  /// Check if `a` is greater than or equal to `b`, handling null cases.
  ///
  /// Returns:
  /// - `true` if `a >= b` and both are non-null
  /// - `false` if either is null or `a < b`
  ///
  /// Parameters:
  /// - `a`: First BigInt value (nullable)
  /// - `b`: Second BigInt value (nullable)
  ///
  /// Example:
  /// ```dart
  /// final isGreaterOrEqual = BigIntUtils.isGreaterOrEqual(BigInt.from(20), BigInt.from(20)); // true
  /// final nullCheck = BigIntUtils.isGreaterOrEqual(null, BigInt.from(10)); // false
  /// ```
  static bool isGreaterOrEqual(BigInt? a, BigInt? b) {
    if (a == null || b == null) return false;
    return a >= b;
  }

  /// Check if `a` equals `b`, handling null cases.
  ///
  /// Returns:
  /// - `true` if both are null or both are non-null and equal
  /// - `false` otherwise
  ///
  /// Parameters:
  /// - `a`: First BigInt value (nullable)
  /// - `b`: Second BigInt value (nullable)
  ///
  /// Example:
  /// ```dart
  /// final isEqual = BigIntUtils.equals(BigInt.from(10), BigInt.from(10)); // true
  /// final nullEqual = BigIntUtils.equals(null, null); // true
  /// final nullNotEqual = BigIntUtils.equals(null, BigInt.from(10)); // false
  /// ```
  static bool equals(BigInt? a, BigInt? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a == b;
  }
}
