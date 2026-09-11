import 'dart:math';

import 'package:dio/dio.dart';
import 'package:fnetwork_inspector/fnetwork_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    FChaosStore.instance
      ..reset()
      ..random = _FixedRandom(0.0);
    FMockStore.instance.reset();
    FNetworkStore.instance.clear();
  });

  tearDown(() => FChaosStore.instance.reset());

  group('FChaosStore', () {
    test('shouldFail needs enabled + rate + roll under rate', () {
      final FChaosStore c = FChaosStore.instance..random = _FixedRandom(0.5);
      c.failRate = 0.8;
      expect(c.shouldFail(), isFalse, reason: 'disabled');
      c.enabled = true;
      expect(c.shouldFail(), isTrue, reason: '0.5 < 0.8');
      c.failRate = 0.2;
      expect(c.shouldFail(), isFalse, reason: '0.5 >= 0.2');
    });

    test('activeDelayMs is zero unless enabled', () {
      final FChaosStore c = FChaosStore.instance..latencyMs = 300;
      expect(c.activeDelayMs, 0);
      c.enabled = true;
      expect(c.activeDelayMs, 300);
    });

    test('failRate clamps to 0..1', () {
      final FChaosStore c = FChaosStore.instance
        ..failRate = 5
        ..enabled = true;
      expect(c.failRate, 1.0);
      c.failRate = -1;
      expect(c.failRate, 0.0);
    });
  });

  group('FNetworkProfile presets', () {
    test('applyProfile sets latency + bandwidth from the preset', () {
      final FChaosStore c = FChaosStore.instance
        ..applyProfile(FNetworkProfile.threeG);
      expect(c.profile, FNetworkProfile.threeG);
      expect(c.latencyMs, 150);
      expect(c.downloadKbps, 1000);
      expect(c.uploadKbps, 500);
    });

    test('applyProfile(none) clears bandwidth throttling', () {
      final FChaosStore c = FChaosStore.instance
        ..applyProfile(FNetworkProfile.fourG)
        ..applyProfile(FNetworkProfile.none);
      expect(c.profile, FNetworkProfile.none);
      expect(c.downloadKbps, 0);
      expect(c.uploadKbps, 0);
    });

    test('manually editing latency or bandwidth marks the profile custom', () {
      final FChaosStore c = FChaosStore.instance
        ..applyProfile(FNetworkProfile.fourG);
      c.latencyMs = 999;
      expect(c.profile, FNetworkProfile.none);

      c.applyProfile(FNetworkProfile.fourG);
      c.downloadKbps = 1;
      expect(c.profile, FNetworkProfile.none);
    });

    test('isOffline requires both enabled and the offline profile', () {
      final FChaosStore c = FChaosStore.instance
        ..applyProfile(FNetworkProfile.offline);
      expect(c.isOffline, isFalse, reason: 'not enabled yet');
      c.enabled = true;
      expect(c.isOffline, isTrue);
    });

    test('uploadDelayMs / downloadDelayMs estimate from payload size', () {
      final FChaosStore c = FChaosStore.instance
        ..enabled = true
        ..downloadKbps = 8
        ..uploadKbps = 16;
      expect(c.downloadDelayMs(1000), 1000);
      expect(c.uploadDelayMs(1000), 500);
      expect(c.downloadDelayMs(0), 0);
    });

    test('reset clears the profile and bandwidth', () {
      FChaosStore.instance.applyProfile(FNetworkProfile.fiveG);
      FChaosStore.instance.reset();
      expect(FChaosStore.instance.profile, FNetworkProfile.none);
      expect(FChaosStore.instance.downloadKbps, 0);
      expect(FChaosStore.instance.uploadKbps, 0);
    });
  });

  group('Dio interceptor', () {
    Dio buildDio(HttpClientAdapter adapter) {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.interceptors.add(FNetworkDioInterceptor(enableInspection: true));
      dio.httpClientAdapter = adapter;
      return dio;
    }

    test('failRate 1.0 forces every request to fail before the network', () async {
      FChaosStore.instance
        ..random = _FixedRandom(0.0)
        ..failStatus = 503
        ..enabled = true
        ..failRate = 1;

      await expectLater(
        buildDio(_ThrowingAdapter()).get<dynamic>('/x'),
        throwsA(isA<DioException>().having(
          (DioException e) => e.response?.statusCode,
          'statusCode',
          503,
        )),
      );
      final NetworkLog log = FNetworkStore.instance.logs.first;
      expect(log.isChaos, isTrue);
      expect(log.status, NetworkLogStatus.error);
    });

    test('latency-only lets the request through', () async {
      FChaosStore.instance
        ..enabled = true
        ..failRate = 0
        ..latencyMs = 150;

      final Stopwatch sw = Stopwatch()..start();
      final Response<dynamic> res =
          await buildDio(_OkAdapter()).get<dynamic>('/x');
      sw.stop();

      expect(res.statusCode, 200);
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(100));
      expect(FNetworkStore.instance.logs.first.isChaos, isFalse);
    });

    test('download bandwidth throttle delays proportionally to payload size', () async {
      FChaosStore.instance
        ..enabled = true
        ..latencyMs = 0
        ..downloadKbps = 8; // 1 byte/ms

      final Stopwatch sw = Stopwatch()..start();
      final Response<dynamic> res =
          await buildDio(_BodyAdapter('x' * 200)).get<dynamic>('/x');
      sw.stop();

      expect(res.statusCode, 200);
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(150));
    });

    test('offline profile rejects with a connection error before the network', () async {
      FChaosStore.instance
        ..enabled = true
        ..applyProfile(FNetworkProfile.offline)
        ..failRate = 0;

      await expectLater(
        buildDio(_ThrowingAdapter()).get<dynamic>('/x'),
        throwsA(isA<DioException>().having(
          (DioException e) => e.type,
          'type',
          DioExceptionType.connectionError,
        )),
      );
      final NetworkLog log = FNetworkStore.instance.logs.first;
      expect(log.isChaos, isTrue);
      expect(log.status, NetworkLogStatus.error);
    });

    test('mock rules win over the offline profile', () async {
      FMockStore.instance.add(FMockRule.create(
        pathPattern: '/x',
        statusCode: 200,
        body: '{"ok":true}',
      ));
      FChaosStore.instance
        ..enabled = true
        ..applyProfile(FNetworkProfile.offline);

      final Response<dynamic> res =
          await buildDio(_ThrowingAdapter()).get<dynamic>('/x');
      expect(res.statusCode, 200);
    });
  });

  group('http interceptor', () {
    test('forced failure never calls the inner client', () async {
      FChaosStore.instance
        ..random = _FixedRandom(0.0)
        ..failStatus = 500
        ..failBody = 'boom'
        ..enabled = true
        ..failRate = 1;

      bool innerCalled = false;
      final FNetworkHttpInterceptor client = FNetworkHttpInterceptor(
        inner: MockClient((http.Request _) async {
          innerCalled = true;
          return http.Response('nope', 200);
        }),
      );

      final http.Response res =
          await client.get(Uri.parse('https://example.com/x'));

      expect(innerCalled, isFalse);
      expect(res.statusCode, 500);
      expect(res.body, 'boom');
      expect(FNetworkStore.instance.logs.first.isChaos, isTrue);
    });

    test('download bandwidth throttle delays proportionally to payload size', () async {
      FChaosStore.instance
        ..enabled = true
        ..latencyMs = 0
        ..downloadKbps = 8; // 1 byte/ms

      final FNetworkHttpInterceptor client = FNetworkHttpInterceptor(
        inner: MockClient(
          (http.Request _) async => http.Response('x' * 200, 200),
        ),
      );

      final Stopwatch sw = Stopwatch()..start();
      final http.Response res =
          await client.get(Uri.parse('https://example.com/x'));
      sw.stop();

      expect(res.statusCode, 200);
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(150));
    });

    test('offline profile throws without calling the inner client', () async {
      FChaosStore.instance
        ..enabled = true
        ..applyProfile(FNetworkProfile.offline);

      bool innerCalled = false;
      final FNetworkHttpInterceptor client = FNetworkHttpInterceptor(
        inner: MockClient((http.Request _) async {
          innerCalled = true;
          return http.Response('nope', 200);
        }),
      );

      await expectLater(
        client.get(Uri.parse('https://example.com/x')),
        throwsA(isA<http.ClientException>()),
      );
      expect(innerCalled, isFalse);
      final NetworkLog log = FNetworkStore.instance.logs.first;
      expect(log.isChaos, isTrue);
      expect(log.status, NetworkLogStatus.error);
    });
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this._value);

  final double _value;

  @override
  double nextDouble() => _value;

  @override
  bool nextBool() => _value < 0.5;

  @override
  int nextInt(int max) => (_value * max).floor();
}

class _OkAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('ok', 200);
  }
}

class _BodyAdapter implements HttpClientAdapter {
  _BodyAdapter(this.body);

  final String body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(body, 200);
  }
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw StateError('network hit for ${options.uri} — chaos did not apply');
  }
}
