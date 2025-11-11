# Phase 4: Auth Service Integration - MTDS Compliance

## Overview

Phase 4 implements a pluggable authentication service architecture that supports JWT token parsing and decouples the SDK from specific auth providers (like UIDS). This enables the SDK to extract tenant ID, subject ID, and app name from JWT tokens or custom auth implementations.

## Changes Implemented

### 1. Abstract Auth Service Interface

**File:** `lib/src/auth/auth_service.dart`

Created an abstract interface that defines the contract for authentication providers:

```dart
abstract class AuthService {
  Future<String?> getTenantId();
  Future<String?> getSubjectId();
  Future<String?> getAppName();
  Future<int?> getDeviceId();
  Future<String?> getAuthToken();
  Map<String, dynamic>? parseToken(String token);
  Future<bool> isAuthenticated();
  Future<void> refreshAuth();
}
```

**Benefits:**

- **Pluggable**: Swap auth providers without changing SDK code
- **Testable**: Easy to mock for unit tests
- **Flexible**: Support JWT, OAuth, custom auth, etc.
- **Decoupled**: No dependency on specific auth providers

### 2. Default Auth Service Implementation

**File:** `lib/src/auth/default_auth_service.dart`

**Dependencies Added:**

- `jwt_decoder: ^2.0.1` - For JWT token parsing

**Features:**

```dart
class DefaultAuthService implements AuthService
```

#### JWT Token Parsing

- Automatically parses JWT tokens to extract claims
- Caches parsed tokens for performance
- Validates token expiration
- Extracts `tid`, `sub`, `app` from token claims

#### Fallback Support

- Tries JWT parsing first
- Falls back to direct secure storage reads
- Backward compatible with existing apps

#### Token Management

```dart
// Parse JWT and extract claims
final claims = authService.parseToken(jwtToken);
// Returns: {'tid': '...', 'sub': '...', 'app': '...', ...}

// Check if authenticated
final isAuth = await authService.isAuthenticated();

// Store auth token
await (authService as DefaultAuthService).setAuthToken(token);

// Clear authentication
await (authService as DefaultAuthService).clearAuth();
```

#### Storage Keys

The `DefaultAuthService` reads from these secure storage keys:

| Key                           | Purpose            | JWT Claim | Fallback    |
| ----------------------------- | ------------------ | --------- | ----------- |
| `AuthToken` / `JWT` / `Token` | JWT token          | N/A       | -           |
| `TenantId`                    | Tenant identifier  | `tid`     | Direct read |
| `SubjectId`                   | Subject identifier | `sub`     | Direct read |
| `AppName`                     | Application name   | `app`     | Direct read |
| `DeviceId`                    | 48-bit device ID   | -         | Direct read |

### 3. DBHelper Integration

**File:** `lib/src/db_helper.dart`

**Changes:**

- Removed direct `FlutterSecureStorage` dependency
- Added `AuthService` integration
- Pluggable auth service support

**New API:**

```dart
// Set custom auth service
DBHelper.setAuthService(myCustomAuthService);

// Get current auth service (auto-creates DefaultAuthService)
final authService = DBHelper.authService;
```

**Updated Methods:**

- `_getTenantId()` - Now uses `authService.getTenantId()`
- `_getSubjectId()` - Now uses `authService.getSubjectId()`
- `_getAppName()` - Now uses `authService.getAppName()`
- `getDeviceId48Bit()` - Now uses `authService.getDeviceId()`

### 4. SSE Manager Updates

**File:** `lib/src/sse/sse.dart`

**Changes:**

- Removed `FlutterSecureStorage` dependency
- Uses `DBHelper.getDeviceId48Bit()` for device ID
- Simplified initialization

**Before:**

```dart
String? deviceId = await _secureStorage.read(key: "DeviceId");
```

**After:**

```dart
final deviceId = await DBHelper.getDeviceId48Bit();
```

### 5. Export Updates

**File:** `lib/tenant_replication.dart`

Added public exports:

```dart
export 'src/auth/auth_service.dart';
export 'src/auth/default_auth_service.dart';
```

Users can now import and use auth services directly.

## JWT Token Structure

### Required Claims

For MTDS compliance, JWT tokens should include:

```json
{
  "sub": "user_id_or_subject",
  "tid": "tenant_id",
  "app": "application_name",
  "exp": 1234567890,
  "iat": 1234567890,
  ... other claims ...
}
```

### Example JWT Token

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyMTIzIiwidGlkIjoidGVuYW50NDU2IiwiYXBwIjoibXlhcHAiLCJleHAiOjE3MzY2MzM2MDB9.signature
```

**Decoded:**

```json
{
  "sub": "user123",
  "tid": "tenant456",
  "app": "myapp",
  "exp": 1736633600
}
```

## Usage Examples

### Example 1: Using Default Auth Service (JWT)

```dart
import 'package:tenant_replication/tenant_replication.dart';

