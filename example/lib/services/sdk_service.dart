import 'package:dio/dio.dart';
import 'package:mtds/index.dart';
import '../database.dart';

/// Service for initializing and managing the MTDS SDK
///
/// Note: Authentication is the consumer's responsibility.
/// Configure Dio interceptors in your app to add auth headers/tokens.
class SdkService {
  /// Initialize SDK with a Dio instance configured by the consumer
  ///
  /// The consumer should configure Dio with auth interceptors before
  /// passing it to the SDK. The SDK does not handle authentication.
  ///
  /// Example:
  /// ```dart
  /// final dio = Dio();
  /// dio.interceptors.add(
  ///   InterceptorsWrapper(
  ///     onRequest: (options, handler) {
  ///       // Add your auth token here
  ///       options.headers['Authorization'] = 'Bearer $yourToken';
  ///       return handler.next(options);
  ///     },
  ///   ),
  /// );
  ///
  /// final sdk = await SdkService.initializeSdk(db, dio);
  /// ```
  static Future<MTDS_SDK> initializeSdk(
    AppDatabase db,
    Dio httpClient,
  ) async {
    // Initialize SDK with consumer-provided Dio instance
    final sdk = MTDS_SDK(
      db: db,
      httpClient: httpClient,
      serverUrl: 'http://localhost:3000',
      deviceId: 12345, // Test device ID
    );

    return sdk;
  }
}
