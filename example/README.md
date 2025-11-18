# MTDS SDK Example App

Complete working example demonstrating the MTDS Flutter SDK with real-time synchronization, automatic syncing, and end-to-end server integration.

## 🚀 Quick Start

### Prerequisites

- Flutter SDK installed
- Server running (see [Server Setup](#server-setup))
- SQLite development libraries (for migration tests): `sudo apt install libsqlite3-dev`

### Setup

```bash
cd example
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d linux
```

### Server Setup

1. **Start the server** (from `tenant_replication_postgres/examples/example-app`):
   ```bash
   npm install
   npm run setup:db  # Creates database and tables
   npm run dev        # Starts server on http://localhost:3000
   ```

2. **Configure the example app**:
   - Edit `lib/services/sdk_service.dart` to set your server URL
   - The app uses JWT authentication (see `lib/utils/jwt_helper.dart`)

## 📱 Features Demonstrated

- ✅ **Database Setup** - Drift tables with `MtdsColumns` mixin
- ✅ **SDK Initialization** - Complete setup with authentication
- ✅ **CRUD Operations** - Create, update, soft delete, hard delete
- ✅ **Manual Sync** - Sync changes to server on demand
- ✅ **Bulk Load** - Load data from server
- ✅ **Real-Time Updates** - SSE connection with live updates
- ✅ **Automatic Sync** - Auto-sync with notifications
- ✅ **Change Log** - View pending changes
- ✅ **Status Monitoring** - Connection status, pending changes, last sync time

## 🏗️ Project Structure

```
example/
├── lib/
│   ├── database.dart              # Drift schema + migrations
│   ├── main.dart                  # App entry point
│   ├── screens/
│   │   └── test_screen.dart       # Main UI with SDK operations
│   ├── services/
│   │   └── sdk_service.dart       # SDK initialization
│   ├── utils/
│   │   ├── jwt_helper.dart        # JWT token generation
│   │   └── activity_logger.dart   # Activity logging
│   └── widgets/                   # Reusable UI components
└── pubspec.yaml
```

## 🔧 Configuration

### Server URL

Edit `lib/services/sdk_service.dart`:

```dart
const String serverUrl = 'http://localhost:3000';
```

### Authentication

The example app generates test JWT tokens automatically. For production:

1. Replace `JwtHelper.generateTestToken()` with your auth service
2. Configure Dio interceptors in `lib/screens/test_screen.dart`

### Device ID

Set a unique 48-bit device ID in `lib/services/sdk_service.dart`:

```dart
const int deviceId = 12345; // Change to unique value per device
```

## 🧪 Testing Workflow

### 1. Start Server

```bash
cd ../../tenant_replication_postgres/examples/example-app
npm run dev
```

### 2. Run Example App

```bash
cd example
flutter run -d linux
```

### 3. Test Operations

1. **Create User** - Click "➕ Add User"
   - Verifies local insert
   - Triggers change log entry
   - Auto-sync will sync after 5 seconds (if enabled)

2. **Update User** - Click "✏️ Update" on any user
   - Updates `mtds_last_updated_txid`
   - Creates change log entry

3. **Soft Delete** - Click "🗑️ Soft Delete"
   - Sets `mtds_deleted_txid`
   - Syncs to server

4. **Hard Delete** - Click "🗑️ Hard Delete"
   - Permanently removes from local DB
   - Does NOT sync to server

5. **Manual Sync** - Click "🔄 Sync to Server"
   - Uploads all pending changes
   - Shows notification on completion

6. **Load from Server** - Click "📥 Load from Server"
   - Fetches latest data from server
   - Upserts into local database
   - Filters server-only columns automatically

7. **SSE Connection** - Automatically connects on startup
   - Shows connection status in UI
   - Receives real-time updates from server

## 📊 UI Components

- **Status Card** - SDK initialization status
- **SDK Information** - Device ID, server URL, connection status
- **Users List** - Display all users with actions
- **Change Log** - View pending changes
- **Triggers** - View SQL triggers
- **Sync Buttons** - Manual sync and load operations
- **Activity Log** - Real-time operation logs

## 🔄 Automatic Synchronization

The example app enables auto-sync by default:

```dart
await sdk.enableAutoSync(
  syncInterval: Duration(seconds: 30),
  debounceDelay: Duration(seconds: 5),
  autoSyncOnReconnect: true,
);
```

**Features:**
- Syncs when changes are detected (5s debounce)
- Syncs when network comes back online
- Shows notifications for sync events
- Logs all sync operations

## 🐛 Troubleshooting

### Database Issues

```bash
# Reset database
rm -f ~/Documents/client_test_db.sqlite
flutter run -d linux
```

### Build Issues

```bash
# Clean and rebuild
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Server Connection Issues

1. Verify server is running: `curl http://localhost:3000/health`
2. Check JWT token generation in logs
3. Verify server URL in `sdk_service.dart`
4. Check authentication headers in Dio interceptors

### Migration Test Failures

```bash
# Install SQLite dev libraries
sudo apt install libsqlite3-dev
```

## 📚 Related Documentation

- [Main SDK README](../README.md) - Complete SDK documentation
- [Schema Alignment](../docs/SCHEMA_ALIGNMENT.md) - Client/server schema differences
- [Server Requirements](../docs/SERVER_REQUIREMENTS.md) - API specifications

## ✅ Status

- ✅ Build: Working
- ✅ Drift Schema: v9 with auto-migrations
- ✅ Triggers: Auto-generated at runtime
- ✅ Change Log: Populated on every operation
- ✅ Sync: Manual and automatic
- ✅ SSE: Real-time updates
- ✅ Ready for: End-to-end testing with server