// 1. Store JWT token in secure storage
final storage = FlutterSecureStorage();
await storage.write(key: 'AuthToken', value: jwtToken);
await storage.write(key: 'DeviceId', value: '12345');

// 2. SDK automatically uses DefaultAuthService
final db = await DBHelper.db;
// JWT is parsed, tid/sub/app extracted, database name generated

// 3. Check what was extracted
final authService = DBHelper.authService;
print('Tenant: ${await authService.getTenantId()}');
print('Subject: ${await authService.getSubjectId()}');
print('App: ${await authService.getAppName()}');
print('Authenticated: ${await authService.isAuthenticated()}');
```

### Example 2: Using Custom Auth Service

```dart
class MyCustomAuthService implements AuthService {
  @override
  Future<String?> getTenantId() async {
    // Get from your custom source
    return await myAuthProvider.getCurrentTenant();
  }

  @override
  Future<String?> getSubjectId() async {
    return await myAuthProvider.getCurrentUser();
  }

  @override
  Future<String?> getAppName() async {
    return 'my-custom-app';
  }

  @override
  Future<int?> getDeviceId() async {
    // Could use MAC address, UUID, etc.
    return await myAuthProvider.getDeviceIdentifier();
  }

  // ... implement other methods
}

// Use custom auth service
DBHelper.setAuthService(MyCustomAuthService());
final db = await DBHelper.db;
```

### Example 3: Firebase Auth Integration

```dart
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<String?> getTenantId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // Get custom claims from Firebase
    final idTokenResult = await user.getIdTokenResult();
    return idTokenResult.claims?['tid'] as String?;
  }

  @override
  Future<String?> getSubjectId() async {
    return _auth.currentUser?.uid;
  }

  @override
  Future<String?> getAppName() async {
    return 'firebase-app';
  }

  @override
  Future<int?> getDeviceId() async {
    // Store device ID in Firebase or secure storage
    final storage = FlutterSecureStorage();
    final deviceIdStr = await storage.read(key: 'DeviceId');
    return deviceIdStr != null ? int.parse(deviceIdStr) : null;
  }

  @override
  Future<String?> getAuthToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  @override
  Map<String, dynamic>? parseToken(String token) {
    // Firebase ID tokens are JWTs
    try {
      return JwtDecoder.decode(token);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    return _auth.currentUser != null;
  }

  @override
  Future<void> refreshAuth() async {
    await _auth.currentUser?.getIdToken(true);
  }
}

// Use it
DBHelper.setAuthService(FirebaseAuthService());
```

### Example 4: UIDS SDK Integration

```dart
import 'package:uids_sdk/uids_sdk.dart';

class UIDSAuthService implements AuthService {
  final UIDSClient _uidsClient;

  UIDSAuthService(this._uidsClient);

  @override
  Future<String?> getTenantId() async {
    final token = await _uidsClient.getToken();
    if (token == null) return null;

    final claims = parseToken(token);
    return claims?['tid'] as String?;
  }

  @override
  Future<String?> getSubjectId() async {
    final token = await _uidsClient.getToken();
    if (token == null) return null;

    final claims = parseToken(token);
    return claims?['sub'] as String?;
  }

  @override
  Future<String?> getAppName() async {
    return _uidsClient.appName;
  }

  @override
  Future<int?> getDeviceId() async {
    return await _uidsClient.getDeviceId();
  }

  @override
  Future<String?> getAuthToken() async {
    return await _uidsClient.getToken();
  }

  @override
  Map<String, dynamic>? parseToken(String token) {
    return JwtDecoder.decode(token);
  }

  @override
  Future<bool> isAuthenticated() async {
    return await _uidsClient.isAuthenticated();
  }

  @override
  Future<void> refreshAuth() async {
    await _uidsClient.refreshToken();
  }
}

// Initialize
final uidsClient = UIDSClient(/* config */);
DBHelper.setAuthService(UIDSAuthService(uidsClient));
```

### Example 5: Manual Token Setting

```dart
// Store token manually
final authService = DBHelper.authService as DefaultAuthService;
await authService.setAuthToken(jwtToken);
await authService.setDeviceId(123456);

// Parse and verify
final claims = authService.parseToken(jwtToken);
print('Token claims: $claims');

// Check authentication
if (await authService.isAuthenticated()) {
  print('✅ Token is valid');
  final db = await DBHelper.db;
} else {
  print('❌ Token expired or invalid');
}
```

## Migration Guide

### From Direct Secure Storage

**Before (Phase 1-3):**

```dart
final storage = FlutterSecureStorage();
await storage.write(key: 'TenantId', value: 'tenant123');
await storage.write(key: 'SubjectId', value: 'user456');
await storage.write(key: 'AppName', value: 'myapp');
await storage.write(key: 'DeviceId', value: '12345');
```

**After (Phase 4):**

```dart
// Option 1: Use JWT (recommended)
final storage = FlutterSecureStorage();
await storage.write(key: 'AuthToken', value: jwtToken);
await storage.write(key: 'DeviceId', value: '12345');
// SDK automatically extracts tid/sub/app from JWT

