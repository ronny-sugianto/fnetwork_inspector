import 'dart:convert';

import 'package:fnetwork_inspector/fnetwork_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

NetworkLog _log({
  required String id,
  required NetworkLogStatus status,
  String method = 'GET',
  String path = '/x',
  String baseUrl = 'https://api.example.com',
  DateTime? startTime,
  Map<String, dynamic>? requestHeaders,
  String? requestBody,
  int? statusCode,
  Map<String, dynamic>? responseHeaders,
  String? responseBody,
  int? durationMs,
  String? errorMessage,
  bool isMocked = false,
}) {
  return NetworkLog(
    id: id,
    method: method,
    path: path,
    baseUrl: baseUrl,
    status: status,
    startTime: startTime ?? DateTime.utc(2026, 1, 1),
    requestHeaders: requestHeaders,
    requestBody: requestBody,
    statusCode: statusCode,
    responseHeaders: responseHeaders,
    responseBody: responseBody,
    durationMs: durationMs,
    errorMessage: errorMessage,
    isMocked: isMocked,
  );
}

void main() {
  test('produces a valid HAR 1.2 skeleton', () {
    final Map<String, dynamic> har = jsonDecode(FNetworkHar.export(<NetworkLog>[]))
        as Map<String, dynamic>;
    final Map<String, dynamic> log = har['log'] as Map<String, dynamic>;
    expect(log['version'], '1.2');
    expect((log['creator'] as Map<String, dynamic>)['name'], 'fnetwork_inspector');
    expect(log['comment'], contains('rons.my.id'));
    expect(log['entries'], isEmpty);
  });

  test('skips in-flight requests and sorts oldest-first', () {
    final String out = FNetworkHar.export(<NetworkLog>[
      _log(
        id: 'b',
        status: NetworkLogStatus.success,
        statusCode: 200,
        startTime: DateTime.utc(2026, 1, 1, 0, 0, 2),
      ),
      _log(id: 'loading', status: NetworkLogStatus.loading),
      _log(
        id: 'a',
        status: NetworkLogStatus.success,
        statusCode: 200,
        startTime: DateTime.utc(2026, 1, 1, 0, 0, 1),
      ),
    ]);
    final List<dynamic> entries =
        (jsonDecode(out) as Map<String, dynamic>)['log']['entries'] as List<dynamic>;
    expect(entries.length, 2);
    expect(entries.first['startedDateTime'], '2026-01-01T00:00:01.000Z');
  });

  test('maps request/response fields, query string and custom flags', () {
    final String out = FNetworkHar.export(<NetworkLog>[
      _log(
        id: 'x',
        method: 'POST',
        path: '/users?page=2&q=ada',
        status: NetworkLogStatus.success,
        statusCode: 201,
        durationMs: 42,
        requestHeaders: <String, dynamic>{'Content-Type': 'application/json'},
        requestBody: '{"name":"ada"}',
        responseHeaders: <String, dynamic>{
          'content-type': 'application/json; charset=utf-8',
        },
        responseBody: '{"id":1}',
        isMocked: true,
      ),
    ]);
    final Map<String, dynamic> entry =
        ((jsonDecode(out) as Map<String, dynamic>)['log']['entries']
            as List<dynamic>)[0] as Map<String, dynamic>;

    final Map<String, dynamic> req = entry['request'] as Map<String, dynamic>;
    expect(req['method'], 'POST');
    expect(req['url'], 'https://api.example.com/users?page=2&q=ada');
    expect(req['postData']['text'], '{"name":"ada"}');
    expect(req['postData']['mimeType'], 'application/json');
    expect(
      (req['queryString'] as List<dynamic>).map((dynamic e) => e['name']),
      containsAll(<String>['page', 'q']),
    );

    final Map<String, dynamic> res = entry['response'] as Map<String, dynamic>;
    expect(res['status'], 201);
    expect(res['content']['text'], '{"id":1}');
    expect(res['content']['mimeType'], 'application/json');

    expect(entry['time'], 42);
    expect(entry['_mocked'], true);
  });

  test('network error without a status code becomes status 0 with _error', () {
    final String out = FNetworkHar.export(<NetworkLog>[
      _log(
        id: 'e',
        status: NetworkLogStatus.error,
        errorMessage: 'Connection refused',
      ),
    ]);
    final Map<String, dynamic> entry =
        ((jsonDecode(out) as Map<String, dynamic>)['log']['entries']
            as List<dynamic>)[0] as Map<String, dynamic>;
    expect((entry['response'] as Map<String, dynamic>)['status'], 0);
    expect(entry['_error'], 'Connection refused');
  });
}
