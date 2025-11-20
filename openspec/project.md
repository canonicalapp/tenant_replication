# Project Context

## Purpose

**MTDS Flutter SDK** is an offline-first, multi-tenant data synchronization SDK for Flutter applications. The SDK automatically tracks database changes via SQL triggers, syncs to a server, and streams real-time updates via Server-Sent Events (SSE).

Key goals:

- Provide seamless offline-first data synchronization
- Support multi-tenant architectures
- Enable real-time bidirectional sync between client and server
- Handle conflict resolution using hybrid timestamps (client ordering + server authority)
- Support both soft deletes (syncs to server) and hard deletes (local only)

## Tech Stack

### Core Technologies

- **Dart**: ^3.7.0
- **Flutter**: >=1.17.0
- **Drift**: ^2.13.0 (Type-safe ORM for SQLite)
- **Dio**: ^5.9.0 (HTTP client for server communication)
- **SQLite**: Via `sqlite3_flutter_libs` and `sqflite`

### Key Dependencies

- `drift_dev`: ^2.29.0 (Code generation for Drift)
- `eventsource`: ^0.4.0 (Server-Sent Events support)
- `connectivity_plus`: ^6.1.3 (Network connectivity monitoring)
- `flutter_secure_storage`: ^9.2.4 (Secure storage for device metadata)
- `jwt_decoder`: ^2.0.1 (JWT token parsing)
- `crypto`: ^3.0.3 (Cryptographic utilities)

### Development Tools

- `flutter_lints`: ^5.0.0 (Dart/Flutter linting rules)
- `flutter_test`: SDK (Testing framework)

## Project Conventions

### Code Style

- **Linting**: Uses `flutter_lints` package (follows Dart style guide)
- **Naming Conventions**:
  - Classes: PascalCase (e.g., `MTDS_SDK`, `SyncService`, `SchemaManager`)
  - Methods/Variables: camelCase (e.g., `syncToServer()`, `deviceId`)
  - Constants: snake_case with leading underscore for private (e.g., `_metadataTable`, `_changeLogTable`)
  - Database tables/columns: snake_case (e.g., `mtds_change_log`, `mtds_last_updated_txid`)
- **Documentation**: Extensive use of Dart doc comments (`///`) for public APIs
- **File Organization**:
  - Main SDK class: `lib/src/mtds_sdk.dart`
  - Services: `lib/src/sync/` directory
  - Database utilities: `lib/src/database/` directory
  - Models: `lib/src/models/` directory
  - Helpers/Utils: `lib/src/helpers/` and `lib/src/utils/` directories

### Architecture Patterns

- **Service-Based Architecture**: Core functionality split into focused service classes:
  - `SyncService`: Handles uploading local changes to server
  - `SSEService`: Manages Server-Sent Events connection and real-time updates
  - `DeleteService`: Handles soft and hard delete operations
  - `AutoSyncService`: Manages automatic synchronization with debouncing
- **Manager Pattern**: Static utility classes for database operations:
  - `SchemaManager`: Manages MTDS metadata tables and schema preparation
  - `TriggerManager`: Sets up SQL triggers for change tracking
- **Mixin Pattern**: `MtdsColumns` mixin for adding required MTDS columns to Drift tables
- **Offline-First**: All operations work locally first, then sync to server
- **Event-Driven**: Uses streams for SSE updates and auto-sync events
- **Dependency Injection**: Services receive dependencies (database, HTTP client) via constructor

### Testing Strategy

- **Example Application**: Comprehensive example app in `example/` directory for end-to-end testing
- **Test Framework**: Uses `flutter_test` for unit and widget tests
- **Testing Approach**:
  - Example app serves as integration test environment
  - Tests against local PostgreSQL server (see `docs/TESTING_GUIDE.md`)
  - Manual testing via Flutter app UI
  - Server-side testing with companion PostgreSQL library
- **Test Structure**:
  - Example app includes test screen (`example/lib/screens/test_screen.dart`)
  - Activity logging for debugging (`example/lib/utils/activity_logger.dart`)
  - JWT helper for authentication testing (`example/lib/utils/jwt_helper.dart`)

### Git Workflow

- **Versioning**: Semantic Versioning (SemVer) - see `CHANGELOG.md`
- **Changelog**: Follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format
- **Branching**: Feature branches (e.g., `feat/improvements` as seen in git status)
- **Repository**: `https://github.com/canons-dev/tenant_replication.git`
- **License**: MIT © Canons Dev Team

## Domain Context

### Multi-Tenant Data Synchronization (MTDS)

The SDK is designed for applications that need to:

- Sync data between multiple devices/users
- Handle offline scenarios gracefully
- Support multi-tenant architectures (data isolation per tenant)
- Resolve conflicts when multiple devices modify the same data

### Key Concepts

- **Transaction IDs (TXID)**: Hybrid timestamps combining client ordering and server authority
  - `mtds_last_updated_txid`: Tracks when a record was last updated
  - `mtds_deleted_txid`: Marks soft-deleted records
- **Device ID**: Unique 48-bit identifier for each device/client
- **Change Log**: SQLite table (`mtds_change_log`) that tracks all database changes via triggers
- **Soft Delete**: Mark record as deleted (sets `mtds_deleted_txid`) but keeps data for sync
- **Hard Delete**: Permanently remove record from local database (no sync)
- **Last Write Wins (LWW)**: Conflict resolution strategy based on transaction IDs

### Database Schema Requirements

Every replicated table must include:

- `mtds_last_updated_txid` (INTEGER, NOT NULL, default 0)
- `mtds_device_id` (INTEGER, NOT NULL, default 0)
- `mtds_deleted_txid` (INTEGER, nullable)

These are automatically added via the `MtdsColumns` mixin.

## Important Constraints

### Technical Constraints

- **Drift ORM Required**: Consumer applications must use Drift for database management
- **SQLite Only**: Currently supports SQLite databases only
- **Authentication**: SDK does NOT handle authentication - consumers must configure Dio interceptors
- **Server Endpoints**: Requires specific server endpoints (see `docs/SERVER_REQUIREMENTS.md`):
  - `POST /mtdd/sync/changes` - Upload local changes
  - `POST /mtdd/sync/bulk-load` - Load data from server
  - `GET /mtdd/sync/events` - Server-Sent Events stream
- **Device ID**: Must be a unique 48-bit integer per device
- **Schema Alignment**: Server may return additional columns that are automatically filtered
- **Migration Required**: Consumer databases must call `SchemaManager.prepareDatabase()` after migrations

### Business Constraints

- **Offline-First**: All operations must work without network connectivity
- **Multi-Tenant**: Designed for applications with tenant isolation requirements
- **Real-Time Sync**: Supports real-time updates but requires SSE-capable server

## External Dependencies

### Server Requirements

The SDK requires a compatible MTDS server that implements:

- Change upload endpoint (`POST /mtdd/sync/changes`)
- Bulk load endpoint (`POST /mtdd/sync/bulk-load`)
- SSE event stream (`GET /mtdd/sync/events`)
- Support for hybrid timestamps (TXID system)
- Multi-tenant data isolation

See `docs/SERVER_REQUIREMENTS.md` for detailed API specifications.

### Peer Dependencies

Consumers must provide:

- **Drift**: ^2.13.0 (with code generation)
- **Dio**: ^5.9.0 (configured with authentication interceptors)
- **sqlite3_flutter_libs**: ^0.5.19 (for SQLite support)

### Related Projects

- **Server Implementation**: Companion PostgreSQL server library (referenced in testing docs)
- **Example App**: Complete working example in `example/` directory
