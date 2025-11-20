## Purpose

Provides client-side timestamp generation using monotonic counters with device ID encoding for conflict resolution and change tracking.

## Requirements

### Requirement: Client Timestamp Generation (PK Class)

The SDK SHALL provide a `PK` class in the utils module for generating client timestamps using a monotonic counter with device ID encoding.

The `PK` class SHALL:

- Be located in the utils module (e.g., `lib/src/utils/`)
- Use a custom epoch starting at January 1, 2025 (timestamp: 1735671600000)
- Use a Stopwatch for monotonic elapsed time tracking
- Encode device ID in the lower 24 bits of the timestamp
- Combine start time, uptime, and device ID into a single BigInt value
- Initialize with device ID before first use

#### Scenario: PK class initialization

- **WHEN** `PK.initialize(deviceId)` is called
- **THEN** the device ID SHALL be stored in the PK class
- **AND** the class SHALL be ready to generate timestamps

#### Scenario: Client timestamp generation

- **WHEN** `PK.getPK()` is called
- **THEN** a unique BigInt value SHALL be returned
- **AND** the value SHALL be calculated as: `((startTime + upTime) << 24) + (deviceId & 0xFFFFFF)`
- **AND** startTime SHALL be: `DateTime.now().millisecondsSinceEpoch - 1735671600000`
- **AND** upTime SHALL be monotonic (never decreases, increments if elapsed time doesn't increase)
- **AND** device ID SHALL be encoded in the lower 24 bits

#### Scenario: Monotonic uptime guarantee

- **WHEN** `PK.getPK()` is called multiple times
- **THEN** upTime SHALL be greater than or equal to elapsed milliseconds
- **AND** if elapsed time doesn't increase, upTime SHALL increment by one
- **AND** subsequent calls SHALL return strictly increasing values

#### Scenario: Device ID encoding

- **WHEN** a timestamp is generated via `PK.getPK()`
- **THEN** the lower 24 bits SHALL contain the device ID
- **AND** the device ID SHALL be masked with `0xFFFFFF` before encoding
- **AND** the device ID SHALL be extractable from the generated timestamp

### Requirement: Client Timestamp Usage

The SDK SHALL generate client timestamps using the `PK` class for client-side timestamp generation.

Client timestamp generation SHALL:

- Use `PK.getPK()` for generating `mtds_client_ts` values
- Initialize PK class with device ID during SDK initialization
- Ensure timestamps are unique and monotonic
- Encode device ID in the timestamp value

#### Scenario: Client timestamp for inserts

- **WHEN** a new record is inserted
- **THEN** `mtds_client_ts` SHALL be set using `PK.getPK()`
- **AND** the timestamp SHALL be unique and monotonic
- **AND** the device ID SHALL be encoded in the timestamp

#### Scenario: Client timestamp for updates

- **WHEN** a record is updated
- **THEN** `mtds_client_ts` SHALL be updated using `PK.getPK()`
- **AND** the new timestamp SHALL be greater than the previous
- **AND** the device ID SHALL remain encoded in the timestamp

