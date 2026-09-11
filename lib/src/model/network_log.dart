import 'package:flutter/foundation.dart';

enum NetworkLogStatus { loading, success, error }

@immutable
class NetworkLog {
  const NetworkLog({
    required this.id,
    required this.method,
    required this.path,
    required this.baseUrl,
    required this.status,
    required this.startTime,
    this.requestHeaders,
    this.requestBody,
    this.statusCode,
    this.responseHeaders,
    this.responseBody,
    this.durationMs,
    this.errorMessage,
    this.isMocked = false,
    this.isChaos = false,
  });

  final String id;
  final String method;
  final String path;
  final String baseUrl;
  final NetworkLogStatus status;
  final DateTime startTime;
  final Map<String, dynamic>? requestHeaders;
  final String? requestBody;
  final int? statusCode;
  final Map<String, dynamic>? responseHeaders;
  final String? responseBody;
  final int? durationMs;
  final String? errorMessage;

  /// True when this entry was served from an [FMockRule] instead of the network.
  final bool isMocked;

  /// True when chaos mode forced this request to fail.
  final bool isChaos;

  NetworkLog copyWith({
    NetworkLogStatus? status,
    int? statusCode,
    Map<String, dynamic>? responseHeaders,
    String? responseBody,
    int? durationMs,
    String? errorMessage,
  }) {
    return NetworkLog(
      id: id,
      method: method,
      path: path,
      baseUrl: baseUrl,
      status: status ?? this.status,
      startTime: startTime,
      requestHeaders: requestHeaders,
      requestBody: requestBody,
      statusCode: statusCode ?? this.statusCode,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
      durationMs: durationMs ?? this.durationMs,
      errorMessage: errorMessage ?? this.errorMessage,
      isMocked: isMocked,
      isChaos: isChaos,
    );
  }

  String get shortLabel => '$method $path';

  String get statusLabel {
    switch (status) {
      case NetworkLogStatus.loading:
        return 'Requesting...';
      case NetworkLogStatus.success:
        return '$statusCode OK • ${durationMs}ms';
      case NetworkLogStatus.error:
        return statusCode != null
            ? '$statusCode ${errorMessage ?? 'Error'}'
            : errorMessage ?? 'Error';
    }
  }
}