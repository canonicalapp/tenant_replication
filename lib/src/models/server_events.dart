/// Event received from server via SSE
enum ServerEventType {
  connected,
  heartbeat,
  insert,
  update,
  delete,
  unknown;

  static ServerEventType parse(String? value) {
    if (value == null) return ServerEventType.unknown;

    return ServerEventType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ServerEventType.unknown,
    );
  }
}

enum ServerAction {
  insert,
  update,
  delete,
  unknown;

  static ServerAction parse(String? value) {
    if (value == null) return ServerAction.unknown;

    return ServerAction.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => ServerAction.unknown,
    );
  }
}

class ServerEvent {
  /// Type of event (e.g., connected, update, delete)
  final ServerEventType type;

  /// Optional table name for data events
  final String? table;

  /// Optional action for data events (e.g., INSERT, UPDATE, DELETE)
  final ServerAction action;

  /// Optional primary-key column name supplied by the server
  final String? pkColumn;

  /// Optional primary-key value supplied by the server
  final Object? pkValue;

  /// Event data payload
  final Map<String, dynamic>? data;

  /// Timestamp of the event
  final DateTime timestamp;

  ServerEvent({
    required this.type,
    this.table,
    this.pkColumn,
    this.pkValue,
    this.data,
    this.action = ServerAction.unknown,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from JSON
  factory ServerEvent.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] ?? json['action'];

    return ServerEvent(
      type: ServerEventType.parse(rawType),
      table: json['table'],
      action: ServerAction.parse(json['action']),
      pkColumn: json['pkColumn'],
      pkValue: json['pkValue'],
      data: json['data'] as Map<String, dynamic>?,
      timestamp:
          json['timestamp'] != null
              ? DateTime.parse(json['timestamp'])
              : DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'type': type.name,
    if (table != null) 'table': table,
    if (action != ServerAction.unknown) 'action': action.name,
    if (pkColumn != null) 'pkColumn': pkColumn,
    if (pkValue != null) 'pkValue': pkValue,
    if (data != null) 'data': data,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() {
    final buffer = StringBuffer('ServerEvent(type: ${type.name}');

    if (table != null) buffer.write(', table: $table');

    if (action != ServerAction.unknown) {
      buffer.write(', action: ${action.name}');
    }

    if (pkColumn != null) buffer.write(', pkColumn: $pkColumn');

    buffer.write(')');

    return buffer.toString();
  }
}