// Option 2: Continue using direct keys (backward compatible)
// Same as before - DefaultAuthService supports fallback
await storage.write(key: 'TenantId', value: 'tenant123');
await storage.write(key: 'SubjectId', value: 'user456');
await storage.write(key: 'AppName', value: 'myapp');
await storage.write(key: 'DeviceId', value: '12345');
```

### Custom Auth Provider

```dart
// Implement AuthService interface
class MyAuthService implements AuthService {
  // ... implement methods
}

// Register before first database access
DBHelper.setAuthService(MyAuthService());

// Use SDK normally
final db = await DBHelper.db;
```

## API Changes

### New Classes

- `AuthService` - Abstract interface
- `DefaultAuthService` - Default implementation with JWT support

### New Methods

**DBHelper:**

```dart
DBHelper.setAuthService(AuthService authService)
DBHelper.authService -> AuthService
```

**DefaultAuthService:**

```dart
defaultAuthService.setAuthToken(String token) -> Future<void>
defaultAuthService.setDeviceId(int deviceId) -> Future<void>
defaultAuthService.clearAuth() -> Future<void>
```

### Modified Internals

- `DBHelper._getTenantId()` - Uses auth service
- `DBHelper._getSubjectId()` - Uses auth service
- `DBHelper._getAppName()` - Uses auth service
- `DBHelper.getDeviceId48Bit()` - Uses auth service
- `SSEManager.initializeSSE()` - Uses DBHelper for device ID
- `SSEManager.loadData()` - Uses DBHelper for device ID

### Removed Dependencies

- `FlutterSecureStorage` removed from `DBHelper` (now in `DefaultAuthService`)
- `FlutterSecureStorage` removed from `SSEManager`

## Testing Examples

### Mock Auth Service for Testing

```dart
class MockAuthService implements AuthService {
  @override
  Future<String?> getTenantId() async => 'test-tenant';

  @override
  Future<String?> getSubjectId() async => 'test-subject';

  @override
  Future<String?> getAppName() async => 'test-app';

  @override
  Future<int?> getDeviceId() async => 12345;

  @override
  Future<String?> getAuthToken() async => 'mock-token';

  @override
  Map<String, dynamic>? parseToken(String token) => {
    'tid': 'test-tenant',
    'sub': 'test-subject',
    'app': 'test-app',
  };

  @override
  Future<bool> isAuthenticated() async => true;

  @override
  Future<void> refreshAuth() async {}
}

// Use in tests
testWidgets('Database initialization', (tester) async {
  DBHelper.setAuthService(MockAuthService());
  final db = await DBHelper.db;
  expect(db, isNotNull);
});
```

## Security Considerations

1. **Token Storage**: Always store JWT tokens in secure storage
2. **Token Expiration**: Check `isAuthenticated()` before operations
3. **Token Refresh**: Implement refresh logic in custom auth services
4. **Device ID**: Ensure device IDs fit in 48 bits
5. **Claims Validation**: Verify JWT claims match expected format

## Breaking Changes

**None** - Fully backward compatible!

- Apps without JWT tokens continue to work with direct secure storage keys
- Existing `TenantId`, `SubjectId`, `AppName` keys still supported
- No changes required to existing code

## Performance Improvements

- JWT tokens are parsed once and cached
- Reduces secure storage reads (single token vs multiple keys)
- Auth service can implement custom caching strategies

## Files Modified

- `pubspec.yaml` - Added `jwt_decoder` dependency
- `lib/src/auth/auth_service.dart` - NEW: Abstract interface
- `lib/src/auth/default_auth_service.dart` - NEW: Default implementation
- `lib/src/db_helper.dart` - Auth service integration
- `lib/src/sse/sse.dart` - Uses DBHelper for device ID
- `lib/tenant_replication.dart` - Export auth services

## Files Created

- `lib/src/auth/auth_service.dart`
- `lib/src/auth/default_auth_service.dart`

## Commit Recommendation

```bash
git add lib/ pubspec.yaml pubspec.lock
git commit -m "feat: Phase 4 - Auth Service Integration

- Create pluggable AuthService interface
- Implement DefaultAuthService with JWT parsing
- Add jwt_decoder dependency for token parsing
- Update DBHelper to use AuthService instead of direct secure storage
- Support JWT token claim extraction (tid, sub, app)
- Add backward compatibility with direct storage keys
- Update SSEManager to use centralized device ID access
- Export auth services for public use

Features:
- JWT token parsing with automatic claim extraction
- Pluggable auth providers (Firebase, UIDS, custom)
- Token caching and validation
- Fully backward compatible

MTDS Compliance: Requirement 1"
```
