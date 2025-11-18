import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'models/sync_result.dart';
import 'models/server_events.dart';
import 'sync/sync_service.dart';
import 'sync/sse_service.dart';
import 'sync/delete_service.dart';
import 'sync/auto_sync_service.dart' show AutoSyncService, AutoSyncEvent;
import 'helpers/pragma_helper.dart';
import 'utils/mtds_utils.dart';

/// Main SDK class for Multi-Tenant Data Synchronization (MTDS)
///
/// This SDK provides offline-first data synchronization with:
/// - Automatic change tracking via SQL triggers
/// - Soft delete (syncs to server) and hard delete (local only)
/// - Hybrid timestamps (client ordering + server authority)
/// - Real-time updates via Server-Sent Events (SSE)
/// - Conflict resolution using Last Write Wins (LWW)
///
/// ## Basic Usage
///
/// ```dart
/// // 1. Configure Dio with auth interceptors
/// final dio = Dio();
/// dio.interceptors.add(InterceptorsWrapper(
///   onRequest: (options, handler) {
///     options.headers['Authorization'] = 'Bearer $token';
///     return handler.next(options);
///   },
/// ));
///
/// // 2. Initialize SDK
/// final sdk = MTDS_SDK(
///   db: myDriftDatabase,
///   httpClient: dio,
///   serverUrl: 'https://api.example.com',
///   deviceId: 12345,
/// );
///
/// // 3. Use SDK methods
/// await sdk.softDelete(...);
/// final result = await sdk.syncToServer();
/// final stream = sdk.subscribeToSSE();
/// ```
///
/// ## Authentication
///
/// The SDK does **not** handle authentication. Configure your Dio instance
/// with interceptors to add auth headers:
///
/// ```dart
/// dio.interceptors.add(InterceptorsWrapper(
///   onRequest: (options, handler) {
///     options.headers['Authorization'] = 'Bearer $yourToken';
///     return handler.next(options);
///   },
/// ));
/// ```
class MTDS_SDK {
  /// Drift database instance
  final GeneratedDatabase db;

  /// HTTP client for server communication
  /// Configure with auth interceptors before passing to SDK
  final Dio httpClient;

  /// Base URL of the MTDS server
  final String serverUrl;

  /// Unique 48-bit identifier for this device
  final int deviceId;

  /// Sync service for uploading changes
  late final SyncService _syncService;

  /// SSE service for real-time updates
  late final SSEService _sseService;

  /// Delete service for soft/hard deletes
  late final DeleteService _deleteService;

  /// Auto-sync service for automatic synchronization
  late final AutoSyncService _autoSyncService;

  /// Initialize the MTDS SDK
  ///
  /// Parameters:
  /// - `db`: Drift database instance
  /// - `httpClient`: Dio instance (configure with auth interceptors)
  /// - `serverUrl`: Base URL of MTDS server
  /// - `deviceId`: Unique device identifier (48-bit)
  ///
  /// The SDK will:
  /// 1. Store deviceId in SQLite PRAGMAs
  /// 2. Initialize internal services
  ///
  /// Example:
  /// ```dart
  /// final sdk = MTDS_SDK(
  ///   db: AppDatabase(),
  ///   httpClient: Dio(),
  ///   serverUrl: 'https://api.example.com',
  ///   deviceId: 123456789012,
  /// );
  /// ```
  MTDS_SDK({
    required this.db,
    required this.httpClient,
    required this.serverUrl,
    required this.deviceId,
  }) {
    _initializeServices();
    _initializePragmas();
  }

  /// Initialize internal services
  void _initializeServices() {
    _syncService = SyncService(
      db: db,
      httpClient: httpClient,
      serverUrl: serverUrl,
      deviceId: deviceId,
    );

    _sseService = SSEService(
      db: db,
      httpClient: httpClient,
      serverUrl: serverUrl,
      deviceId: deviceId,
    );

    _deleteService = DeleteService(db: db, deviceId: deviceId);

    _autoSyncService = AutoSyncService(db: db, syncService: _syncService);
  }

  /// Initialize SQLite PRAGMAs with deviceId
  Future<void> _initializePragmas() async {
    await PragmaHelper.setDeviceId(db, deviceId);
  }

  // ═══════════════════════════════════════════════════════════════
  // Delete Operations
  // ═══════════════════════════════════════════════════════════════

  /// Soft delete: Mark record for deletion and sync to server
  ///
  /// Sets `mtds_deleted_txid` to mark the record as deleted.
  /// The record remains in the database and will be synced to the server.
  /// After successful sync, the record is permanently removed.
  ///
  /// Example:
  /// ```dart
  /// await sdk.softDelete(
  ///   tableName: 'users',
  ///   primaryKeyColumn: 'id',
  ///   primaryKeyValue: 123,
  /// );
  /// ```
  Future<void> softDelete({
    required String tableName,
    required String primaryKeyColumn,
    required dynamic primaryKeyValue,
  }) async {
    return _deleteService.softDelete(
      tableName: tableName,
      primaryKeyColumn: primaryKeyColumn,
      primaryKeyValue: primaryKeyValue,
    );
  }

