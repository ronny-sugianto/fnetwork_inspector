import 'dart:collection';

import 'package:fnetwork_inspector/src/model/network_log.dart';

class FNetworkStore {
  FNetworkStore._();

  static final FNetworkStore instance = FNetworkStore._();

  static const int _maxLogs = 200;

  final LinkedHashMap<String, NetworkLog> _logs =
      LinkedHashMap<String, NetworkLog>();

  int _successCount = 0;
  int _errorCount = 0;
  String _latestEndpoint = '';

  UnmodifiableListView<NetworkLog> get logs =>
      UnmodifiableListView<NetworkLog>(_logs.values.toList().reversed.toList());

  int get loadingCount => _logs.values
      .where((NetworkLog l) => l.status == NetworkLogStatus.loading)
      .length;

  int get successCount => _successCount;
  int get errorCount => _errorCount;
  String get latestEndpoint => _latestEndpoint;

  void onRequest(NetworkLog log) {
    if (_logs.length >= _maxLogs) {
      _logs.remove(_logs.keys.first);
    }
    _logs[log.id] = log;
    _latestEndpoint = log.shortLabel;
  }

  void onSuccess(
    String id,
    int statusCode,
    int durationMs, {
    Map<String, dynamic>? responseHeaders,
    String? responseBody,
  }) {
    final NetworkLog? log = _logs[id];
    if (log == null) return;
    _logs[id] = log.copyWith(
      status: NetworkLogStatus.success,
      statusCode: statusCode,
      durationMs: durationMs,
      responseHeaders: responseHeaders,
      responseBody: responseBody,
    );
    _successCount++;
    _latestEndpoint = _logs[id]!.shortLabel;
  }

  void onError(
    String id,
    int? statusCode,
    String errorMessage,
    int durationMs, {
    String? responseBody,
  }) {
    final NetworkLog? log = _logs[id];
    if (log == null) return;
    _logs[id] = log.copyWith(
      status: NetworkLogStatus.error,
      statusCode: statusCode,
      durationMs: durationMs,
      errorMessage: errorMessage,
      responseBody: responseBody,
    );
    _errorCount++;
    _latestEndpoint = _logs[id]!.shortLabel;
  }

  NetworkLog? getLog(String id) => _logs[id];

  void clear() {
    _logs.clear();
    _successCount = 0;
    _errorCount = 0;
    _latestEndpoint = '';
  }
}
