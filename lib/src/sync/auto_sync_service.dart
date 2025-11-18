import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';

import 'sync_service.dart';

/// Service for automatic synchronization
///
/// Monitors the change log and network connectivity to automatically
/// sync changes to the server when online.
class AutoSyncService {
  final GeneratedDatabase db;
  final SyncService syncService;
  final Connectivity _connectivity = Connectivity();

  Timer? _pollTimer;
  Timer? _debounceTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isEnabled = false;
  bool _isSyncing = false;
  int _lastChangeLogCount = 0;

  /// Stream controller for sync events (for notifications)
  final StreamController<AutoSyncEvent> _eventController =
      StreamController<AutoSyncEvent>.broadcast();

  // Configuration
  Duration syncInterval;
  Duration debounceDelay;
  bool autoSyncOnReconnect;
  int minChangesForSync;

  AutoSyncService({
    required this.db,
    required this.syncService,
    this.syncInterval = const Duration(seconds: 30),
    this.debounceDelay = const Duration(seconds: 5),
    this.autoSyncOnReconnect = true,
    this.minChangesForSync = 1,
  });

  /// Enable automatic syncing
  ///
  /// Starts monitoring change log and network connectivity.
  /// Syncs automatically when:
  /// - Change log has new entries (debounced)
  /// - Network comes back online (if there are pending changes)
  /// - Periodic interval (if syncInterval > 0)
  Future<void> enable() async {
    if (_isEnabled) {
      print('⚠️ Auto-sync already enabled');
      return;
    }

    _isEnabled = true;
    print('✅ Auto-sync enabled');
    print('   Sync interval: $syncInterval');
    print('   Debounce delay: $debounceDelay');
    print('   Auto-sync on reconnect: $autoSyncOnReconnect');
    print('   Min changes for sync: $minChangesForSync');

    // Get initial change log count
    _lastChangeLogCount = await _getChangeLogCount();

    // Start monitoring network connectivity
    if (autoSyncOnReconnect) {
      _startConnectivityMonitoring();
    }

    // Start periodic polling
    if (syncInterval.inSeconds > 0) {
      _startPeriodicSync();
    }

    // Check for changes immediately
    _checkAndSync();
  }

