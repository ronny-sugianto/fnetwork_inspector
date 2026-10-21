import 'package:fnetwork_inspector/fnetwork_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

NetworkLog _log(String id, {String? body}) => NetworkLog(
  id: id,
  method: 'GET',
  path: '/p/$id',
  baseUrl: 'https://x.com',
  status: NetworkLogStatus.success,
  startTime: DateTime.now(),
  statusCode: 200,
  durationMs: 5,
  responseBody: body,
);

void main() {
  setUp(() {
    FNetworkStore.instance
      ..clear()
      ..maxLogs = 200;
  });

  tearDown(() => FNetworkStore.instance.maxLogs = 200);

  test('evicts the oldest logs past maxLogs', () {
    FNetworkStore.instance.maxLogs = 3;
    for (int i = 0; i < 5; i++) {
      FNetworkStore.instance.onRequest(_log('r$i'));
    }
    expect(FNetworkStore.instance.logs.map((NetworkLog l) => l.id), <String>[
      'r4',
      'r3',
      'r2',
    ]);
  });

  test('lowering maxLogs trims immediately', () {
    for (int i = 0; i < 10; i++) {
      FNetworkStore.instance.onRequest(_log('r$i'));
    }
    FNetworkStore.instance.maxLogs = 4;
    expect(FNetworkStore.instance.logs.length, 4);
  });

  test('counts and snapshot stay correct across updates', () {
    FNetworkStore.instance.onRequest(
      NetworkLog(
        id: 'a',
        method: 'GET',
        path: '/a',
        baseUrl: 'https://x.com',
        status: NetworkLogStatus.loading,
        startTime: DateTime.now(),
      ),
    );
    expect(FNetworkStore.instance.loadingCount, 1);
    FNetworkStore.instance.onSuccess('a', 200, 5);
    expect(FNetworkStore.instance.loadingCount, 0);
    expect(FNetworkStore.instance.successCount, 1);
    FNetworkStore.instance.onError('a', 500, 'x', 5);
    expect(FNetworkStore.instance.successCount, 0);
    expect(FNetworkStore.instance.errorCount, 1);
  });

  group('detail screen', () {
    testWidgets('keeps the last data (with a notice) when its log is evicted', (
      WidgetTester tester,
    ) async {
      FNetworkStore.instance.maxLogs = 5;
      FNetworkStore.instance.onRequest(_log('first', body: '{"a":1}'));
      await tester.pumpWidget(
        const MaterialApp(home: NetworkLogDetailScreen(requestId: 'first')),
      );
      expect(find.text('Request not found'), findsNothing);

      for (int i = 0; i < 10; i++) {
        FNetworkStore.instance.onRequest(_log('n$i'));
      }
      await tester.pump();

      expect(find.text('Request not found'), findsNothing);
      expect(find.textContaining('Evicted from history'), findsOneWidget);
      expect(find.textContaining('/p/first'), findsWidgets);
    });

    testWidgets('does not rebuild for unrelated log changes', (
      WidgetTester tester,
    ) async {
      FNetworkStore.instance.onRequest(_log('mine', body: '{"a":1}'));
      await tester.pumpWidget(
        const MaterialApp(home: NetworkLogDetailScreen(requestId: 'mine')),
      );
      final Finder statusText = find.textContaining('200 OK');
      expect(statusText, findsWidgets);

      // Unrelated traffic must not disturb the open page.
      for (int i = 0; i < 20; i++) {
        FNetworkStore.instance.onRequest(_log('other$i'));
      }
      await tester.pump();
      expect(find.textContaining('Evicted'), findsNothing);
      expect(statusText, findsWidgets);
    });

    testWidgets('body has a single copy control (no duplicate in the header)', (
      WidgetTester tester,
    ) async {
      FNetworkStore.instance.onRequest(_log('x', body: '{"a":1}'));
      await tester.pumpWidget(
        const MaterialApp(home: NetworkLogDetailScreen(requestId: 'x')),
      );
      await tester.tap(find.text('Response'));
      await tester.pumpAndSettle();

      // `copy_outlined` is only the app-bar "copy full report"; the body's own
      // copy lives in the viewer toolbar (`copy_all`).
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
      expect(find.byIcon(Icons.copy_all), findsOneWidget);
    });
  });
}