  /// Hard delete: Permanently remove record from local database (local only)
  ///
  /// Immediately deletes the record without syncing to server.
  /// Use this for local-only data that doesn't need to be synced.
  ///
  /// ⚠️ WARNING: This operation is permanent and cannot be synced!
  ///
  /// Example:
  /// ```dart
  /// await sdk.hardDelete(
  ///   tableName: 'cache',
  ///   primaryKeyColumn: 'id',
  ///   primaryKeyValue: 456,
  /// );
  /// ```
  Future<void> hardDelete({
    required String tableName,
    required String primaryKeyColumn,
    required dynamic primaryKeyValue,
  }) async {
    return _deleteService.hardDelete(
      tableName: tableName,
      primaryKeyColumn: primaryKeyColumn,
      primaryKeyValue: primaryKeyValue,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Sync Operations
  // ═══════════════════════════════════════════════════════════════

  /// Sync local changes to the server
  ///
  /// Uploads all pending changes from the change log to the server.
  /// The server assigns authoritative timestamps which are applied
  /// to local records.
  ///
  /// Returns a [SyncResult] with success status and count of processed changes.
  ///
  /// Example:
  /// ```dart
  /// final result = await sdk.syncToServer();
  /// if (result.success) {
  ///   print('Synced ${result.processed} changes');
  /// } else {
  ///   print('Sync failed: ${result.error}');
  /// }
  /// ```
  Future<SyncResult> syncToServer() async {
    return _syncService.syncToServer();
  }

  /// Load data from server for specified tables
  ///
  /// Fetches the latest data from the server for the given tables.
  /// This should be called on app startup or after a long offline period.
  ///
  /// Parameters:
  /// - `tableNames`: List of table names to load
  ///
  /// Example:
  /// ```dart
  /// await sdk.loadFromServer(tableNames: ['users', 'products']);
  /// ```
  Future<void> loadFromServer({required List<String> tableNames}) async {
    await _syncService.loadFromServer(tableNames: tableNames);
  }

  // ═══════════════════════════════════════════════════════════════
  // Real-Time Sync (SSE)
  // ═══════════════════════════════════════════════════════════════

  /// Subscribe to server-sent events for real-time updates
  ///
  /// Opens a persistent connection to the server that receives real-time
  /// data changes. Updates are automatically applied to the local database.
  ///
  /// The connection will automatically reconnect if dropped.
  ///
  /// Example:
  /// ```dart
  /// final stream = sdk.subscribeToSSE();
  /// stream.listen((event) {
  ///   print('Received: ${event.type} for ${event.table}');
  ///   // Refresh UI
  /// });
  /// ```
  Stream<ServerEvent> subscribeToSSE() {
    return _sseService.subscribeToSSE();
  }

  /// Check if SSE is currently connected
  bool get isSSEConnected => _sseService.isConnected;

  /// Stream of SSE connection state changes
  ///
  /// Emits `true` when connected, `false` when disconnected.
  Stream<bool> get sseConnectionStateStream =>
      _sseService.connectionStateStream;

  // ═══════════════════════════════════════════════════════════════
  // Automatic Sync
  // ═══════════════════════════════════════════════════════════════

  /// Enable automatic synchronization
  ///
  /// Automatically syncs changes to the server when:
  /// - Change log has new entries (debounced)
  /// - Network comes back online (if there are pending changes)
  /// - Periodic interval (if syncInterval > 0)
  ///
  /// Parameters:
  /// - `syncInterval`: How often to check for changes (default: 30s)
  /// - `debounceDelay`: Wait time after last change before syncing (default: 5s)
  /// - `autoSyncOnReconnect`: Auto-sync when network comes back (default: true)
  /// - `minChangesForSync`: Minimum changes before syncing (default: 1)
  ///
  /// Example:
  /// ```dart
  /// await sdk.enableAutoSync(
  ///   syncInterval: Duration(seconds: 30),
  ///   debounceDelay: Duration(seconds: 5),
  /// );
  /// ```
  Future<void> enableAutoSync({
    Duration syncInterval = const Duration(seconds: 30),
    Duration debounceDelay = const Duration(seconds: 5),
    bool autoSyncOnReconnect = true,
    int minChangesForSync = 1,
  }) async {
    _autoSyncService.syncInterval = syncInterval;
    _autoSyncService.debounceDelay = debounceDelay;
    _autoSyncService.autoSyncOnReconnect = autoSyncOnReconnect;
    _autoSyncService.minChangesForSync = minChangesForSync;
    await _autoSyncService.enable();
  }

  /// Disable automatic synchronization
  Future<void> disableAutoSync() async {
    await _autoSyncService.disable();
  }

  /// Check if auto-sync is enabled
  bool get isAutoSyncEnabled => _autoSyncService.isEnabled;

  /// Check if auto-sync is currently syncing
  bool get isAutoSyncing => _autoSyncService.isSyncing;

  /// Stream of auto-sync events (for notifications)
  ///
  /// Emits events when sync starts, completes, or fails.
  Stream<AutoSyncEvent> get autoSyncEventStream => _autoSyncService.eventStream;

  // ═══════════════════════════════════════════════════════════════
  // Utilities
  // ═══════════════════════════════════════════════════════════════

  /// Generate a new TXID (UTC timestamp in nanoseconds)
  ///
  /// Example:
  /// ```dart
  /// final txid = sdk.generateTxid();
  /// ```
  int generateTxid() {
    return MtdsUtils.generateTxid();
  }

  /// Dispose resources
  ///
  /// Closes SSE connections, disables auto-sync, and cleans up resources.
  /// Call this when the SDK is no longer needed.
  ///
  /// Example:
  /// ```dart
  /// await sdk.dispose();
  /// ```
  Future<void> dispose() async {
    await _autoSyncService.dispose();
    _sseService.dispose();
    await db.close();
  }
}
