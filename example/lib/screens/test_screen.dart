import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:mtds/index.dart';
import 'package:mtds/src/sync/auto_sync_service.dart';
import '../database.dart';
import '../services/sdk_service.dart';
import '../utils/activity_logger.dart';
import '../utils/jwt_helper.dart';
import '../widgets/status_card.dart';
import '../widgets/section_container.dart';
import '../widgets/info_row.dart';
import '../widgets/sync_buttons.dart';
import '../widgets/user_card.dart';
import '../widgets/change_log_card.dart';
import '../widgets/trigger_card.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  late AppDatabase driftDb;
  MTDS_SDK? sdk;

  List<User> users = [];
  List<Map<String, Object?>> changeLogs = [];
  List<Map<String, dynamic>> triggers = [];
  final ActivityLogger activityLogger = ActivityLogger();

  bool isInitialized = false;
  bool isLoading = false;
  String statusMessage = '';
  bool isSyncing = false;
  bool isSSEConnected = false;
  bool isAutoSyncEnabled = false;
  bool isAutoSyncing = false;
  DateTime? lastSyncTime;
  int pendingChangesCount = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() {
        isLoading = true;
        statusMessage = 'Initializing database...';
      });

      // Initialize Drift database
      print('📂 Initializing Drift database...');
      driftDb = AppDatabase();

      // Force Drift to create the database and run migrations
      print('🔨 Creating database schema...');
      await driftDb.customSelect('SELECT 1').get();
      print('✅ Database schema created');

      // Prepare MTDS metadata (change log + triggers)
      print('🔧 Preparing MTDS metadata...');
      await SchemaManager.prepareDatabase(driftDb);

      // Configure Dio with auth interceptors (consumer's responsibility)
      print('🔧 Configuring HTTP client with auth...');

      // Generate test JWT token with tenant-id and user-id claims
      // In production, obtain this token from your authentication server
      //
      // IMPORTANT: The server must use the same secret key ('test-secret-key') to validate this token.
      // If your server uses a different secret, update the secretKey parameter or configure
      // your server to accept 'test-secret-key' for testing.
      final jwtToken = JwtHelper.generateTestToken(
        tenantId: 'test-tenant',
        userId: 'test-user',
        expirationMinutes: 60,
        secretKey: 'test-secret-key', // Must match server's JWT secret
      );
      print('✅ Generated test JWT token');
      print(
        '   ⚠️  Server must use secret key: "test-secret-key" to validate this token',
      );

      // Decode and log token claims for debugging
      final claims = JwtHelper.decodeToken(jwtToken);
      if (claims != null) {
        print('📋 JWT Claims:');
        print('   tenant-id: ${claims['tenant-id']}');
        print('   user-id: ${claims['user-id']}');
        print(
          '   exp: ${claims['exp']} (expires in ${((claims['exp'] as int) - DateTime.now().millisecondsSinceEpoch ~/ 1000) ~/ 60} minutes)',
        );
      } else {
        print('⚠️  Failed to decode JWT token - this should not happen');
      }

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            // Consumer provides auth token - server extracts tenant-id and user-id from JWT
            options.headers['Authorization'] = 'Bearer $jwtToken';
            // Temporary headers for sync endpoints (some endpoints may accept these directly)
            options.headers['tenant-id'] = 'test-tenant';
            options.headers['user-id'] = 'test-user';
            // Debug: Log headers for SSE requests
            if (options.uri.path.contains('/sync/events')) {
              print('📤 SSE Request Configuration:');
              print('   URL: ${options.uri}');
              print('   Method: ${options.method}');
              print('   Headers: ${options.headers.keys.join(', ')}');
              final authHeader = options.headers['Authorization'] as String?;
              if (authHeader != null && authHeader.startsWith('Bearer ')) {
                final token = authHeader.substring(7);
                print(
                  '   JWT Token (preview): ${token.substring(0, token.length > 30 ? 30 : token.length)}...',
                );
                print('   JWT Token length: ${token.length} characters');
              }
            }
            return handler.next(options);
          },
          onError: (error, handler) {
            // Log errors for debugging
            if (error.requestOptions.uri.path.contains('/sync/events')) {
              print('❌ SSE Request Error:');
              print('   Status: ${error.response?.statusCode}');
              print('   Message: ${error.message}');
            }
            return handler.next(error);
          },
        ),
      );

      // Initialize SDK with consumer-configured Dio instance
      print('🔧 Initializing SDK...');
      sdk = await SdkService.initializeSdk(driftDb, dio);
      print('✅ SDK initialized');

      setState(() {
        isInitialized = true;
        isLoading = false;
        statusMessage = '✅ SDK initialized successfully!';
      });

      await _refreshData();
      await _subscribeToSSE();
      await _updatePendingChangesCount();
      await _enableAutoSync();
      activityLogger.add('✅ SDK initialized and ready');
    } catch (e, stackTrace) {
      print('❌ Initialization error: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        isLoading = false;
        statusMessage = '❌ Error: $e';
      });
      activityLogger.add('❌ Initialization failed: $e');
    }
  }

  void _addActivityLog(String message) {
    activityLogger.add(message);
    setState(() {});
  }

  Future<void> _subscribeToSSE() async {
    try {
      // Subscribe to connection state changes
      sdk!.sseConnectionStateStream.listen((connected) {
        setState(() {
          isSSEConnected = connected;
        });
        _addActivityLog(connected ? '✅ SSE connected' : '❌ SSE disconnected');
      });

      // Subscribe to SSE events
      final stream = sdk!.subscribeToSSE();
      stream.listen(
        (event) {
          _addActivityLog(
            '📨 SSE: ${event.type.name} on ${event.table ?? 'unknown'}',
          );
          _refreshData();
        },
        onError: (error) {
          _addActivityLog('❌ SSE error: $error');
        },
      );

      // Set initial state
      setState(() {
        isSSEConnected = sdk!.isSSEConnected;
      });
      _addActivityLog('🔌 SSE subscription started');
    } catch (e) {
      _addActivityLog('❌ Failed to subscribe to SSE: $e');
    }
  }

  Future<void> _updatePendingChangesCount() async {
    try {
      final count =
          await driftDb
              .customSelect('SELECT COUNT(*) as count FROM mtds_change_log')
              .get();
      setState(() {
        pendingChangesCount =
            count.isNotEmpty ? (count.first.data['count'] as int? ?? 0) : 0;
      });
    } catch (e) {
      print('Error counting pending changes: $e');
    }
  }

  Future<void> _enableAutoSync() async {
    if (sdk == null) return;

    try {
      print('🔄 Enabling auto-sync...');
      await sdk!.enableAutoSync(
        syncInterval: const Duration(seconds: 30),
        debounceDelay: const Duration(seconds: 5),
        autoSyncOnReconnect: true,
        minChangesForSync: 1,
      );

      setState(() {
        isAutoSyncEnabled = true;
      });

      // Listen to auto-sync events for notifications
      sdk!.autoSyncEventStream.listen((event) {
        _handleAutoSyncEvent(event);
      });

      _addActivityLog('✅ Auto-sync enabled');
      print('✅ Auto-sync enabled');
    } catch (e) {
      print('❌ Failed to enable auto-sync: $e');
      _addActivityLog('❌ Failed to enable auto-sync: $e');
    }
  }

  void _handleAutoSyncEvent(AutoSyncEvent event) {
    if (!mounted) return;

    final context = this.context;
    String message;
    Color backgroundColor;

    switch (event.type) {
      case AutoSyncEventType.started:
        message = '🔄 Auto-sync started...';
        backgroundColor = Colors.blue;
        setState(() {
          isAutoSyncing = true;
        });
        break;
      case AutoSyncEventType.completed:
        message = '✅ Auto-sync completed: ${event.processed} changes processed';
        backgroundColor = Colors.green;
        setState(() {
          isAutoSyncing = false;
          lastSyncTime = DateTime.now();
        });
        _updatePendingChangesCount();
        _refreshData();
        break;
      case AutoSyncEventType.partial:
        message =
            '⚠️ Auto-sync partial: ${event.processed} succeeded, ${event.errors} failed';
        backgroundColor = Colors.orange;
        setState(() {
          isAutoSyncing = false;
        });
        _updatePendingChangesCount();
        break;
      case AutoSyncEventType.failed:
        message =
            '❌ Auto-sync failed: ${event.errorMessage ?? 'Unknown error'}';
        backgroundColor = Colors.red;
        setState(() {
          isAutoSyncing = false;
        });
        break;
    }

    // Show notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );

    // Log to activity logger
    _addActivityLog(message);
    print('📢 Auto-sync event: $message');
  }

  Future<void> _refreshData() async {
    try {
      // Fetch users
      print('📊 Fetching users...');
      final usersList = await driftDb.select(driftDb.users).get();
      print('✅ Found ${usersList.length} users');

      // Fetch change logs using custom query
      print('📊 Fetching change logs...');
      final logs = await driftDb.getChangeLogs();
      print('✅ Found ${logs.length} change logs');

      // Fetch triggers using Drift
      print('📊 Fetching triggers...');
      final triggersResult =
          await driftDb.customSelect('''
        SELECT name, sql 
        FROM sqlite_master 
        WHERE type = 'trigger' 
        ORDER BY name
      ''').get();
      final triggersList = triggersResult.map((row) => row.data).toList();
      print('✅ Found ${triggersList.length} triggers');

      setState(() {
        users = usersList;
        changeLogs = logs;
        triggers = triggersList;
      });
      await _updatePendingChangesCount();
    } catch (e, stackTrace) {
      print('❌ Error refreshing data: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        statusMessage = '❌ Error refreshing data: $e';
      });
    }
  }

  Future<void> _addUser() async {
    try {
      print('🆕 Starting to add user...');
      final txid = MtdsUtils.generateTxid();
      print('   Generated TXID: $txid');

      final deviceId = sdk!.deviceId;
      print('   Using DeviceID: $deviceId');

      final randomName = 'User ${DateTime.now().millisecond}';
      print('   Creating user: $randomName');

      await driftDb
          .into(driftDb.users)
          .insert(
            UsersCompanion.insert(
              name: randomName,
              email: '$randomName@example.com',
              age: Value(25),
              mtdsLastUpdatedTxid: Value(txid),
              mtdsDeviceId: Value(deviceId),
            ),
          );

      print('✅ User inserted successfully!');

      setState(() {
        statusMessage = '✅ User added: $randomName';
      });

      _addActivityLog('➕ Created user: $randomName');
      await _refreshData();
    } catch (e, stackTrace) {
      print('❌❌❌ ERROR ADDING USER ❌❌❌');
      print('Error: $e');
      print('Stack trace:');
      print(stackTrace);
      print('❌❌❌ END ERROR ❌❌❌');

      setState(() {
        statusMessage = '❌ Error adding user: $e';
      });
    }
  }

  Future<void> _updateUser(int userId) async {
    try {
      final txid = MtdsUtils.generateTxid();
      final deviceId = sdk!.deviceId;

      await (driftDb.update(driftDb.users)
        ..where((t) => t.id.equals(userId))).write(
        UsersCompanion(
          name: Value('Updated ${DateTime.now().millisecond}'),
          mtdsLastUpdatedTxid: Value(txid),
          mtdsDeviceId: Value(deviceId),
        ),
      );

      setState(() {
        statusMessage = '✅ User updated: ID $userId';
      });

      _addActivityLog('✏️ Updated user: ID $userId');
      await _refreshData();
    } catch (e) {
      setState(() {
        statusMessage = '❌ Error updating user: $e';
      });
    }
  }

  Future<void> _softDeleteUser(int userId) async {
    try {
      await sdk!.softDelete(
        tableName: 'users',
        primaryKeyColumn: 'id',
        primaryKeyValue: userId,
      );

      setState(() {
        statusMessage = '✅ User soft-deleted: ID $userId';
      });

      _addActivityLog('🗑️ Soft-deleted user: ID $userId');
      await _refreshData();
    } catch (e) {
      setState(() {
        statusMessage = '❌ Error soft deleting: $e';
      });
    }
  }

  Future<void> _hardDeleteUser(int userId) async {
    try {
      await sdk!.hardDelete(
        tableName: 'users',
        primaryKeyColumn: 'id',
        primaryKeyValue: userId,
      );

      setState(() {
        statusMessage = '✅ User hard-deleted: ID $userId';
      });

      _addActivityLog('💥 Hard-deleted user: ID $userId');
      await _refreshData();
    } catch (e) {
      setState(() {
        statusMessage = '❌ Error hard deleting: $e';
      });
    }
  }

  Future<void> _clearChangeLogs() async {
    try {
      await driftDb.clearChangeLogs();

      setState(() {
        statusMessage = '✅ Change logs cleared';
      });

      _addActivityLog('🧹 Cleared change logs');
      await _refreshData();
    } catch (e) {
      setState(() {
        statusMessage = '❌ Error clearing logs: $e';
      });
    }
  }

  Future<void> _syncToServer() async {
    if (sdk == null || isSyncing) return;

    setState(() {
      isSyncing = true;
      statusMessage = '🔄 Syncing to server...';
    });

    _addActivityLog('🔄 Starting sync to server...');

    try {
      final result = await sdk!.syncToServer();

      setState(() {
        isSyncing = false;
        lastSyncTime = DateTime.now();
        statusMessage =
            result.success
                ? '✅ Sync complete: ${result.processed} changes'
                : '❌ Sync failed: ${result.errorMessage ?? 'Unknown error'}';
      });

      if (result.success) {
        _addActivityLog(
          '✅ Sync successful: ${result.processed} changes processed',
        );
      } else {
        _addActivityLog(
          '❌ Sync failed: ${result.errorMessage ?? 'Unknown error'}',
        );
      }

      await _refreshData();
    } catch (e) {
      setState(() {
        isSyncing = false;
        statusMessage = '❌ Sync error: $e';
      });
      final message = '❌ Sync error: $e';
      _addActivityLog(message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadFromServer() async {
    if (sdk == null || isSyncing) return;

    setState(() {
      isSyncing = true;
      statusMessage = '🔄 Loading from server...';
    });

    _addActivityLog('🔄 Loading data from server...');

    try {
      await sdk!.loadFromServer(tableNames: ['users', 'products']);

      final message = '✅ Data loaded from server';
      setState(() {
        isSyncing = false;
        statusMessage = message;
      });

      _addActivityLog(message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      await _refreshData();
    } catch (e) {
      final message = '❌ Load error: $e';
      setState(() {
        isSyncing = false;
        statusMessage = message;
      });
      _addActivityLog(message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    driftDb.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MTDS SDK Client Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : !isInitialized
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(statusMessage),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card
                    StatusCard(message: statusMessage),
                    const SizedBox(height: 16),

                    // SDK Info
                    SectionContainer(
                      title: 'SDK Information',
                      icon: Icons.info_outline,
                      children: [
                        InfoRow(
                          label: 'Device ID',
                          value: sdk!.deviceId.toString(),
                        ),
                        InfoRow(
                          label: 'Server URL',
                          value: 'http://localhost:3000',
                        ),
                        InfoRow(
                          label: 'SSE Status',
                          value:
                              isSSEConnected
                                  ? '🟢 Connected'
                                  : '🔴 Disconnected',
                        ),
                        InfoRow(
                          label: 'Auto-Sync',
                          value:
                              isAutoSyncEnabled
                                  ? (isAutoSyncing
                                      ? '🔄 Syncing...'
                                      : '🟢 Enabled')
                                  : '🔴 Disabled',
                        ),
                        InfoRow(
                          label: 'Pending Changes',
                          value: pendingChangesCount.toString(),
                        ),
                        if (lastSyncTime != null)
                          InfoRow(
                            label: 'Last Sync',
                            value: lastSyncTime!.toString().substring(11, 19),
                          ),
                      ],
                    ),

                    // Sync Actions
                    SectionContainer(
                      title: 'Sync Operations',
                      icon: Icons.sync,
                      children: [
                        SyncButtons(
                          isSyncing: isSyncing,
                          onSyncToServer: _syncToServer,
                          onLoadFromServer: _loadFromServer,
                        ),
                      ],
                    ),

                    // Local Actions
                    SectionContainer(
                      title: 'Local Actions',
                      icon: Icons.touch_app,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _addUser,
                          icon: const Icon(Icons.add),
                          label: const Text('Add User'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _refreshData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Data'),
                        ),
                      ],
                    ),

                    // Users Table
                    SectionContainer(
                      title: 'Users (${users.length})',
                      icon: Icons.people,
                      children: [
                        if (users.isEmpty)
                          const Text('No users yet. Add one!')
                        else
                          ...users.map(
                            (user) => UserCard(
                              user: user,
                              onUpdate: () => _updateUser(user.id),
                              onSoftDelete: () => _softDeleteUser(user.id),
                              onHardDelete: () => _hardDeleteUser(user.id),
                            ),
                          ),
                      ],
                    ),

                    // Change Log
                    SectionContainer(
                      title: 'Change Log (${changeLogs.length})',
                      icon: Icons.list_alt,
                      children: [
                        if (changeLogs.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: _clearChangeLogs,
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Clear Logs'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (changeLogs.isEmpty)
                          const Text('No changes logged yet')
                        else
                          ...changeLogs.map((log) => ChangeLogCard(log: log)),
                      ],
                    ),

                    // Triggers
                    SectionContainer(
                      title: 'Triggers (${triggers.length})',
                      icon: Icons.flash_on,
                      children: [
                        if (triggers.isEmpty)
                          const Text('No triggers found')
                        else
                          ...triggers.map(
                            (trigger) => TriggerCard(trigger: trigger),
                          ),
                      ],
                    ),

                    // Activity Log
                    SectionContainer(
                      title: 'Activity Log (${activityLogger.count})',
                      icon: Icons.history,
                      children: [
                        if (activityLogger.logs.isEmpty)
                          const Text('No activity yet')
                        else
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.builder(
                              reverse: false,
                              itemCount: activityLogger.logs.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    activityLogger.logs[index],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }
}
