## Purpose

Manages device identification for multi-device synchronization, ensuring each device has a unique, persistent 64-bit identifier.

## Requirements

### Requirement: Drift ORM Usage

The SDK SHALL use Drift ORM as the primary method for all device ID database operations to ensure type safety.

Device ID operations SHALL:

- Use Drift ORM methods as the default for querying and updating device ID in `mtds_state` table
- Use raw SQL queries only when Drift ORM cannot be used effectively (e.g., SQL triggers, performance limitations, or unsupported operations)
- Ensure type-safe retrieval and storage of 64-bit device ID values where possible

### Requirement: Device ID Management

The SDK SHALL manage device identification using the `mtds_state` table exclusively.

Device ID management SHALL:

- Store device ID in `mtds_state` table with Attribute `'mtds:DeviceID'` and numValue as the 64-bit device ID
- Never change device ID after first initialization
- Support optional device ID parameter in SDK constructor
- Generate random device ID if not provided
- Be retrievable from state table using Drift ORM (triggers may use raw SQL as needed)
- Use 64-bit BIGINT for device ID storage

#### Scenario: Device ID initialization with provided value

- **WHEN** SDK is initialized with deviceID parameter
- **AND** no device ID exists in state table (Attribute = 'mtds:DeviceID')
- **THEN** the provided 64-bit device ID SHALL be stored in `mtds_state` table with Attribute `'mtds:DeviceID'` and numValue as the device ID
- **AND** the device ID SHALL be used for all operations

#### Scenario: Device ID initialization without provided value

- **WHEN** SDK is initialized without deviceID parameter
- **AND** no device ID exists in state table (Attribute = 'mtds:DeviceID')
- **THEN** a random 64-bit device ID SHALL be generated
- **AND** the generated device ID SHALL be stored in `mtds_state` table with Attribute `'mtds:DeviceID'` and numValue as the device ID

#### Scenario: Device ID persistence

- **WHEN** device ID exists in state table (Attribute = 'mtds:DeviceID')
- **THEN** the existing device ID SHALL be retrieved using Drift ORM from `mtds_state` table WHERE Attribute = 'mtds:DeviceID'
- **AND** it SHALL never be changed during database lifetime
- **AND** provided device ID parameter SHALL be ignored if state table entry exists

#### Scenario: Device ID retrieval for triggers

- **WHEN** triggers need device ID for change tracking
- **THEN** device ID SHALL be read from `mtds_state` table (triggers may use raw SQL as SQL triggers require SQL syntax)
- **AND** triggers SHALL use this value to populate `mtds_device_id` column
- **NOTE**: SQL triggers require raw SQL, but application code SHALL use Drift ORM

#### Scenario: Device ID validation

- **WHEN** a device ID is provided or generated
- **THEN** the device ID SHALL be a valid 64-bit integer (BIGINT)
- **AND** the device ID SHALL be stored as numValue in `mtds_state` table
- **AND** invalid device IDs SHALL be rejected with an error
