import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fnetwork_inspector/src/core/fchaos_store.dart';
import 'package:fnetwork_inspector/src/core/fmock_store.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_notification_service.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_store.dart';
import 'package:fnetwork_inspector/src/model/fmock_rule.dart';
import 'package:fnetwork_inspector/src/model/network_log.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class FNetworkDioInterceptor extends Interceptor {
  FNetworkDioInterceptor({
    bool enableInspection = true,
    bool enableNotifications = false,
  })  : _enableInspection = enableInspection,
        _enableNotifications = enableNotifications && !kIsWeb;

  final bool _enableInspection;
  final bool _enableNotifications;

  final FNetworkStore _store = FNetworkStore.instance;
  final FMockStore _mockStore = FMockStore.instance;
  final FChaosStore _chaos = FChaosStore.instance;
  final FNetworkNotificationService _notifService =
      FNetworkNotificationService.instance;

  static const String _requestIdKey = 'fnetwork_inspector_request_id';
  static const String _startTimeKey = 'fnetwork_inspector_start_time';
  static const String _mockKey = 'fnetwork_inspector_mock';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_enableInspection) {
      final String requestId = const Uuid().v4();
      final int startMs = DateTime.now().millisecondsSinceEpoch;

      options.extra[_requestIdKey] = requestId;
      options.extra[_startTimeKey] = startMs;

      final String fullUrl = options.uri.toString();
      final String path = _extractPath(fullUrl);
      final String baseUrl = _extractBaseUrl(fullUrl);

      final FMockRule? mock = _mockStore.match(options.method, path);
      final bool offline = mock == null && _chaos.isOffline;
      final bool chaosFail = mock == null && !offline && _chaos.shouldFail();

      final String? requestBody = _encodeBody(options.data);

      final NetworkLog log = NetworkLog(
        id: requestId,
        method: options.method,
        path: path,
        baseUrl: baseUrl,
        status: NetworkLogStatus.loading,
        startTime: DateTime.fromMillisecondsSinceEpoch(startMs),
        requestHeaders: options.headers.map(
          (String k, dynamic v) => MapEntry<String, dynamic>(k, v.toString()),
        ),
        requestBody: requestBody,
        isMocked: mock != null,
        isChaos: chaosFail || offline,
      );

      _store.onRequest(log);
      if (_enableNotifications) {
        _notifService.showRequestLoading(log);
        _notifService.showSummary();
      }

      if (mock != null) {
        _resolveMock(options, handler, mock, requestId, startMs);
        return;
      }
      if (offline) {
        _resolveOffline(options, handler, requestId, startMs);
        return;
      }
      if (chaosFail) {
        _resolveChaos(options, handler, requestId, startMs);
        return;
      }
      final int preDelay = _chaos.activeDelayMs +
          _chaos.uploadDelayMs(_byteLength(requestBody));
      if (preDelay > 0) {
        Future<void>.delayed(
          Duration(milliseconds: preDelay),
          () => handler.next(options),
        );
        return;
      }
    }

    handler.next(options);
  }

  void _resolveOffline(
    RequestOptions options,
    RequestInterceptorHandler handler,
    String requestId,
    int startMs,
  ) {
    Future<void>.delayed(Duration(milliseconds: _chaos.activeDelayMs), () {
      options.extra[_mockKey] = true;
      final int durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
      _store.onError(
        requestId,
        null,
        'Chaos: offline (no connection)',
        durationMs,
      );
      if (_enableNotifications) {
        final NetworkLog? log = _store.getLog(requestId);
        if (log != null) {
          _notifService.showRequestError(log);
          _notifService.showSummary();
        }
      }
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'No internet connection (chaos: offline profile)',
        ),
        true,
      );
    });
  }

  void _resolveChaos(
    RequestOptions options,
    RequestInterceptorHandler handler,
    String requestId,
    int startMs,
  ) {
    final int status = _chaos.failStatus;
    final String body = _chaos.failBody;
    final String contentType = _chaos.failContentType;
    Future<void>.delayed(Duration(milliseconds: _chaos.activeDelayMs), () {
      options.extra[_mockKey] = true;
      dynamic data = body;
      if (contentType.toLowerCase().contains('json')) {
        try {
          data = jsonDecode(body);
        } catch (_) {
          data = body;
        }
      }
      final Response<dynamic> response = Response<dynamic>(
        requestOptions: options,
        statusCode: status,
        statusMessage: _reasonPhrase(status),
        data: data,
        headers: Headers.fromMap(<String, List<String>>{
          Headers.contentTypeHeader: <String>[contentType],
        }),
        extra: <String, dynamic>{_mockKey: true},
      );
      final int durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
      _store.onError(
        requestId,
        status,
        'Chaos: forced $status',
        durationMs,
        responseBody: body,
      );
      if (_enableNotifications) {
        final NetworkLog? log = _store.getLog(requestId);
        if (log != null) {
          _notifService.showRequestError(log);
          _notifService.showSummary();
        }
      }
      handler.reject(
        DioException(
          requestOptions: options,
          response: response,
          type: DioExceptionType.badResponse,
        ),
        true,
      );
    });
  }

  void _resolveMock(
    RequestOptions options,
    RequestInterceptorHandler handler,
    FMockRule mock,
    String requestId,
    int startMs,
  ) {
    final int delay = mock.delayMs < 0 ? 0 : mock.delayMs;
    Future<void>.delayed(Duration(milliseconds: delay), () {
      options.extra[_mockKey] = true;
      final Response<dynamic> response = _buildMockResponse(options, mock);
      final int durationMs = DateTime.now().millisecondsSinceEpoch - startMs;

      final Map<String, dynamic> responseHeaders = <String, dynamic>{};
      response.headers.forEach(
        (String name, List<String> values) =>
            responseHeaders[name] = values.join(', '),
      );
      final String? responseBody = _encodeBody(response.data);

      if (options.validateStatus(mock.statusCode)) {
        _store.onSuccess(
          requestId,
          mock.statusCode,
          durationMs,
          responseHeaders: responseHeaders,
          responseBody: responseBody,
        );
        if (_enableNotifications) {
          final NetworkLog? log = _store.getLog(requestId);
          if (log != null) {
            _notifService.showRequestSuccess(log);
            _notifService.showSummary();
          }
        }
        handler.resolve(response, true);
      } else {
        _store.onError(
          requestId,
          mock.statusCode,
          _reasonPhrase(mock.statusCode),
          durationMs,
          responseBody: responseBody,
        );
        if (_enableNotifications) {
          final NetworkLog? log = _store.getLog(requestId);
          if (log != null) {
            _notifService.showRequestError(log);
            _notifService.showSummary();
          }
        }
        handler.reject(
          DioException(
            requestOptions: options,
            response: response,
            type: DioExceptionType.badResponse,
          ),
          true,
        );
      }
    });
  }

  Response<dynamic> _buildMockResponse(RequestOptions options, FMockRule mock) {
    final String ct = mock.contentType.toLowerCase();
    dynamic data;
    if (mock.isBase64) {
      data = Uint8List.fromList(mock.bodyBytes);
    } else if (ct.contains('json')) {
      try {
        data = jsonDecode(mock.body);
      } catch (_) {
        data = mock.body;
      }
    } else {
      data = mock.body;
    }

    return Response<dynamic>(
      requestOptions: options,
      statusCode: mock.statusCode,
      statusMessage: _reasonPhrase(mock.statusCode),
      data: data,
      headers: Headers.fromMap(<String, List<String>>{
        Headers.contentTypeHeader: <String>[mock.contentType],
      }),
      extra: <String, dynamic>{_mockKey: true},
    );
  }

  String _reasonPhrase(int statusCode) {
    switch (statusCode) {
      case 200:
        return 'OK';
      case 201:
        return 'Created';
      case 202:
        return 'Accepted';
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
  // ignore: always_specify_types
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_enableInspection &&
        response.requestOptions.extra[_mockKey] != true) {
      final String? requestId =
          response.requestOptions.extra[_requestIdKey] as String?;
      final int? startMs =
          response.requestOptions.extra[_startTimeKey] as int?;

      if (requestId != null && startMs != null) {
        final int extraDelay =
            _chaos.downloadDelayMs(_byteLength(_encodeBody(response.data)));
        if (extraDelay > 0) {
          Future<void>.delayed(Duration(milliseconds: extraDelay), () {
            _completeSuccess(requestId, startMs, response);
            handler.next(response);
          });
          return;
        }
        _completeSuccess(requestId, startMs, response);
      }
    }

    handler.next(response);
  }

  void _completeSuccess(
    String requestId,
    int startMs,
    // ignore: always_specify_types
    Response response,
  ) {
    final int durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
    final Map<String, dynamic> responseHeaders = <String, dynamic>{};
    response.headers.forEach(
      (String name, List<String> values) =>
          responseHeaders[name] = values.join(', '),
    );
    _store.onSuccess(
      requestId,
      response.statusCode ?? 200,
      durationMs,
      responseHeaders: responseHeaders,
      responseBody: _encodeBody(response.data),
    );
    if (_enableNotifications) {
      final NetworkLog? log = _store.getLog(requestId);
      if (log != null) {
        _notifService.showRequestSuccess(log);
        _notifService.showSummary();
      }
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_enableInspection && err.requestOptions.extra[_mockKey] != true) {
      final String? requestId =
          err.requestOptions.extra[_requestIdKey] as String?;
      final int? startMs = err.requestOptions.extra[_startTimeKey] as int?;

      if (requestId != null && startMs != null) {
        final int extraDelay = err.response != null
            ? _chaos.downloadDelayMs(_byteLength(_encodeBody(err.response!.data)))
            : 0;
        if (extraDelay > 0) {
          Future<void>.delayed(Duration(milliseconds: extraDelay), () {
            _completeError(requestId, startMs, err);
            handler.next(err);
          });
          return;
        }
        _completeError(requestId, startMs, err);
      }
    }

    handler.next(err);
  }

  void _completeError(String requestId, int startMs, DioException err) {
    final int durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
    final int? statusCode = err.response?.statusCode;
    final String errorMessage = _extractErrorMessage(err);

    _store.onError(
      requestId,
      statusCode,
      errorMessage,
      durationMs,
      responseBody: err.response?.data != null
          ? _encodeBody(err.response!.data)
          : null,
    );

    if (_enableNotifications) {
      final NetworkLog? log = _store.getLog(requestId);
      if (log != null) {
        _notifService.showRequestError(log);
        _notifService.showSummary();
      }
    }
  }

  int _byteLength(String? s) => s == null ? 0 : utf8.encode(s).length;

  String _extractPath(String fullUrl) {
    try {
      final Uri uri = Uri.parse(fullUrl);
      String path = uri.path;
      if (uri.query.isNotEmpty) path = '$path?${uri.query}';
      return path.isEmpty ? '/' : path;
    } catch (_) {
      return fullUrl;
    }
  }

  String _extractBaseUrl(String fullUrl) {
    try {
      final Uri uri = Uri.parse(fullUrl);
      return '${uri.scheme}://${uri.host}'
          '${uri.port != 80 && uri.port != 443 && uri.port != -1 ? ':${uri.port}' : ''}';
    } catch (_) {
      return '';
    }
  }

  String? _encodeBody(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  String _extractErrorMessage(DioException err) {
    if (err.response?.statusCode != null) {
      return err.response?.statusMessage ?? 'Error';
    }
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Timeout';
      case DioExceptionType.cancel:
        return 'Cancelled';
      default:
        return err.message ?? 'Network Error';
    }
  }
}
