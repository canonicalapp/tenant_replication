import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:eventsource/eventsource.dart';

class SSEHandler {
  final String url;
  final StreamController<String> _controller = StreamController<String>();
  EventSource? _eventSource;
  StreamSubscription<Event>? _subscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription; // Updated type
  bool _isReconnecting = false;
  int _retryDelay = 5000; // Initial retry delay in milliseconds

  SSEHandler(this.url);

  Stream<String> get stream => _controller.stream;

  void startListening() async {
    try {
      print("Connecting to SSE...");
      _eventSource = await EventSource.connect(url);
      print("Connected to SSE");

      // Reset retry delay on successful connection
      _retryDelay = 5000;

      _subscription = _eventSource!.listen((Event event) {
        if (event.data != null) {
          print('Event data: ${event.data}');
          _controller.add(event.data!);
        }
      }, onError: (error) {
        print("SSE connection error: $error");
        _attemptReconnect();
      }, onDone: () {
        print("SSE connection closed.");
        _attemptReconnect();
      });

      // ✅ Start monitoring network connectivity
      _monitorNetworkConnectivity();
    } catch (e) {
      print('Error connecting to SSE: $e');
      _attemptReconnect();
    }
  }

  // ✅ Monitor network connectivity changes
  void _monitorNetworkConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Check if any of the connectivity results indicate a connected state
      if (results.any((result) => result != ConnectivityResult.none)) {
        print("Network restored. Attempting to reconnect to SSE...");
        _attemptReconnect();
      } else {
        print("Network lost. SSE connection may be interrupted.");
      }
    });
  }

  void _attemptReconnect() {
    if (!_isReconnecting) {
      _isReconnecting = true;
      print("Attempting to reconnect in $_retryDelay ms...");
      Future.delayed(Duration(milliseconds: _retryDelay), () {
        _isReconnecting = false;
        startListening(); // Retry connection
        _retryDelay = _retryDelay * 2; // Exponential backoff
        if (_retryDelay > 60000) _retryDelay = 60000; // Cap retry delay at 60s
      });
    }
  }

  void dispose() {
    _subscription?.cancel(); // Properly cancel the subscription
    _connectivitySubscription?.cancel(); // Cancel the connectivity subscription
    _controller.close(); // Close the stream controller
  }
}