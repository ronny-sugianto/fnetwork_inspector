import 'dart:convert';

import 'package:fnetwork_inspector/src/core/fnetwork_store.dart';
import 'package:fnetwork_inspector/src/model/network_log.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// An [http.BaseClient] interceptor that logs all requests to [FNetworkStore].
///
/// Wrap any [http.Client] the same way you'd add an interceptor to Dio:
/// ```dart
/// final client = FNetworkHttpInterceptor(inner: http.Client());
/// ```
class FNetworkHttpInterceptor extends http.BaseClient {
  FNetworkHttpInterceptor({required http.Client inner}) : _inner = inner;

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final String id = const Uuid().v4();
    final DateTime startTime = DateTime.now();
    final int startMs = startTime.millisecondsSinceEpoch;

    final Uri uri = request.url;
    final String path =
        uri.path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
    final String baseUrl = '${uri.scheme}://${uri.host}'
        '${uri.hasPort && uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}';

    String? requestBody;
    if (request is http.Request && request.body.isNotEmpty) {
      requestBody = request.body;
    }

    FNetworkStore.instance.onRequest(
      NetworkLog(
        id: id,
        method: request.method,
        path: path,
        baseUrl: baseUrl,
        status: NetworkLogStatus.loading,
        startTime: startTime,
        requestHeaders: Map<String, dynamic>.from(request.headers),
        requestBody: requestBody,
      ),
    );

    try {
      final http.StreamedResponse response = await _inner.send(request);
      final List<int> bodyBytes = await response.stream.toBytes();
      final int durationMs = DateTime.now().millisecondsSinceEpoch - startMs;

      String? responseBody;
      try {
        responseBody = utf8.decode(bodyBytes, allowMalformed: true);
      } catch (_) {}

      final Map<String, dynamic> responseHeaders =
          Map<String, dynamic>.from(response.headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        FNetworkStore.instance.onSuccess(
          id,
          response.statusCode,
          durationMs,
          responseHeaders: responseHeaders,
          responseBody: responseBody,
        );
      } else {
        FNetworkStore.instance.onError(
          id,
          response.statusCode,
          response.reasonPhrase ?? 'HTTP ${response.statusCode}',
          durationMs,
          responseBody: responseBody,
        );
      }

      // Reconstruct the response with the already-consumed body bytes.
      return http.StreamedResponse(
        Stream<List<int>>.value(bodyBytes),
        response.statusCode,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
        request: response.request,
        contentLength: bodyBytes.length,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
      );
    } catch (e) {
      final int durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
      FNetworkStore.instance.onError(id, null, e.toString(), durationMs);
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
