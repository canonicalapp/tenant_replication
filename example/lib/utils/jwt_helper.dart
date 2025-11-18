import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// Helper utility for generating test JWT tokens
///
/// This is for testing purposes only. In production, obtain JWT tokens
/// from your authentication server.
class JwtHelper {
  /// Generate a test JWT token with tenant-id and user-id claims
  ///
  /// For testing, we use a simple symmetric key (HMAC). In production,
  /// your server will use its own secret key to validate tokens.
  ///
  /// Parameters:
  /// - [tenantId]: The tenant identifier (default: 'test-tenant')
  /// - [userId]: The user identifier (default: 'test-user')
  /// - [expirationMinutes]: Token expiration in minutes (default: 60)
  /// - [secretKey]: Secret key for signing (default: 'test-secret-key')
  ///
  /// Returns a signed JWT token string
  static String generateTestToken({
    String tenantId = 'test-tenant',
    String userId = 'test-user',
    int expirationMinutes = 60,
    String secretKey = 'test-secret-key',
  }) {
    // Standard JWT claims
    final now = DateTime.now();
    final iat = now.millisecondsSinceEpoch ~/ 1000;
    final exp =
        now.add(Duration(minutes: expirationMinutes)).millisecondsSinceEpoch ~/
        1000;

    final payload = {
      // Standard JWT claims
      'iss': 'mtds-test-client', // Issuer
      'sub': userId, // Subject (user ID)
      'iat': iat, // Issued at
      'exp': exp, // Expiration
      // Custom claims for MTDS
      'tenant-id': tenantId,
      'user-id': userId,
    };

    return _encodeJWT(payload, secretKey);
  }

  /// Generate a JWT token using a specific secret key (for server matching)
  ///
  /// Use this if your server uses a specific secret key for JWT validation.
  /// You'll need to configure the same secret on your test server.
  static String generateTokenWithSecret({
    required String secretKey,
    String tenantId = 'test-tenant',
    String userId = 'test-user',
    int expirationMinutes = 60,
  }) {
    return generateTestToken(
      tenantId: tenantId,
      userId: userId,
      expirationMinutes: expirationMinutes,
      secretKey: secretKey,
    );
  }

  /// Encode a JWT token (header.payload.signature)
  static String _encodeJWT(Map<String, dynamic> payload, String secretKey) {
    // JWT Header
    final header = {'alg': 'HS256', 'typ': 'JWT'};

    // Encode header and payload to base64url
    final encodedHeader = _base64UrlEncode(jsonEncode(header));
    final encodedPayload = _base64UrlEncode(jsonEncode(payload));

    // Create signature using HMAC-SHA256
    final message = '$encodedHeader.$encodedPayload';
    final key = utf8.encode(secretKey);
    final messageBytes = utf8.encode(message);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(messageBytes);
    // Convert digest bytes to base64url
    // digest.bytes is already bytes, so encode to base64 then convert to base64url
    final base64 = base64Encode(digest.bytes);
    final signature = base64
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', ''); // Remove padding

    // Combine all parts
    return '$encodedHeader.$encodedPayload.$signature';
  }

  /// Base64URL encode (JWT standard)
  static String _base64UrlEncode(String input) {
    final bytes = utf8.encode(input);
    final base64 = base64Encode(bytes);
    return base64
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', ''); // Remove padding
  }

  /// Decode a JWT token to inspect its claims (for debugging)
  ///
  /// Returns a map of claims, or null if token is invalid
  static Map<String, dynamic>? decodeToken(String token) {
    try {
      return JwtDecoder.decode(token);
    } catch (e) {
      print('❌ Failed to decode JWT: $e');
      return null;
    }
  }

  /// Check if a JWT token is expired
  static bool isExpired(String token) {
    try {
      return JwtDecoder.isExpired(token);
    } catch (e) {
      return true;
    }
  }
}
