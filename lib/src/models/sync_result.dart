/// Result of a sync operation
class SyncResult {
  /// Whether the sync was successful
  final bool success;

  /// Number of records successfully processed
  final int processed;

  /// Number of records that failed
  final int errors;

  /// Total number of records attempted
  final int total;

  /// Optional error message if sync failed
  final String? errorMessage;

  /// Duration of the sync operation
  final Duration? duration;

  const SyncResult({
    required this.success,
    required this.processed,
    required this.errors,
    required this.total,
    this.errorMessage,
    this.duration,
  });

  /// Create a successful result
  factory SyncResult.success({
    required int processed,
    int errors = 0,
    Duration? duration,
  }) {
    return SyncResult(
      success: true,
      processed: processed,
      errors: errors,
      total: processed + errors,
      duration: duration,
    );
  }

  /// Create a failed result
  factory SyncResult.failure({
    required String errorMessage,
    int total = 0,
    Duration? duration,
  }) {
    return SyncResult(
      success: false,
      processed: 0,
      errors: total,
      total: total,
      errorMessage: errorMessage,
      duration: duration,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'success': success,
    'processed': processed,
    'errors': errors,
    'total': total,
    if (errorMessage != null) 'errorMessage': errorMessage,
    if (duration != null) 'duration': duration!.inMilliseconds,
  };

  @override
  String toString() {
    return 'SyncResult(success: $success, processed: $processed, '
        'errors: $errors, total: $total${errorMessage != null ? ', error: $errorMessage' : ''})';
  }
}
