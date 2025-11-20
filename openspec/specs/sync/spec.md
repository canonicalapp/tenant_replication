## Purpose

The synchronization service provides bidirectional data synchronization between client and server using GraphQL operations, with support for offline-first scenarios, initial sync, and real-time updates.

## Requirements

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

#### Scenario: Initial sync on app start

- **WHEN** the app starts or comes online
- **THEN** the service SHALL query all tables for their max `mtds_server_ts` (or `mtds_client_ts` if `mtds_server_ts` is NULL)
- **AND** send table names with max timestamps to server via GraphQL mutation
- **AND** receive all updates where `mtds_server_ts > requested_timestamp`
- **AND** the service SHALL check `mtds_device_id` for each received record
- **AND** if `mtds_device_id` matches current device, the record SHALL be skipped (prevent loops)
- **AND** if `mtds_device_id` differs, the record SHALL be applied to local database idempotently
- **AND** update local records with server-assigned `mtds_server_ts` values

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

### Requirement: Initial Sync Operation

The SDK SHALL automatically perform initial sync when the app starts or comes online.

Initial sync SHALL:

- Query all user tables for their maximum `mtds_server_ts` (using `MAX(mtds_server_ts)` query)
- Cache MAX values to avoid repeated queries (especially after hard deletes)
- Send table names with max timestamps to server
- Receive all updates where `mtds_server_ts > requested_timestamp`
- Apply updates to local database idempotently
- Update local records with server-assigned `mtds_server_ts` values
- Be idempotent (safe to call multiple times)

#### Scenario: Initial sync on app start

- **WHEN** the SDK is initialized
- **THEN** initial sync SHALL be triggered automatically
- **AND** all tables SHALL be queried for max `mtds_server_ts`
- **AND** MAX values SHALL be cached
- **AND** updates SHALL be fetched and applied

#### Scenario: Initial sync on network reconnect

- **WHEN** network connectivity is restored
- **AND** there are pending changes or app was offline
- **THEN** initial sync SHALL be triggered
- **AND** cached MAX values SHALL be used if available
- **AND** updates since last sync SHALL be fetched

### Requirement: MAX Timestamp Caching

The SDK SHALL cache the maximum `mtds_server_ts` value per table to avoid repeated database queries.

Caching SHALL:

- Store MAX timestamp per table in memory
- Update cache when records are synced from server
- Use cached values for initial sync queries
- Invalidate cache appropriately (e.g., after hard deletes that might affect MAX)

#### Scenario: Cache MAX timestamp

- **WHEN** initial sync queries MAX timestamp for a table
- **THEN** the value SHALL be cached in memory
- **AND** subsequent initial sync requests SHALL use cached value
- **AND** cache SHALL be updated when new records with higher `mtds_server_ts` are received

#### Scenario: Cache invalidation after hard delete

- **WHEN** a hard delete occurs (bypassing MTDS)
- **THEN** the MAX timestamp cache SHALL be invalidated for that table
- **AND** next initial sync SHALL query MAX timestamp from database
- **AND** cache SHALL be refreshed with new value

### Requirement: Soft Delete Hard Delete on Sync Back

When a soft-deleted record is received from the server (indicating server confirmed the delete), the client SHALL perform a hard delete locally.

#### Scenario: Soft delete confirmation from server

- **WHEN** a soft-deleted record is received from server via sync
- **AND** the record has `mtds_deleted_ts` set
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

