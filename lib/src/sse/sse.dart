import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sse_handler_web.dart' if (dart.library.io) 'sse_handler_native.dart';

class SSEManager {
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static Future<void> initializeSSE(url) async {
    String? deviceId = await _secureStorage.read(key: "DeviceId");
    print('Initializing SSE.............................');

    final SSEHandler _sseHandler = SSEHandler('$url/events?deviceId=$deviceId');

    _sseHandler.startListening();
    print('SSE started listening for events.............................');

    _sseHandler.stream.listen((data) async {
      try {
        print('Raw event received: $data'); // Debug print of the raw event
        if (data != 'Connected') {
          final Map<String, dynamic> event = jsonDecode(data);
          print('Decoded event: $event'); // Debug print of decoded JSON
        }
      } catch (e) {
        print('Error processing event: $e');
      }
    });
  }
}