  /// Disable automatic syncing
  Future<void> disable() async {
    if (!_isEnabled) {
      return;
    }

    _isEnabled = false;
    print('🛑 Auto-sync disabled');

    _pollTimer?.cancel();
    _pollTimer = null;

    _debounceTimer?.cancel();
    _debounceTimer = null;

    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Check if auto-sync is enabled
  bool get isEnabled => _isEnabled;

  /// Check if currently syncing
  bool get isSyncing => _isSyncing;

  /// Stream of auto-sync events (for notifications)
  ///
  /// Emits events when sync starts, completes, or fails.
  Stream<AutoSyncEvent> get eventStream => _eventController.stream;

  /// Start monitoring network connectivity
  void _startConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      final isOnline = results.any(
        (result) => result != ConnectivityResult.none,
      );

      if (isOnline) {
        print('🌐 Network online - checking for pending changes...');
        final changeCount = await _getChangeLogCount();
        if (changeCount > 0) {
          print('   Found $changeCount pending changes, syncing...');
          await _performSync();
        } else {
          print('   No pending changes');
        }
      } else {
        print('📴 Network offline - changes will be queued');
      }
    });
  }

  /// Start periodic sync polling
  void _startPeriodicSync() {
    _pollTimer = Timer.periodic(syncInterval, (_) {
      if (_isEnabled && !_isSyncing) {
        _checkAndSync();
      }
    });
  }

  /// Check change log and sync if needed
  Future<void> _checkAndSync() async {
    if (!_isEnabled || _isSyncing) {
      return;
    }

    final currentCount = await _getChangeLogCount();

    if (currentCount == 0) {
      _lastChangeLogCount = 0;
      return;
    }

    // Check if we have new changes
    if (currentCount > _lastChangeLogCount) {
      final newChanges = currentCount - _lastChangeLogCount;
      print(
        '📝 Detected $newChanges new change(s) in log (total: $currentCount)',
      );

      if (newChanges >= minChangesForSync) {
        // Debounce: cancel previous timer and start new one
        _debounceTimer?.cancel();
        _debounceTimer = Timer(debounceDelay, () {
          _performSync();
        });
        print('   ⏳ Debouncing sync (${debounceDelay.inSeconds}s delay)...');
      }
    } else if (currentCount < _lastChangeLogCount) {
      // Change log was cleared (manual sync or successful auto-sync)
      _lastChangeLogCount = currentCount;
    }
  }

  /// Perform the actual sync
  Future<void> _performSync() async {
    if (_isSyncing) {
      print('⏸️ Sync already in progress, skipping...');
      return;
    }

    // Check if online
    final connectivityResults = await _connectivity.checkConnectivity();
    final isOnline = connectivityResults.any(
      (result) => result != ConnectivityResult.none,
    );

    if (!isOnline) {
      print('📴 Offline - skipping sync');
      return;
    }

    _isSyncing = true;
    print('🔄 Auto-sync starting...');
    _eventController.add(AutoSyncEvent.started());

    try {
      final result = await syncService.syncToServer();

      if (result.success) {
        print('✅ Auto-sync completed: ${result.processed} changes processed');
        _lastChangeLogCount = await _getChangeLogCount();
        _eventController.add(
          AutoSyncEvent.completed(
            processed: result.processed,
            errors: result.errors,
          ),
        );
      } else {
        print(
          '⚠️ Auto-sync partial: ${result.processed} succeeded, '
          '${result.errors} failed',
        );
        _eventController.add(
          AutoSyncEvent.partial(
            processed: result.processed,
            errors: result.errors,
            errorMessage: result.errorMessage,
          ),
        );
      }
    } catch (e) {
      print('❌ Auto-sync error: $e');
      _eventController.add(AutoSyncEvent.failed(error: e.toString()));
    } finally {
      _isSyncing = false;
    }
  }

  /// Get current change log count
  Future<int> _getChangeLogCount() async {
    try {
      final result =
          await db
              .customSelect('SELECT COUNT(*) as count FROM mtds_change_log')
              .get();
      if (result.isEmpty) return 0;
      return result.first.data['count'] as int? ?? 0;
    } catch (e) {
      print('❌ Error getting change log count: $e');
      return 0;
    }
  }

  /// Manually trigger a sync check (useful for testing)
  Future<void> triggerSync() async {
    if (!_isEnabled) {
      print('⚠️ Auto-sync not enabled, cannot trigger');
      return;
    }
    await _checkAndSync();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disable();
    await _eventController.close();
  }
}

/// Event types for auto-sync notifications
class AutoSyncEvent {
  final AutoSyncEventType type;
  final int? processed;
  final int? errors;
  final String? errorMessage;

  AutoSyncEvent({
    required this.type,
    this.processed,
    this.errors,
    this.errorMessage,
  });

  factory AutoSyncEvent.started() =>
      AutoSyncEvent(type: AutoSyncEventType.started);

  factory AutoSyncEvent.completed({
    required int processed,
    required int errors,
  }) => AutoSyncEvent(
    type: AutoSyncEventType.completed,
    processed: processed,
    errors: errors,
  );

  factory AutoSyncEvent.partial({
    required int processed,
    required int errors,
    String? errorMessage,
  }) => AutoSyncEvent(
    type: AutoSyncEventType.partial,
    processed: processed,
    errors: errors,
    errorMessage: errorMessage,
  );

  factory AutoSyncEvent.failed({required String error}) =>
      AutoSyncEvent(type: AutoSyncEventType.failed, errorMessage: error);
}

enum AutoSyncEventType { started, completed, partial, failed }
