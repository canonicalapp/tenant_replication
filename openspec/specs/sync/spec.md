## Purpose

The synchronization service provides bidirectional data synchronization between client and server using GraphQL operations, with support for offline-first scenarios, initial sync, and real-time updates.

## Requirements

### Requirement: Drift ORM Usage

The SDK SHALL use Drift ORM as the primary method for all database queries in the sync service to ensure type safety and consistency.

Sync service database operations SHALL:

- Use Drift ORM methods as the default for querying user tables and `mtds_state` table
- Use Drift's type-safe query builders for SELECT, INSERT, UPDATE operations
- Use Drift's `INSERT OR REPLACE` semantics for idempotent updates
- Use raw SQL queries only when Drift ORM cannot be used effectively (e.g., MAX() aggregations with complex conditions, performance limitations, or unsupported operations)
- Ensure all queries are type-safe where possible and benefit from compile-time checking

### Requirement: Synchronization Service

The SDK SHALL provide a synchronization service that uploads local changes to the server and receives updates using GraphQL operations.

The service SHALL:

- Use GraphQL mutations to upload local changes
- Use GraphQL queries to load data from server
- Use GraphQL subscriptions for real-time updates
- Handle all operations idempotently
- Support initial sync on app start with table timestamps
- Cache MAX timestamp values to avoid repeated queries

#### Scenario: Upload local changes via GraphQL

- **WHEN** local changes exist in the change log
- **THEN** the service SHALL send changes to server via GraphQL mutation
- **AND** changes SHALL include `mtds_client_ts` from local records
- **AND** the server SHALL return server-assigned `mtds_server_ts` values
- **AND** local records SHALL be updated with `mtds_server_ts` values

#### Scenario: Initial sync on app start (SyncAllTables)

- **WHEN** the app starts or comes online
- **THEN** the service SHALL send a `SyncAllTables` request to server
- **AND** for each table, retrieve MAX(mtds_server_ts) from `mtds_state` table using Drift ORM WHERE Attribute = 'table:' + tableName
- **AND** if no value exists in state table, query MAX(mtds_server_ts) from the user table using Drift ORM and store it in state table
- **AND** send table names with max timestamps to server via GraphQL mutation
- **AND** server SHALL check Redis cache to see if changes exist since last sync
- **AND** if no changes in cache, server may query actual tables for the tenant
- **AND** receive all updates where `mtds_server_ts > requested_timestamp`
- **AND** the service SHALL check `mtds_device_id` for each received record
- **AND** if `mtds_device_id` matches current device, the record SHALL be skipped (prevent loops)
- **AND** if `mtds_device_id` differs, the record SHALL be applied to local database idempotently
- **AND** update local records with server-assigned `mtds_server_ts` values
- **AND** update state table with new MAX(mtds_server_ts) per table after sync completes

#### Scenario: Debounce repeated offline/online transitions

- **WHEN** the app goes offline and online repeatedly
- **THEN** initial sync SHALL be debounced to avoid excessive requests
- **AND** only the last online transition SHALL trigger sync

#### Scenario: Load data from server via GraphQL

- **WHEN** `loadFromServer()` is called with table names
- **THEN** the service SHALL query server via GraphQL query
- **AND** receive table data with `mtds_server_ts` values
- **AND** the service SHALL check `mtds_device_id` for each record
- **AND** if `mtds_device_id` matches current device, the record SHALL be skipped (prevent loops)
- **AND** if `mtds_device_id` differs, the record SHALL be upserted into local database
- **AND** preserve `mtds_client_ts` if record exists locally
- **AND** update `mtds_server_ts` with server value

#### Scenario: Real-time updates via GraphQL subscription

- **WHEN** subscription is established
- **THEN** the service SHALL receive real-time updates via GraphQL subscription
- **AND** updates SHALL include `mtds_server_ts` from server
- **AND** the service SHALL check if `mtds_device_id` matches current device
- **AND** if device ID matches, the update SHALL be ignored (prevent loops)
- **AND** if device ID differs, the update SHALL be applied with `mtds_server_ts`

### Requirement: Initial Sync Operation (SyncAllTables)

The SDK SHALL automatically perform initial sync when the app starts or comes online using `SyncAllTables` request.

Initial sync SHALL:

- Send `SyncAllTables` request to server with table names and MAX(mtds_server_ts) per table
- Retrieve MAX timestamps from `mtds_state` table using Drift ORM (Attribute = 'table:' + tableName)
- If timestamp doesn't exist in state table, query MAX(mtds_server_ts) from the user table using Drift ORM and store it
- Server SHALL check Redis cache to see if changes exist since last sync
- If no changes in cache, server may query actual tables for the tenant
- Receive all updates where `mtds_server_ts > requested_timestamp`
- Apply updates to local database idempotently
- Update local records with server-assigned `mtds_server_ts` values
- Update state table with new MAX(mtds_server_ts) per table after sync completes
- Be idempotent (safe to call multiple times)

#### Scenario: Initial sync on app start

- **WHEN** the SDK is initialized
- **THEN** initial sync SHALL be triggered automatically via `SyncAllTables` request
- **AND** for each table, MAX timestamp SHALL be retrieved from `mtds_state` (Attribute = 'table:' + tableName)
- **AND** if timestamp doesn't exist, it SHALL be queried from database and stored in state table
- **AND** updates SHALL be fetched and applied
- **AND** state table SHALL be updated with new MAX timestamps after sync

#### Scenario: Initial sync on network reconnect

