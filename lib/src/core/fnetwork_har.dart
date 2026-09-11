import 'dart:convert';

import 'package:fnetwork_inspector/src/core/fnetwork_meta.dart';
import 'package:fnetwork_inspector/src/model/network_log.dart';

/// Builds a [HAR 1.2](http://www.softwareishard.com/blog/har-12-spec/) archive
/// from captured [NetworkLog]s. The output can be imported into Chrome
/// DevTools, Charles, Proxyman, Postman, etc.
class FNetworkHar {
  FNetworkHar._();

  static const String _version = '0.4.0';

  /// Serialises [logs] to a pretty-printed HAR JSON string.
  ///
  /// Entries are sorted oldest-first (per the spec). Requests that are still
  /// in flight ([NetworkLogStatus.loading]) are omitted.
  static String export(
    Iterable<NetworkLog> logs, {
    String creatorName = 'fnetwork_inspector',
    String creatorVersion = _version,
  }) {
    final List<NetworkLog> sorted = logs
        .where((NetworkLog l) => l.status != NetworkLogStatus.loading)
        .toList()
      ..sort((NetworkLog a, NetworkLog b) => a.startTime.compareTo(b.startTime));

    final Map<String, dynamic> har = <String, dynamic>{
      'log': <String, dynamic>{
        'version': '1.2',
        'creator': <String, dynamic>{
          'name': creatorName,
          'version': creatorVersion,
          'comment': kFNetworkInspectorUrl,
        },
        'comment': kFNetworkInspectorCreditLine,
        'entries': sorted.map(_entry).toList(),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(har);
  }

  static Map<String, dynamic> _entry(NetworkLog log) {
    final int time = log.durationMs ?? 0;
    final String reqBody = log.requestBody ?? '';
    final String resBody = log.responseBody ?? '';

    final Map<String, dynamic> request = <String, dynamic>{
      'method': log.method,
      'url': '${log.baseUrl}${log.path}',
      'httpVersion': 'HTTP/1.1',
      'headers': _headers(log.requestHeaders),
      'queryString': _queryString(log.path),
      'cookies': const <dynamic>[],
      'headersSize': -1,
      'bodySize': reqBody.length,
    };
    if (reqBody.isNotEmpty) {
      request['postData'] = <String, dynamic>{
        'mimeType': _mimeType(log.requestHeaders) ?? 'application/json',
        'text': reqBody,
      };
    }

    final Map<String, dynamic> response = <String, dynamic>{
      'status': log.statusCode ?? 0,
      'statusText': log.errorMessage ?? '',
      'httpVersion': 'HTTP/1.1',
      'headers': _headers(log.responseHeaders),
      'cookies': const <dynamic>[],
      'content': <String, dynamic>{
        'size': resBody.length,
        'mimeType': _mimeType(log.responseHeaders) ?? 'text/plain',
        'text': resBody,
      },
      'redirectURL': '',
      'headersSize': -1,
      'bodySize': resBody.length,
    };

    return <String, dynamic>{
      'startedDateTime': log.startTime.toUtc().toIso8601String(),
      'time': time,
      'request': request,
      'response': response,
      'cache': const <String, dynamic>{},
      'timings': <String, dynamic>{'send': 0, 'wait': time, 'receive': 0},
      if (log.isMocked) '_mocked': true,
      if (log.isChaos) '_chaos': true,
      if (log.errorMessage != null) '_error': log.errorMessage,
    };
  }

  static List<Map<String, String>> _headers(Map<String, dynamic>? headers) {
    if (headers == null) return <Map<String, String>>[];
    return headers.entries
        .map(
          (MapEntry<String, dynamic> e) => <String, String>{
            'name': e.key,
            'value': e.value.toString(),
          },
        )
        .toList();
  }

  static String? _mimeType(Map<String, dynamic>? headers) {
    if (headers == null) return null;
    for (final MapEntry<String, dynamic> e in headers.entries) {
      if (e.key.toLowerCase() == 'content-type') {
        return e.value.toString().split(';').first.trim();
      }
    }
    return null;
  }

  static List<Map<String, String>> _queryString(String path) {
    final int q = path.indexOf('?');
    if (q == -1 || q == path.length - 1) return <Map<String, String>>[];
    final Map<String, String> params =
        Uri.splitQueryString(path.substring(q + 1));
    return params.entries
        .map(
          (MapEntry<String, String> e) => <String, String>{
            'name': e.key,
            'value': e.value,
          },
        )
        .toList();
  }
}
