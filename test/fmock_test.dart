import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fnetwork_inspector/fnetwork_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    FMockStore.instance
      ..reset()
      ..enabled = true;
    FNetworkStore.instance.clear();
  });

  group('FMockRule.matches', () {
    test('substring match, any method', () {
      final FMockRule r = FMockRule.create(pathPattern: '/users');
      expect(r.matches('GET', '/api/users/42'), isTrue);
      expect(r.matches('POST', '/api/users'), isTrue);
      expect(r.matches('GET', '/api/orders'), isFalse);
    });

    test('method filter is case-insensitive', () {
      final FMockRule r =
          FMockRule.create(pathPattern: '/users', method: 'post');
      expect(r.matches('POST', '/users'), isTrue);
      expect(r.matches('GET', '/users'), isFalse);
    });

    test('glob pattern is anchored', () {
      final FMockRule r = FMockRule.create(pathPattern: '/api/*/profile');
      expect(r.matches('GET', '/api/v1/profile'), isTrue);
      expect(r.matches('GET', '/api/v1/x/profile'), isTrue);
      expect(r.matches('GET', '/api/v1/profile/extra'), isFalse);
    });

    test('query string is ignored', () {
      final FMockRule r = FMockRule.create(pathPattern: '/search');
      expect(r.matches('GET', '/search?q=hello&page=2'), isTrue);
    });

    test('disabled rule never matches', () {
      final FMockRule r =
          FMockRule.create(pathPattern: '/users', enabled: false);
      expect(r.matches('GET', '/users'), isFalse);
    });
  });

  group('FMockRule.bodyBytes', () {
    test('text body is utf8 encoded', () {
      final FMockRule r = FMockRule.create(pathPattern: '/x', body: 'héllo');
      expect(r.bodyBytes, utf8.encode('héllo'));
    });

    test('base64 body is decoded', () {
      final String b64 = base64.encode(<int>[1, 2, 3, 250]);
      final FMockRule r =
          FMockRule.create(pathPattern: '/x', body: b64, isBase64: true);
      expect(r.bodyBytes, <int>[1, 2, 3, 250]);
    });

    test('invalid base64 resolves to empty', () {
      final FMockRule r = FMockRule.create(
        pathPattern: '/x',
        body: 'not valid base64 !!!',
        isBase64: true,
      );
      expect(r.bodyBytes, isEmpty);
    });
  });

  group('FMockStore', () {
    test('master switch disables matching', () {
      FMockStore.instance.add(FMockRule.create(pathPattern: '/users'));
      expect(FMockStore.instance.match('GET', '/users'), isNotNull);
      FMockStore.instance.enabled = false;
      expect(FMockStore.instance.match('GET', '/users'), isNull);
      expect(FMockStore.instance.activeCount, 0);
    });

    test('toggle flips enabled', () {
      FMockStore.instance.add(FMockRule.create(pathPattern: '/a'));
      final String id = FMockStore.instance.rules.first.id;
      FMockStore.instance.toggle(id);
      expect(FMockStore.instance.rules.first.enabled, isFalse);
      expect(FMockStore.instance.match('GET', '/a'), isNull);
    });

    test('ruleFor ignores enabled flags, match respects them', () {
      FMockStore.instance.add(
        FMockRule.create(pathPattern: '/users', enabled: false),
      );
      expect(FMockStore.instance.match('GET', '/users'), isNull);
      expect(FMockStore.instance.ruleFor('GET', '/users'), isNotNull);

      FMockStore.instance.enabled = false;
      expect(FMockStore.instance.ruleFor('GET', '/users'), isNotNull);
    });

    test('first matching rule wins', () {
      FMockStore.instance.add(FMockRule.create(
        pathPattern: '/a',
        statusCode: 500,
      ));
      FMockStore.instance.add(FMockRule.create(
        pathPattern: '/a',
        statusCode: 200,
      ));
      // add() inserts at the front, so the 200 rule was added last / is first.
      expect(FMockStore.instance.match('GET', '/a')!.statusCode, 200);
    });
  });

  group('scenarios', () {
    test('save / apply / detach', () {
      FMockStore.instance.add(FMockRule.create(pathPattern: '/a'));
      FMockStore.instance.add(FMockRule.create(pathPattern: '/b'));
      final FMockScenario s = FMockStore.instance.saveAsScenario('two rules');
      expect(FMockStore.instance.activeScenarioId, s.id);
      expect(s.rules.length, 2);

      FMockStore.instance.clear();
      expect(FMockStore.instance.rules, isEmpty);

      FMockStore.instance.applyScenario(s.id);
      expect(FMockStore.instance.rules.length, 2);
      expect(FMockStore.instance.activeScenario?.name, 'two rules');

      FMockStore.instance.detachScenario();
      expect(FMockStore.instance.activeScenarioId, isNull);
      expect(FMockStore.instance.rules.length, 2);
    });

    test('saveAsScenario overwrites a scenario with the same name', () {
      FMockStore.instance.add(FMockRule.create(pathPattern: '/a'));
      FMockStore.instance.saveAsScenario('dupe');
      FMockStore.instance
        ..add(FMockRule.create(pathPattern: '/b'))
        ..saveAsScenario('dupe');
      expect(FMockStore.instance.scenarios.length, 1);
      expect(FMockStore.instance.scenarios.first.rules.length, 2);
    });

    test('exportJson / importJson round-trips rules, scenarios and flags', () {
      FMockStore.instance
        ..add(FMockRule.create(pathPattern: '/x', statusCode: 418))
        ..saveAsScenario('teapot')
        ..enabled = false;
      final String json = FMockStore.instance.exportJson();
      expect(json, contains('rons.my.id'));

      FMockStore.instance.reset();
      FMockStore.instance.enabled = true;
      FMockStore.instance.importJson(json);

      expect(FMockStore.instance.enabled, isFalse);
      expect(FMockStore.instance.rules.single.statusCode, 418);
      expect(FMockStore.instance.scenarios.single.name, 'teapot');
      expect(FMockStore.instance.activeScenario?.name, 'teapot');
    });

    test('importJson accepts a bare array of rules', () {
      FMockStore.instance.importJson(
        jsonEncode(<dynamic>[
          FMockRule.create(pathPattern: '/one').toJson(),
          FMockRule.create(pathPattern: '/two').toJson(),
        ]),
      );
      expect(FMockStore.instance.rules.length, 2);
    });
  });

  group('persistence', () {
    test('attachPersistence hydrates from load and saves on change', () async {
      final _MemPersistence mem = _MemPersistence();
      FMockStore.instance.add(FMockRule.create(pathPattern: '/seed'));
      mem.data = FMockStore.instance.exportJson();
      FMockStore.instance.reset();

      await FMockStore.instance.attachPersistence(mem);
      expect(FMockStore.instance.rules.single.pathPattern, '/seed');

      FMockStore.instance.add(FMockRule.create(pathPattern: '/added'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(mem.data, contains('/added'));
    });
  });

  group('Dio interceptor', () {
    Dio buildDio() {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.interceptors.add(FNetworkDioInterceptor(enableInspection: true));
      // Fail loudly if a request ever escapes to the network.
      dio.httpClientAdapter = _ThrowingAdapter();
      return dio;
    }

    test('serves a JSON mock without hitting the network', () async {
      FMockStore.instance.add(FMockRule.create(
        method: 'GET',
        pathPattern: '/ping',
        statusCode: 200,
        contentType: 'application/json',
        body: '{"pong": true}',
      ));

      final Response<dynamic> res = await buildDio().get<dynamic>('/ping');

      expect(res.statusCode, 200);
      expect(res.data, <String, dynamic>{'pong': true});
      final NetworkLog log = FNetworkStore.instance.logs.first;
      expect(log.isMocked, isTrue);
      expect(log.status, NetworkLogStatus.success);
    });

    test('non-2xx mock throws DioException', () async {
      FMockStore.instance.add(FMockRule.create(
        pathPattern: '/boom',
        statusCode: 503,
        contentType: 'text/plain',
        body: 'unavailable',
      ));

      await expectLater(
        buildDio().get<dynamic>('/boom'),
        throwsA(isA<DioException>().having(
          (DioException e) => e.response?.statusCode,
          'statusCode',
          503,
        )),
      );
      expect(FNetworkStore.instance.logs.first.status, NetworkLogStatus.error);
    });

    test('applies the configured delay', () async {
      FMockStore.instance.add(FMockRule.create(
        pathPattern: '/slow',
        body: 'ok',
        contentType: 'text/plain',
        delayMs: 200,
      ));

      final Stopwatch sw = Stopwatch()..start();
      await buildDio().get<dynamic>('/slow');
      sw.stop();
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(150));
    });
  });

  group('http interceptor', () {
    test('serves a mock and never calls the inner client', () async {
      FMockStore.instance.add(FMockRule.create(
        pathPattern: '/thing',
        statusCode: 201,
        contentType: 'application/json',
        body: '{"created": 1}',
      ));

      bool innerCalled = false;
      final FNetworkHttpInterceptor client = FNetworkHttpInterceptor(
        inner: MockClient((http.Request _) async {
          innerCalled = true;
          return http.Response('should not happen', 500);
        }),
      );

      final http.Response res =
          await client.get(Uri.parse('https://example.com/thing'));

      expect(innerCalled, isFalse);
      expect(res.statusCode, 201);
      expect(res.body, '{"created": 1}');
      expect(FNetworkStore.instance.logs.first.isMocked, isTrue);
    });

    test('base64 mock is served as raw bytes', () async {
      final List<int> bytes = <int>[0, 1, 2, 3, 200, 255];
      FMockStore.instance.add(FMockRule.create(
        pathPattern: '/file.bin',
        contentType: 'application/octet-stream',
        body: base64.encode(bytes),
        isBase64: true,
      ));

      final FNetworkHttpInterceptor client = FNetworkHttpInterceptor(
        inner: MockClient((http.Request _) async => http.Response('', 500)),
      );

      final http.Response res =
          await client.get(Uri.parse('https://example.com/file.bin'));

      expect(res.bodyBytes, bytes);
    });
  });
}

class _MemPersistence implements FMockPersistence {
  String? data;

  @override
  Future<String?> load() async => data;

  @override
  Future<void> save(String json) async => data = json;
}

/// Dio adapter that throws if any request reaches it — proves mocks
/// short-circuit before the network layer.
class _ThrowingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw StateError('network was hit for ${options.uri} — mock did not apply');
  }
}
