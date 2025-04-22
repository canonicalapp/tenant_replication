import 'dart:async';
import 'dart:html' as html;

class SSEHandler {
  final String url;
  final StreamController<String> _controller = StreamController<String>();

  SSEHandler(this.url);

  Stream<String> get stream => _controller.stream;

  void startListening() {
    try {
      final eventSource = html.EventSource(url);
      print("Connected to SSE");
      eventSource.onMessage.listen((html.MessageEvent event) {
        if (event.data != null) {
          print('Event data: ${event.data}');
          _controller.add(event.data!);
        }
      });

      eventSource.onError.listen((error) {
        print('SSE Error: $error');
        _controller.addError(error);
      });
    } catch (e) {
      print('Error connecting to SSE: $e');
    }
  }

  void dispose() {
    _controller.close();
  }
}