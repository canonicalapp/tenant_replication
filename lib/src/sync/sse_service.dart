import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../models/server_events.dart';
import '../utils/bigint_utils.dart';

/// Service for handling Server-Sent Events (SSE)
///
/// Manages real-time updates from the server, automatically applying
/// changes to the local database.
class SSEService {
  final GeneratedDatabase db;
  final Dio httpClient;
  final String serverUrl;
  final int deviceId;
  final Map<String, String> _pkCache = {};

  StreamController<ServerEvent>? _sseController;
  StreamController<bool>? _connectionStateController;
  CancelToken? _cancelToken;
  bool _isConnected = false;

  SSEService({
    required this.db,
    required this.httpClient,
    required this.serverUrl,
    required this.deviceId,
  });

  /// Check if SSE is currently connected
  bool get isConnected => _isConnected;

  /// Stream of connection state changes
  ///
  /// Emits `true` when connected, `false` when disconnected.
  /// The current state is emitted immediately when a listener subscribes.
  Stream<bool> get connectionStateStream {
    _connectionStateController ??= StreamController<bool>.broadcast();
    // Emit current state immediately for new listeners
    Future.microtask(() {
      if (!_connectionStateController!.isClosed) {
        _connectionStateController!.add(_isConnected);
      }
    });
    return _connectionStateController!.stream;
  }

  /// Subscribe to server-sent events for real-time updates
  ///
  /// Opens a persistent connection to the server that receives real-time
  /// data changes. Updates are automatically applied to the local database.
  ///
  /// The connection will automatically reconnect if dropped.
  ///
  /// Example:
  /// ```dart
  /// final stream = sseService.subscribeToSSE();
  /// stream.listen((event) {
  ///   print('Received: ${event.type} for ${event.table}');
  ///   // Update UI
  /// });
  /// ```
  Stream<ServerEvent> subscribeToSSE() {
    if (_sseController != null && !_sseController!.isClosed) {
      return _sseController!.stream;
    }

    _sseController = StreamController<ServerEvent>.broadcast(
      onListen: _connectSSE,
      onCancel: _disconnectSSE,
    );

    return _sseController!.stream;
  }

  /// Connect to SSE endpoint
  Future<void> _connectSSE() async {
    if (_isConnected) {
      print('⚠️ SSE already connected');
      return;
    }

    try {
      final url = '$serverUrl/mtdd/sync/events';
      print('🔌 Connecting to SSE: $url');
      print('   Device ID: $deviceId');

      _cancelToken = CancelToken();

      // Prepare headers - Dio will merge these with interceptor headers
      final headers = <String, dynamic>{
        'Accept': 'text/event-stream',
        'deviceId': deviceId.toString(),
      };

      final response = await httpClient.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          followRedirects: true,
          validateStatus: (status) {
            // Accept 200 OK for successful SSE connection
            return status == 200;
          },
        ),
        cancelToken: _cancelToken,
      );

      _isConnected = true;
      _connectionStateController?.add(true);
      print('✅ SSE connected successfully');

      // Process stream
      final stream = response.data?.stream;
      if (stream == null) {
        print('❌ SSE stream is null');
        _isConnected = false;
        _connectionStateController?.add(false);
        return;
      }

      print('📡 SSE stream established, listening for events...');

      stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _processSSEMessage,
            onError: (error) {
              print('❌ SSE stream error: $error');
              print('   Error type: ${error.runtimeType}');
              _handleDisconnect();
            },
            onDone: () {
              print('🔌 SSE connection closed by server');
              _handleDisconnect();
            },
            cancelOnError: false,
          );
    } on DioException catch (e) {
      print('❌ SSE connection failed: ${e.message}');
      if (e.response != null) {
        print('   Status: ${e.response!.statusCode}');
      }

      _isConnected = false;
      _connectionStateController?.add(false);
      _scheduleReconnect();
    } catch (e) {
      print('❌ Failed to connect to SSE: $e');
      _isConnected = false;
      _connectionStateController?.add(false);
      _scheduleReconnect();
    }
  }

  /// Process incoming SSE message
  ///
  /// SSE format supports:
  /// - `data: <json>` - The actual data payload
  /// - `event: <type>` - Event type
  /// - `id: <id>` - Event ID
  /// - `: <comment>` - Comments (ignored)
  /// - Empty lines - Field separators
  void _processSSEMessage(String line) {
    // Trim whitespace
    final trimmed = line.trim();

    // Skip empty lines
    if (trimmed.isEmpty) return;

    // Skip comments (lines starting with ':')
    if (trimmed.startsWith(':')) {
      return;
    }

    // Handle data lines
    if (trimmed.startsWith('data: ')) {
      final data =
          trimmed.substring(6).trim(); // Remove 'data: ' prefix and trim

      // Skip empty data lines
      if (data.isEmpty) {
        return;
      }

      try {
        // Try to parse as JSON - jsonDecode will throw FormatException for non-JSON
        final json = jsonDecode(data) as Map<String, dynamic>;

        final event = ServerEvent.fromJson(json);

        print('📨 SSE event: ${event.type} for ${event.table ?? 'unknown'}');

        // Auto-apply update to local database
        if ((event.type == ServerEventType.update ||
                event.type == ServerEventType.insert) &&
            event.table != null &&
            event.data != null) {
          _applyServerUpdate(event);
        }

        // Emit event to subscribers
        _sseController?.add(event);
      } on FormatException {
        // Not JSON - treat as informational message (e.g., "Connected")
        print('📡 SSE message: $data');
      } catch (e) {
        // Other errors (e.g., ServerEvent parsing errors)
        print('❌ Error processing SSE message: $e');
        print(
          '   Data: ${data.length > 200 ? data.substring(0, 200) + '...' : data}',
        );
      }
    } else if (trimmed.startsWith('event: ')) {
      // Handle event type lines
      final eventType = trimmed.substring(7).trim();
      print('📋 SSE event type: $eventType');
    } else if (trimmed.startsWith('id: ')) {
      // Handle event ID lines
      final eventId = trimmed.substring(4).trim();
      print('🆔 SSE event ID: $eventId');
    } else if (trimmed.startsWith('retry: ')) {
      // Handle retry lines
      final retry = trimmed.substring(7).trim();
      print('🔄 SSE retry: $retry');
    } else {
      // Unknown line format - log for debugging
      print(
        '⚠️  Unknown SSE line format: ${trimmed.length > 100 ? trimmed.substring(0, 100) + '...' : trimmed}',
      );
    }
  }

  /// Apply server update to local database
  ///
  /// This method receives updates from SSE and applies them locally.
  /// It checks the DeviceID to prevent loops - updates from this device
  /// are skipped.
  Future<void> _applyServerUpdate(ServerEvent event) async {
    try {
      final tableName = event.table!;
      final payload = Map<String, dynamic>.from(event.data!);
      // Handle device ID - convert to BigInt using utility
      final recordDeviceId = BigIntUtils.toBigInt(payload['mtds_device_id']);

      // Prevent loop: Don't apply updates from this device
      if (recordDeviceId != null &&
          BigIntUtils.equals(recordDeviceId, BigInt.from(deviceId))) {
        print('⏭️ Skipping update from this device ($deviceId)');
        return;
      }

      // Handle client timestamp - convert to BigInt using utility
      final recordTxid = BigIntUtils.toBigInt(payload['mtds_client_ts']);

      String? pkColumnName =
          event.pkColumn ?? payload.remove('pkColumn') as String?;

      Object? pkValue = event.pkValue ?? payload.remove('pkValue');

      pkColumnName ??= await _resolvePrimaryKeyColumn(tableName);
      pkValue ??= pkColumnName != null ? payload[pkColumnName] : null;

      if (pkColumnName == null || pkValue == null) {
        print('⚠️ Missing primary key metadata in server update');
        return;
      }

      // Ensure payload includes the PK column so inserts succeed.
      payload.putIfAbsent(pkColumnName, () => pkValue);

      if (recordTxid == null) {
        print('⚠️ Missing txid in server update');
        return;
      }

      // recordTxid is guaranteed to be non-null after the check above
      // Check if local record exists and compare timestamps
      final tableInfo =
          await db.customSelect('PRAGMA table_info($tableName)').get();

      // Query existing record
      final existing =
          await db
              .customSelect(
                'SELECT mtds_client_ts AS txid FROM $tableName WHERE $pkColumnName = ?',
                variables: [_variableForValue(pkValue)],
              )
              .get();

      // Apply update if:
      // 1. Record doesn't exist locally, OR
      // 2. Server timestamp is newer than local timestamp
      final existingTxidRaw =
          existing.isEmpty ? null : existing.first.data['txid'];
      final existingTxid = BigIntUtils.toBigInt(existingTxidRaw);

      // recordTxid is guaranteed to be non-null here due to earlier check
      if (existing.isEmpty ||
          existingTxid == null ||
          BigIntUtils.isGreater(recordTxid, existingTxid)) {
        // Build INSERT OR REPLACE statement
        final columns =
            tableInfo.map((col) => col.data['name'] as String).toList();

        // Filter columns to only include those present in the payload
        final validColumns =
            columns.where((col) => payload.containsKey(col)).toList();

        if (validColumns.isEmpty) {
          print(
            '   ⚠️ Skipping SSE update: no valid columns found for $tableName[$pkColumnName=$pkValue]',
          );
          print('      Local columns: $columns');
          print('      Payload keys: ${payload.keys.toList()}');
          return;
        }

        final placeholders = List.filled(validColumns.length, '?').join(', ');
        final columnNames = validColumns.join(', ');
        final values = validColumns.map((colName) => payload[colName]).toList();

        // TODO: Replace with Drift insert/update once database is set up
        await db.customStatement(
          'INSERT OR REPLACE INTO $tableName ($columnNames) VALUES ($placeholders)',
          values,
        );

        print('✅ Applied SSE update: $tableName[$pkColumnName=$pkValue]');
      } else {
        print(
          '⏭️ Skipping older update for $tableName[$pkColumnName=$pkValue]',
        );
      }
    } catch (e) {
      print('❌ Error applying server update: $e');
    }
  }

  Future<String?> _resolvePrimaryKeyColumn(String tableName) async {
    if (_pkCache.containsKey(tableName)) {
      return _pkCache[tableName];
    }

    final tableInfo =
        await db.customSelect('PRAGMA table_info($tableName)').get();
    final pkColumn = tableInfo.firstWhere(
      (col) => col.data['pk'] == 1,
      orElse:
          () => throw Exception('No primary key found for table $tableName'),
    );
    final name = pkColumn.data['name'] as String?;
    if (name != null) {
      _pkCache[tableName] = name;
    }
    return name;
  }

  Variable _variableForValue(Object? value) {
    if (value is int) return Variable.withInt(value);
    if (value is double) return Variable.withReal(value);
    if (value is num) return Variable.withReal(value.toDouble());
    if (value is bool) return Variable.withBool(value);
    if (value is Uint8List) return Variable.withBlob(value);
    if (value is String) return Variable.withString(value);
    return Variable.withString(value?.toString() ?? '');
  }

  /// Handle disconnect and schedule reconnect
  void _handleDisconnect() {
    _isConnected = false;
    _connectionStateController?.add(false);
    _scheduleReconnect();
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_sseController != null && !_sseController!.isClosed) {
        print('🔄 Attempting to reconnect SSE...');
        _connectSSE();
      }
    });
  }

  /// Disconnect from SSE
  void _disconnectSSE() {
    print('🔌 Disconnecting from SSE...');
    _cancelToken?.cancel();
    _isConnected = false;
    _connectionStateController?.add(false);
  }

  /// Dispose resources
  void dispose() {
    _disconnectSSE();
    _sseController?.close();
    _sseController = null;
    _connectionStateController?.close();
    _connectionStateController = null;
  }
}
