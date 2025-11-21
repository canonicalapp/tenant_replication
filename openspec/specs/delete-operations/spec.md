## Purpose

Provides soft delete functionality for sync-aware deletions, allowing records to be marked as deleted and synced to the server before permanent removal.

## Requirements

### Requirement: Delete Operations

The SDK SHALL provide soft delete functionality for sync-aware deletions.

Delete operations SHALL:

- Provide `softDelete()` method for marking records as deleted
- Support normal DELETE operations (users can delete directly)
- Not provide `hardDelete()` method (removed from API)
- Use `mtds_delete_ts` column (BIGINT) to mark soft-deleted records
- Set `mtds_delete_ts` to the same value as `mtds_client_ts` when soft deleting

#### Scenario: Soft delete for sync

- **WHEN** `softDelete()` is called
- **THEN** the record SHALL be updated with:
  - `mtds_delete_ts` set to current `mtds_client_ts` value (via trigger)
  - `mtds_client_ts` updated via state table (via trigger)
  - `mtds_device_id` set to current device ID (via trigger)
- **AND** the change SHALL be logged to change log via AFTER UPDATE trigger
- **AND** the change SHALL be synced to server
- **AND** when server confirms (returns `mtds_server_ts`), the record SHALL be hard deleted locally

#### Scenario: Normal delete operations

- **WHEN** user performs standard DELETE operation
- **THEN** the operation SHALL proceed normally
- **AND** triggers SHALL handle change tracking if applicable
- **AND** no special SDK method is required

#### Scenario: Hard delete bypass

- **WHEN** user performs hard delete (standard DELETE)
- **THEN** the record SHALL be permanently removed from local database
- **AND** the operation SHALL bypass MTDS change tracking
- **AND** the change SHALL NOT be synced to server
- **AND** per-table MAX timestamp in state table SHALL remain unchanged (no cache invalidation needed)

#### Scenario: Soft delete timestamp generation

- **WHEN** a record is soft deleted
- **THEN** BEFORE UPDATE trigger SHALL:
  - Update `mtds:client_ts` in state table and get numValue
  - Set `NEW.mtds_client_ts` to the returned numValue
  - Set `NEW.mtds_delete_ts` to the same value as `mtds_client_ts`
  - Set `NEW.mtds_device_id` to current DeviceID
- **AND** `mtds_delete_ts` SHALL be stored as BIGINT in milliseconds since client epoch

#### Scenario: Server-side soft delete handling

- **WHEN** server receives soft-deleted record
- **THEN** server SHALL:
  - Add `mtds_delete_ts` timestamp
  - Add `mtds_server_ts` timestamp
  - Broadcast the change to all devices
- **AND** when client receives the soft-deleted record with `mtds_server_ts`
- **THEN** client SHALL perform hard delete locally
- **AND** other devices receiving the same update SHALL also remove the record

#### Scenario: Server query filtering

- **WHEN** server performs INSERT or UPDATE queries
- **THEN** server SHALL add `AND mtds_delete_ts IS NULL` to all queries
- **AND** server-side UNIQUE indexes SHALL include `COALESCE(mtds_delete_ts, 0)` at the end
- **AND** soft-deleted records SHALL be excluded from normal queries
