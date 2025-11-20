## Purpose

Automatically tracks database changes via SQL triggers for synchronization, ensuring all local modifications are captured and synced to the server.

## Requirements

### Requirement: Automatic Change Tracking Triggers

The SDK SHALL create SQL triggers on all user tables to automatically track changes for synchronization.

Triggers SHALL:

- Use `mtds_trigger_` prefix to avoid conflicts with user-defined triggers
- Include BEFORE INSERT triggers to populate `mtds_device_id`
- Include AFTER INSERT triggers for insert tracking
- Include AFTER UPDATE triggers for update and soft delete tracking
- Read device ID from `mtds_metadata` table

#### Scenario: BEFORE INSERT trigger populates device ID and client timestamp

- **WHEN** a new row is inserted into any user table
- **THEN** BEFORE INSERT trigger SHALL populate `mtds_device_id` from metadata table
- **AND** trigger SHALL populate `mtds_client_ts` using PK class (via application code)
- **AND** trigger SHALL use namespace `mtds_trigger_${tableName}_insert_before`
- **NOTE**: SQLite limitations may require application code to set `mtds_client_ts` directly

#### Scenario: AFTER INSERT trigger logs change

- **WHEN** a new row is inserted into any user table
- **AND** the row's `mtds_device_id` matches current device ID
- **THEN** AFTER INSERT trigger SHALL log change to `mtds_change_log`
- **AND** trigger SHALL use namespace `mtds_trigger_${tableName}_insert`

#### Scenario: AFTER UPDATE trigger logs changes

- **WHEN** a row is updated in any user table
- **AND** `mtds_client_ts` changed or soft delete occurred
- **AND** the row's `mtds_device_id` matches current device ID
- **THEN** AFTER UPDATE trigger SHALL log change to `mtds_change_log`
- **AND** trigger SHALL use namespace `mtds_trigger_${tableName}_update`
- **AND** the trigger SHALL capture both `mtds_client_ts` and `mtds_server_ts` in the payload

#### Scenario: Trigger namespace isolation

- **WHEN** user defines their own triggers
- **THEN** SDK triggers SHALL not conflict due to `mtds_trigger_` prefix
- **AND** user triggers SHALL not interfere with SDK triggers

### Requirement: BEFORE INSERT Trigger for Device ID and Client Timestamp

The SDK SHALL create BEFORE INSERT triggers that automatically populate `mtds_device_id` and `mtds_client_ts` columns.

#### Scenario: Automatic device ID and client timestamp population

- **WHEN** a row is inserted without `mtds_device_id` or `mtds_client_ts` set
- **THEN** BEFORE INSERT trigger SHALL read device ID from `mtds_metadata` table
- **AND** trigger SHALL set `NEW.mtds_device_id` to the retrieved value
- **AND** application code SHALL set `NEW.mtds_client_ts` using `PK.getPK()`
- **NOTE**: Due to SQLite limitations, `mtds_client_ts` may need to be set by application code before insert

