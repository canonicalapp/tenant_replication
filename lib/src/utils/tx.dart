/// Transaction ID (TXID) generation with monotonic counter
///
/// Provides unique, strictly increasing transaction IDs for MTDS synchronization.
/// Uses a monotonic counter combined with timestamp to guarantee uniqueness
/// even under concurrent operations.
///
/// Example:
/// ```dart
/// final txid1 = TX.getId(); // Returns BigInt
/// final txid2 = TX.getId(); // Returns BigInt > txid1
/// ```
class TX {
  /// Static counter that ensures monotonic ordering
  static BigInt now = BigInt.zero;

  /// Generate a unique transaction ID
  ///
  /// Returns a BigInt that is guaranteed to be:
  /// - Unique (no two calls return the same value)
  /// - Strictly increasing (each call returns a value > previous)
  /// - Based on timestamp with counter fallback
  ///
  /// The counter is initialized from the current timestamp in nanoseconds.
  /// If the timestamp is not greater than the current counter, the counter
  /// is incremented to maintain monotonicity.
  ///
  /// Returns: BigInt representing nanoseconds since Unix epoch (with counter guarantee)
  static BigInt getId() {
    // Get current timestamp in nanoseconds
    final BigInt ns =
        BigInt.from(DateTime.now().microsecondsSinceEpoch) * BigInt.from(1000);

    // Ensure monotonicity: if timestamp is not greater, increment counter
    now = (ns > now) ? ns : now + BigInt.one;

    return now;
  }
}
