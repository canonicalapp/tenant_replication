import 'dart:async';
import 'dart:html' as html;

class SSEHandler {
  final String url;
  final Map<String, String>? headers;
  final StreamController<String> _controller = StreamController<String>();

  SSEHandler(this.url, {this.headers});

  Stream<String> get stream => _controller.stream;

  void startListening() {
    try {
      final effectiveUrl = _appendQueryParameters(url, headers ?? const {});
      final eventSource = html.EventSource(effectiveUrl);
      // final eventSource = html.EventSource(url);
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
String _appendQueryParameters(String baseUrl, Map<String, String> extra) {
  if (extra.isEmpty) return baseUrl;

  final uri = Uri.parse(baseUrl);

  // Transform Authorization header into a token query param
  final transformed = <String, String>{};
  extra.forEach((key, value) {
    if (key.toLowerCase() == 'authorization' && value.toLowerCase().startsWith('bearer ')) {
      transformed['token'] = value.substring(7); // remove "Bearer "
    } else {
      transformed[key] = value;
    }
  });

  // Merge existing query params with new ones
  final merged = <String, String>{
    ...uri.queryParameters,
    ...transformed,
  };

  final newUri = uri.replace(queryParameters: merged);
  return newUri.toString();
}