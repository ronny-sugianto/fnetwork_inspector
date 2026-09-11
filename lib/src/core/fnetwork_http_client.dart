import 'dart:convert';

import 'package:fnetwork_inspector/src/core/fchaos_store.dart';
import 'package:fnetwork_inspector/src/core/fmock_store.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_store.dart';
import 'package:fnetwork_inspector/src/model/fmock_rule.dart';
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

    final FMockRule? mock = FMockStore.instance.match(request.method, path);
    final bool offline = mock == null && FChaosStore.instance.isOffline;
    final bool chaosFail =
        mock == null && !offline && FChaosStore.instance.shouldFail();

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
        isMocked: mock != null,
        isChaos: chaosFail || offline,
      ),
    );

    if (mock != null) {
      return _serveMock(request, mock, id, startMs);
    }
    if (offline) {
      return _serveOffline(request, id, startMs);
    }
    if (chaosFail) {
      return _serveChaos(request, id, startMs);
    }
    final int reqBytes = utf8.encode(requestBody ?? '').length;
    final int preDelay = FChaosStore.instance.activeDelayMs +
        FChaosStore.instance.uploadDelayMs(reqBytes);
    if (preDelay > 0) {
      await Future<void>.delayed(Duration(milliseconds: preDelay));
    }

    try {
      final http.StreamedResponse response = await _inner.send(request);
      final List<int> bodyBytes = await response.stream.toBytes();
      final int extraDelay =
          FChaosStore.instance.downloadDelayMs(bodyBytes.length);
      if (extraDelay > 0) {
        await Future<void>.delayed(Duration(milliseconds: extraDelay));
      }
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

  Future<http.StreamedResponse> _serveMock(
    http.BaseRequest request,
    FMockRule mock,
    String id,
    int startMs,
  ) async {
    if (mock.delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: mock.delayMs));
    }

    final List<int> bodyBytes = mock.bodyBytes;
    final int durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
    final Map<String, String> headers = <String, String>{
      'content-type': mock.contentType,
    };

    String? responseBody;
    try {
      responseBody = utf8.decode(bodyBytes, allowMalformed: true);
    } catch (_) {}

    if (mock.statusCode >= 200 && mock.statusCode < 300) {
      FNetworkStore.instance.onSuccess(
        id,
        mock.statusCode,
        durationMs,
        responseHeaders: headers,
        responseBody: responseBody,
      );
    } else {
      FNetworkStore.instance.onError(
        id,
        mock.statusCode,
        _reasonPhrase(mock.statusCode),
        durationMs,
        responseBody: responseBody,
      );
    }

    return http.StreamedResponse(
      Stream<List<int>>.value(bodyBytes),
      mock.statusCode,
      headers: headers,
      reasonPhrase: _reasonPhrase(mock.statusCode),
      request: request,
      contentLength: bodyBytes.length,
    );
  }

  Future<http.StreamedResponse> _serveOffline(
    http.BaseRequest request,
    String id,
    int startMs,
  ) async {
    final FChaosStore chaos = FChaosStore.instance;
    if (chaos.activeDelayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: chaos.activeDelayMs));
    }
    final int durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
    FNetworkStore.instance.onError(
      id,
      null,
      'Chaos: offline (no connection)',
      durationMs,
    );
    throw http.ClientException(
      'No internet connection (chaos: offline profile)',
      request.url,
    );
  }

  Future<http.StreamedResponse> _serveChaos(
    http.BaseRequest request,
    String id,
    int startMs,
  ) async {
    final FChaosStore chaos = FChaosStore.instance;
    if (chaos.activeDelayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: chaos.activeDelayMs));
    }
    final int status = chaos.failStatus;
    final List<int> bodyBytes = utf8.encode(chaos.failBody);
    final int durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
    final Map<String, String> headers = <String, String>{
      'content-type': chaos.failContentType,
    };

    FNetworkStore.instance.onError(
      id,
      status,
      'Chaos: forced $status',
      durationMs,
      responseBody: chaos.failBody,
    );

    return http.StreamedResponse(
      Stream<List<int>>.value(bodyBytes),
      status,
      headers: headers,
      reasonPhrase: _reasonPhrase(status),
      request: request,
      contentLength: bodyBytes.length,
    );
  }

  String _reasonPhrase(int statusCode) {
    switch (statusCode) {
      case 200:
        return 'OK';
      case 201:
        return 'Created';
      case 204:
        return 'No Content';
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 409:
        return 'Conflict';
      case 422:
        return 'Unprocessable Entity';
      case 429:
        return 'Too Many Requests';
      case 500:
        return 'Internal Server Error';
      case 502:
        return 'Bad Gateway';
      case 503:
        return 'Service Unavailable';
      case 504:
        return 'Gateway Timeout';
      default:
        return 'Mock';
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
