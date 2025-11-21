/// Utility for managing activity logs
class ActivityLogger {
  final List<String> _logs = [];
  static const int maxLogs = 50;

  /// Add a log entry with timestamp
  void add(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logs.insert(0, '[$timestamp] $message');
    if (_logs.length > maxLogs) {
      _logs.removeRange(maxLogs, _logs.length);
    }
  }

  /// Get all logs
  List<String> get logs => List.unmodifiable(_logs);

  /// Clear all logs
  void clear() {
    _logs.clear();
  }

  /// Get log count
  int get count => _logs.length;
}
