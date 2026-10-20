import 'dart:convert';

import 'package:fnetwork_inspector/fnetwork_inspector.dart';
import 'package:fnetwork_inspector/src/ui/widget/ftester_guide_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemStorage implements FInspectorStorage {
  final Map<String, String> data = <String, String>{};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

Widget _app({Widget? home}) => MaterialApp(
      builder: (BuildContext context, Widget? child) =>
          FNetworkInspectorOverlay(enabled: true, child: child!),
      home: home ?? const Scaffold(body: Text('home')),
    );

void main() {
  setUp(() => FTesterGuideStore.instance.reset());
  tearDown(() => FTesterGuideStore.instance.reset());

  group('FTesterGuideStore', () {
    test('auto-shows once per session when configured', () async {
      final FTesterGuideStore s = FTesterGuideStore.instance;
      expect(s.shouldAutoShow, isFalse, reason: 'no guide configured');

      await s.configure(const FTesterGuide(), null);
      expect(s.shouldAutoShow, isTrue);

      s.markShownThisSession();
      expect(s.shouldAutoShow, isFalse);
      expect(s.showAtStartup, isTrue, reason: 'still enabled for next launch');
    });

    test('"don\'t show again" hides it, a version bump shows it once more',
        () async {
      final _MemStorage storage = _MemStorage();
      final FTesterGuideStore s = FTesterGuideStore.instance;
      await s.configure(const FTesterGuide(version: 1), storage);

      s.setShowAtStartup(false);
      expect(s.showAtStartup, isFalse);
      expect(
        jsonDecode(storage.data[FTesterGuideStore.storageKey]!),
        <String, dynamic>{'hiddenVersion': 1},
      );

      // Next launch, same version: stays hidden.
      s.reset();
      await s.configure(const FTesterGuide(version: 1), storage);
      expect(s.showAtStartup, isFalse);

      // Guide content changed: shows again.
      s.reset();
      await s.configure(const FTesterGuide(version: 2), storage);
      expect(s.showAtStartup, isTrue);
    });

    test('switching it back on clears the stored choice', () async {
      final _MemStorage storage = _MemStorage();
      final FTesterGuideStore s = FTesterGuideStore.instance;
      await s.configure(const FTesterGuide(), storage);
      s.setShowAtStartup(false);
      s.setShowAtStartup(true);
      expect(s.showAtStartup, isTrue);
      expect(
        jsonDecode(storage.data[FTesterGuideStore.storageKey]!),
        <String, dynamic>{'hiddenVersion': null},
      );
    });

    test('ignores corrupt stored state', () async {
      final _MemStorage storage = _MemStorage()
        ..data[FTesterGuideStore.storageKey] = '{not json';
      await FTesterGuideStore.instance.configure(const FTesterGuide(), storage);
      expect(FTesterGuideStore.instance.showAtStartup, isTrue);
    });
  });

  group('startup dialog (overlay)', () {
    testWidgets('shows on first build, dismisses with "Got it"', (
      WidgetTester tester,
    ) async {
      await FTesterGuideStore.instance.configure(const FTesterGuide(), null);
      await tester.pumpWidget(_app());
      await tester.pump();

      expect(find.text('Before you report a bug'), findsOneWidget);
      expect(find.text('Check the data first'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pump();
      expect(find.text('Before you report a bug'), findsNothing);
    });

    testWidgets('is not shown again in the same session', (
      WidgetTester tester,
    ) async {
      await FTesterGuideStore.instance.configure(const FTesterGuide(), null);
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.tap(find.text('Got it'));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.text('Before you report a bug'), findsNothing);
    });

    testWidgets('"don\'t show again" is stored', (WidgetTester tester) async {
      final _MemStorage storage = _MemStorage();
      await FTesterGuideStore.instance.configure(const FTesterGuide(), storage);
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Got it'));
      await tester.pump();

      expect(FTesterGuideStore.instance.showAtStartup, isFalse);
      expect(storage.data, isNotEmpty);
    });

    testWidgets('stays hidden when switched off', (WidgetTester tester) async {
      await FTesterGuideStore.instance.configure(const FTesterGuide(), null);
      FTesterGuideStore.instance.setShowAtStartup(false);
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.text('Before you report a bug'), findsNothing);
    });

    testWidgets('no guide configured → no dialog', (WidgetTester tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.text('Before you report a bug'), findsNothing);
    });

    testWidgets('all text can be replaced (localisation)', (
      WidgetTester tester,
    ) async {
      await FTesterGuideStore.instance.configure(
        const FTesterGuide(
          title: 'Sebelum melapor bug',
          intro: 'Baca dulu.',
          steps: <FTesterGuideStep>[
            FTesterGuideStep('Rekam layar', 'Mulai sebelum langkah pertama.'),
          ],
          confirmLabel: 'Mengerti',
          dontShowAgainLabel: 'Jangan tampilkan lagi',
          openInspectorLabel: 'Buka inspector',
        ),
        null,
      );
      await tester.pumpWidget(_app());
      await tester.pump();

      expect(find.text('Sebelum melapor bug'), findsOneWidget);
      expect(find.text('Rekam layar'), findsOneWidget);
      expect(find.text('Mengerti'), findsOneWidget);
      expect(find.text('Jangan tampilkan lagi'), findsOneWidget);
      expect(find.text('Buka inspector'), findsOneWidget);
      expect(find.text('Got it'), findsNothing);
    });
  });

  group('inspector menu', () {
    testWidgets('can reopen the guide and toggle startup', (
      WidgetTester tester,
    ) async {
      await FTesterGuideStore.instance.configure(const FTesterGuide(), null);
      FTesterGuideStore.instance.markShownThisSession();
      await tester.pumpWidget(
        const MaterialApp(home: NetworkLogListScreen()),
      );

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Tester guide'), findsOneWidget);
      expect(find.text('Show guide at startup'), findsOneWidget);

      await tester.tap(find.text('Tester guide'));
      await tester.pumpAndSettle();
      expect(find.text('Before you report a bug'), findsOneWidget);
      // Opened from inside the inspector: no redundant "Open inspector".
      expect(find.text('Open inspector'), findsNothing);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show guide at startup'));
      await tester.pumpAndSettle();
      expect(FTesterGuideStore.instance.showAtStartup, isFalse);
    });

    testWidgets('guide items are absent when no guide is configured', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: NetworkLogListScreen()),
      );
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Tester guide'), findsNothing);
    });
  });

  testWidgets('showTesterGuideDialog uses defaults when nothing configured', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showTesterGuideDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Before you report a bug'), findsOneWidget);
  });
}
