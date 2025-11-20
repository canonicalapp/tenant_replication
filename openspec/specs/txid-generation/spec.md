## Purpose

Provides unique transaction ID generation using monotonic counters for ordering and conflict resolution in synchronization operations.

## Requirements

### Requirement: Transaction ID Generation

The SDK SHALL generate unique transaction IDs (TXID) for ordering and conflict resolution using a monotonic counter class in the utils module.

TXID generation SHALL:

- Be implemented as a `TX` class in the utils module
- Use a monotonic counter to guarantee uniqueness
- Use BigInt for large value support
- Combine timestamp with counter for ordering
- Ensure thread-safety if needed

#### Scenario: Unique TXID generation from utils

- **WHEN** `TX.getId()` is called from the utils module
- **THEN** a unique BigInt value SHALL be returned
- **AND** subsequent calls SHALL return strictly increasing values
- **AND** uniqueness SHALL be guaranteed even under concurrent operations
- **AND** the implementation SHALL be located in the utils module

#### Scenario: Monotonic ordering

- **WHEN** multiple TXIDs are generated via `TX.getId()`
- **THEN** each TXID SHALL be greater than the previous
- **AND** ordering SHALL be preserved across app restarts (if counter is persisted)

#### Scenario: Timestamp-based initialization

- **WHEN** counter is initialized in the `TX` class
- **THEN** counter SHALL start from current timestamp in nanoseconds
- **AND** if timestamp is less than current counter, counter SHALL increment
- **AND** the counter state SHALL be maintained in the utils module

### Requirement: Monotonic ID Generation in Utils

The SDK SHALL provide a `TX` class in the utils module for generating monotonic transaction IDs.

The `TX` class SHALL:

- Be located in the utils module (e.g., `lib/src/utils/`)
- Provide a static `getId()` method that returns a unique BigInt
- Maintain a static counter that ensures monotonic ordering
- Initialize counter from timestamp on first use

#### Scenario: TX class location

- **WHEN** the SDK is used
- **THEN** the `TX` class SHALL be available in the utils module
- **AND** it SHALL be importable from the SDK's utils exports

#### Scenario: Counter implementation

- **WHEN** `TX.getId()` is implemented
- **THEN** it SHALL use a static BigInt counter
- **AND** it SHALL compare current timestamp with counter value
- **AND** it SHALL increment counter if timestamp is not greater

