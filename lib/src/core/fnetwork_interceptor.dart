import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_notification_service.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_store.dart';
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
  final FNetworkNotificationService _notifService =
      FNetworkNotificationService.instance;

  static const String _requestIdKey = 'fnetwork_inspector_request_id';
  static const String _startTimeKey = 'fnetwork_inspector_start_time';

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
        requestBody: _encodeBody(options.data),
      );

      _store.onRequest(log);
      if (_enableNotifications) {
        _notifService.showRequestLoading(log);
        _notifService.showSummary();
      }
    }

    handler.next(options);
  }

  @override
  // ignore: always_specify_types
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_enableInspection) {
      final String? requestId =
          response.requestOptions.extra[_requestIdKey] as String?;
      final int? startMs =
          response.requestOptions.extra[_startTimeKey] as int?;

      if (requestId != null && startMs != null) {
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
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_enableInspection) {
      final String? requestId =
          err.requestOptions.extra[_requestIdKey] as String?;
      final int? startMs = err.requestOptions.extra[_startTimeKey] as int?;

      if (requestId != null && startMs != null) {
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
    }

    handler.next(err);
  }

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
