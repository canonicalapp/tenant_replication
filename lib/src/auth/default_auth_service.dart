import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'auth_service.dart';

/// Default implementation of AuthService that reads from Flutter Secure Storage
/// This implementation:
/// - Reads values directly from secure storage (backward compatible)
/// - Can parse JWT tokens to extract tid/sub/app
/// - Falls back to explicit storage keys if JWT parsing fails
class DefaultAuthService implements AuthService {
  final FlutterSecureStorage _secureStorage;

  // Cache for parsed token
  Map<String, dynamic>? _cachedTokenClaims;
  String? _lastParsedToken;

  DefaultAuthService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  @override
  Future<String?> getTenantId() async {
    // Try to get from JWT token first
    final token = await getAuthToken();
    if (token != null) {
      final claims = parseToken(token);
      if (claims != null && claims.containsKey('tid')) {
        return claims['tid'] as String?;
      }
    }

    // Fallback to direct storage read
    return await _secureStorage.read(key: 'TenantId');
  }

  @override
  Future<String?> getSubjectId() async {
    // Try to get from JWT token first
    final token = await getAuthToken();
    if (token != null) {
      final claims = parseToken(token);
      if (claims != null && claims.containsKey('sub')) {
        return claims['sub'] as String?;
      }
    }

    // Fallback to direct storage read
    return await _secureStorage.read(key: 'SubjectId');
  }

  @override
  Future<String?> getAppName() async {
    // Try to get from JWT token first
    final token = await getAuthToken();
    if (token != null) {
      final claims = parseToken(token);
      if (claims != null && claims.containsKey('app')) {
        return claims['app'] as String?;
      }
    }

    // Fallback to direct storage read
    return await _secureStorage.read(key: 'AppName');
  }

  @override
  Future<int?> getDeviceId() async {
    final deviceIdStr = await _secureStorage.read(key: 'DeviceId');
    if (deviceIdStr == null || deviceIdStr.isEmpty) {
      return null;
    }

    try {
      final deviceId = int.parse(deviceIdStr);

      // Validate 48-bit limit
      if (deviceId > 0xFFFFFFFFFFFF) {
        throw Exception(
          'DeviceID exceeds 48-bit limit: $deviceId (max: ${0xFFFFFFFFFFFF})',
        );
      }

      return deviceId;
    } catch (e) {
      print('⚠️ Error parsing DeviceID: $e');
      return null;
    }
  }

  @override
  Future<String?> getAuthToken() async {
    // Try multiple possible keys for auth token
    final token =
        await _secureStorage.read(key: 'AuthToken') ??
        await _secureStorage.read(key: 'JWT') ??
        await _secureStorage.read(key: 'Token');

    return token;
  }

  @override
  Map<String, dynamic>? parseToken(String token) {
    // Return cached if same token
    if (_lastParsedToken == token && _cachedTokenClaims != null) {
      return _cachedTokenClaims;
    }

    try {
      // Check if token is expired
      if (JwtDecoder.isExpired(token)) {
        print('⚠️ JWT token is expired');
        return null;
      }

      // Decode token
      final decodedToken = JwtDecoder.decode(token);

      // Cache the result
      _lastParsedToken = token;
      _cachedTokenClaims = decodedToken;

      print('✅ JWT token parsed successfully');
      print('   - sub: ${decodedToken['sub']}');
      print('   - tid: ${decodedToken['tid']}');
      print('   - app: ${decodedToken['app']}');

      return decodedToken;
    } catch (e) {
      print('⚠️ Failed to parse JWT token: $e');
      _cachedTokenClaims = null;
      _lastParsedToken = null;
      return null;
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await getAuthToken();
    if (token == null) return false;

    try {
      return !JwtDecoder.isExpired(token);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> refreshAuth() async {
    // Clear cache to force re-read
    _cachedTokenClaims = null;
    _lastParsedToken = null;
  }

  /// Helper: Store auth token in secure storage
  Future<void> setAuthToken(String token) async {
    await _secureStorage.write(key: 'AuthToken', value: token);

    // Parse and cache
    parseToken(token);
  }

  /// Helper: Store device ID in secure storage
  Future<void> setDeviceId(int deviceId) async {
    if (deviceId > 0xFFFFFFFFFFFF) {
      throw Exception('DeviceID exceeds 48-bit limit: $deviceId');
    }
    await _secureStorage.write(key: 'DeviceId', value: deviceId.toString());
  }

  /// Helper: Clear all auth data
  Future<void> clearAuth() async {
    await _secureStorage.delete(key: 'AuthToken');
    await _secureStorage.delete(key: 'JWT');
    await _secureStorage.delete(key: 'Token');
    _cachedTokenClaims = null;
    _lastParsedToken = null;
  }
}