- **WHEN** network connectivity is restored
- **AND** there are pending changes or app was offline
- **THEN** initial sync SHALL be triggered via `SyncAllTables` request
- **AND** MAX timestamps SHALL be retrieved from state table
- **AND** updates since last sync SHALL be fetched
- **AND** state table SHALL be updated with new MAX timestamps after sync

### Requirement: MAX Timestamp Storage in State Table

The SDK SHALL store the maximum `mtds_server_ts` value per table in `mtds_state` table.

Timestamp storage SHALL:

- Store MAX timestamp per table as `'table:' + tableName` attribute in state table
- Use numValue column to store the BIGINT timestamp
- Update state table when records are synced from server
- Use stored values for initial sync queries
- Query database only if timestamp doesn't exist in state table

#### Scenario: Store MAX timestamp in state table

- **WHEN** sync completes for a table
- **THEN** the MAX(mtds_server_ts) value SHALL be stored in `mtds_state` with Attribute `'table:' + tableName`
- **AND** the value SHALL be stored in numValue column
- **AND** this value SHALL be used for subsequent sync requests

#### Scenario: Retrieve MAX timestamp from state table

- **WHEN** initial sync is performed
- **THEN** the SDK SHALL use Drift ORM to query the `mtds_state` table WHERE Attribute = 'table:' + tableName
- **AND** if value exists, it SHALL be used as the last known MAX(mtds_server_ts)
- **AND** if value doesn't exist, database SHALL be queried and value SHALL be stored in state table

### Requirement: Soft Delete Hard Delete on Sync Back

When a soft-deleted record is received from the server (indicating server confirmed the delete), the client SHALL perform a hard delete locally.

#### Scenario: Soft delete confirmation from server

- **WHEN** a soft-deleted record is received from server via sync
- **AND** the record has `mtds_delete_ts` set
- **AND** the record's `mtds_server_ts` is present
- **THEN** the client SHALL perform a hard delete (permanent removal)
- **AND** the record SHALL be removed from the local database
- **AND** other devices receiving the same update SHALL also remove the record

### Requirement: Infinite Loop Prevention

The SDK SHALL implement multiple safeguards to prevent infinite synchronization loops.

#### Scenario: Device ID filtering prevents trigger loops

- **WHEN** server updates are received via sync or subscription
- **THEN** the service SHALL check `mtds_device_id` before applying updates
- **AND** if `mtds_device_id` matches current device, the update SHALL be skipped
- **AND** triggers SHALL NOT fire for updates from other devices (device_id mismatch)
- **AND** triggers SHALL NOT fire for updates from same device (skipped before database write)

#### Scenario: Change tracking prevents re-logging

- **WHEN** a local change is sent to server
- **THEN** the change SHALL be marked as "sent" in change log
- **AND** when server confirms the change (returns `mtds_server_ts`)
- **AND** the change is received back via sync
- **THEN** the service SHALL recognize it as a confirmation (not a new change)
- **AND** the change SHALL be applied without triggering change log entry
- **AND** only `mtds_server_ts` SHALL be updated

#### Scenario: Sync operation timeout

- **WHEN** a sync operation is in progress
- **THEN** the operation SHALL have a maximum timeout (default: 30 seconds)
- **AND** if timeout is exceeded, the operation SHALL be cancelled
- **AND** an error SHALL be logged
- **AND** the service SHALL enter a cooldown period (default: 5 seconds) before retrying

#### Scenario: Sync rate limiting

- **WHEN** sync operations are triggered
- **THEN** the service SHALL limit sync frequency (maximum: 1 sync per 2 seconds)
- **AND** rapid sync requests SHALL be debounced
- **AND** if more than 10 sync operations occur within 1 minute, the service SHALL enter circuit breaker mode
- **AND** circuit breaker mode SHALL pause sync for 30 seconds before allowing new syncs

#### Scenario: Change log size monitoring

- **WHEN** change log entries are created
- **THEN** the service SHALL monitor change log size
- **AND** if change log exceeds 1000 entries, the service SHALL trigger immediate sync
- **AND** if change log exceeds 5000 entries, the service SHALL log a warning
- **AND** if change log exceeds 10000 entries, the service SHALL pause sync and log an error

#### Scenario: Duplicate change detection

- **WHEN** applying server updates
- **THEN** the service SHALL check if the same change (table + pk + client_ts) was already applied
- **AND** duplicate changes SHALL be skipped
- **AND** duplicate detection SHALL use a sliding window (last 1000 changes) to prevent memory growth

### Requirement: Server-Side Query Requirements

The SDK SHALL document server-side requirements for query handling and indexing.

Server-side requirements SHALL:

- Add `AND mtds_delete_ts IS NULL` to all INSERT and UPDATE queries
- Include `COALESCE(mtds_delete_ts, 0)` at the end of all UNIQUE indexes
- Ensure soft-deleted records are excluded from normal queries
- Support Redis cache for checking if changes exist since last sync

#### Scenario: Server query filtering

- **WHEN** server performs INSERT or UPDATE queries
- **THEN** server SHALL add `AND mtds_delete_ts IS NULL` to all queries
- **AND** soft-deleted records SHALL be excluded from normal operations

#### Scenario: Server UNIQUE index handling

- **WHEN** server creates UNIQUE indexes
- **THEN** indexes SHALL include `COALESCE(mtds_delete_ts, 0)` at the end
- **AND** soft-deleted records SHALL not violate UNIQUE constraints

#### Scenario: Server Redis cache check

- **WHEN** client sends `SyncAllTables` request with MAX(mtds_server_ts) per table
- **THEN** server SHALL check Redis cache to see if changes exist since last sync
- **AND** if no changes in cache, server may query actual tables for the tenant
- **AND** server SHALL return all updates where `mtds_server_ts > requested_timestamp`
