import 'dart:collection';

import 'package:fnetwork_inspector/src/model/network_log.dart';
import 'package:flutter/foundation.dart';

typedef FNetworkErrorCallback = void Function(NetworkLog log);

class FNetworkStore with ChangeNotifier {
  FNetworkStore._();

  static final FNetworkStore instance = FNetworkStore._();

  int _maxLogs = 200;

  /// Maximum number of logs kept in memory; the oldest are evicted first.
  int get maxLogs => _maxLogs;
  set maxLogs(int value) {
    _maxLogs = value < 1 ? 1 : value;
    _trim();
    _changed();
  }

  final LinkedHashMap<String, NetworkLog> _logs =
      LinkedHashMap<String, NetworkLog>();

  // Snapshot cache, invalidated on every change — the UI reads `logs` and the
  // counts several times per build.
  List<NetworkLog>? _snapshot;
  int _loading = 0;
  int _success = 0;
  int _error = 0;

  String _latestEndpoint = '';

  FNetworkErrorCallback? onApiError;

  /// Newest first.
  UnmodifiableListView<NetworkLog> get logs =>
      UnmodifiableListView<NetworkLog>(_ensureSnapshot());

  int get loadingCount {
    _ensureSnapshot();
    return _loading;
  }

  int get successCount {
    _ensureSnapshot();
    return _success;
  }

  int get errorCount {
    _ensureSnapshot();
    return _error;
  }

  List<NetworkLog> _ensureSnapshot() {
    final List<NetworkLog>? cached = _snapshot;
    if (cached != null) return cached;
    int loading = 0;
    int success = 0;
    int error = 0;
    for (final NetworkLog l in _logs.values) {
      switch (l.status) {
        case NetworkLogStatus.loading:
          loading++;
        case NetworkLogStatus.success:
          success++;
        case NetworkLogStatus.error:
          error++;
      }
    }
    _loading = loading;
    _success = success;
    _error = error;
    return _snapshot = _logs.values.toList().reversed.toList();
  }

  void _trim() {
    while (_logs.length > _maxLogs) {
      _logs.remove(_logs.keys.first);
    }
  }

  void _changed() {
    _snapshot = null;
    notifyListeners();
  }

  String get latestEndpoint => _latestEndpoint;

  void onRequest(NetworkLog log) {
    _logs[log.id] = log;
    _trim();
    _latestEndpoint = log.shortLabel;
    _changed();
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
    _latestEndpoint = _logs[id]!.shortLabel;
    _changed();
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
    _latestEndpoint = _logs[id]!.shortLabel;
    onApiError?.call(_logs[id]!);
    _changed();
  }

  NetworkLog? getLog(String id) => _logs[id];

  void clear() {
    _logs.clear();
    _latestEndpoint = '';
    _changed();
  }
}
