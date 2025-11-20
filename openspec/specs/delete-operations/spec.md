## Purpose

Provides soft delete functionality for sync-aware deletions, allowing records to be marked as deleted and synced to the server before permanent removal.

## Requirements

### Requirement: Delete Operations

The SDK SHALL provide soft delete functionality for sync-aware deletions.

Delete operations SHALL:

- Provide `softDelete()` method for marking records as deleted
- Support normal DELETE operations (users can delete directly)
- Not provide `hardDelete()` method (removed from API)

#### Scenario: Soft delete for sync

- **WHEN** `softDelete()` is called
- **THEN** the record SHALL be marked with `mtds_deleted_ts` using `PK.getPK()`
- **AND** `mtds_client_ts` SHALL be updated using `PK.getPK()`
- **AND** the change SHALL be logged to change log
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
- **AND** MAX timestamp cache SHALL be invalidated for that table

