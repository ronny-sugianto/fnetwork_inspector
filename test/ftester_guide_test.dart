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

Widget _app({Widget? home, Locale? locale}) => MaterialApp(
  builder: (BuildContext context, Widget? child) {
    Widget overlay = FNetworkInspectorOverlay(enabled: true, child: child!);
    // The dialog follows the app's resolved locale; force one for the test.
    if (locale != null) {
      overlay = Localizations.override(
        context: context,
        locale: locale,
        child: overlay,
      );
    }
    return overlay;
  },
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

    test(
      '"don\'t show again" hides it, a version bump shows it once more',
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
      },
    );

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
      final _MemStorage storage =
          _MemStorage()..data[FTesterGuideStore.storageKey] = '{not json';
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

      expect(find.text("You're in a testing environment"), findsOneWidget);
      expect(find.text('Verify the data source'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pump();
      expect(find.text("You're in a testing environment"), findsNothing);
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
      expect(find.text("You're in a testing environment"), findsNothing);
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
      expect(find.text("You're in a testing environment"), findsNothing);
    });

    testWidgets('no guide configured → no dialog', (WidgetTester tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.text("You're in a testing environment"), findsNothing);
    });

    testWidgets('shows the intro, the highlighted note and all nine steps', (
      WidgetTester tester,
    ) async {
      await FTesterGuideStore.instance.configure(const FTesterGuide(), null);
      await tester.pumpWidget(_app());
      await tester.pump();

      expect(find.textContaining('Thanks for helping us test'), findsOneWidget);
      expect(
        find.textContaining('may be returned for further investigation'),
        findsOneWidget,
      );
      for (final FTesterGuideStep step in FTesterGuide.defaultSteps) {
        expect(find.text(step.title), findsOneWidget, reason: step.title);
      }
    });

    testWidgets('all text can be replaced (localisation)', (
      WidgetTester tester,
    ) async {
      await FTesterGuideStore.instance.configure(
        const FTesterGuide(
          title: 'Sebelum melapor bug',
          intro: 'Baca dulu.',
          note: 'Laporan tanpa bukti bisa dikembalikan.',
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
      expect(
        find.text('Laporan tanpa bukti bisa dikembalikan.'),
        findsOneWidget,
      );
      expect(find.text('Rekam layar'), findsOneWidget);
      expect(find.text('Mengerti'), findsOneWidget);
      expect(find.text('Jangan tampilkan lagi'), findsOneWidget);
      expect(find.text('Buka inspector'), findsOneWidget);
      expect(find.text('Got it'), findsNothing);
    });
  });

  group('built-in languages (en / id)', () {
    testWidgets('Indonesian app locale shows the Indonesian guide', (
      WidgetTester tester,
    ) async {
      await FTesterGuideStore.instance.configure(const FTesterGuide(), null);
      await tester.pumpWidget(_app(locale: const Locale('id')));
      await tester.pump();

      expect(
        find.text('Anda sedang berada di lingkungan testing'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Terima kasih sudah membantu testing'),
        findsOneWidget,
      );
      expect(find.text('Ikuti alur yang seharusnya'), findsOneWidget);
      expect(find.text('Mengerti'), findsOneWidget);
      expect(find.text('Jangan tampilkan lagi'), findsOneWidget);
      expect(find.text("You're in a testing environment"), findsNothing);
      expect(find.text('Got it'), findsNothing);
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('fr')]) {
      testWidgets('${locale.languageCode} falls back to English', (
        WidgetTester tester,
      ) async {
        await FTesterGuideStore.instance.configure(const FTesterGuide(), null);
        await tester.pumpWidget(_app(locale: locale));
        await tester.pump();
        expect(find.text("You're in a testing environment"), findsOneWidget);
        expect(find.text('Got it'), findsOneWidget);
      });
    }

    testWidgets('your own text wins over the built-in one, per field', (
      WidgetTester tester,
    ) async {
      await FTesterGuideStore.instance.configure(
        const FTesterGuide(title: 'Custom title', note: ''),
        null,
      );
      await tester.pumpWidget(_app(locale: const Locale('id')));
      await tester.pump();

      expect(find.text('Custom title'), findsOneWidget);
      // Fields you did not override still follow the locale.
      expect(find.text('Ikuti alur yang seharusnya'), findsOneWidget);
      expect(find.textContaining('dapat dikembalikan'), findsNothing);
    });

    test('resolve() picks the language and applies overrides', () {
      expect(
        const FTesterGuide().resolve(const Locale('id')).confirmLabel,
        'Mengerti',
      );
      expect(
        const FTesterGuide().resolve(const Locale('id', 'ID')).confirmLabel,
        'Mengerti',
        reason: 'country code must not matter',
      );
      expect(
        const FTesterGuide().resolve(const Locale('en', 'US')).confirmLabel,
        'Got it',
      );
      expect(
        const FTesterGuide(
          confirmLabel: 'OK',
        ).resolve(const Locale('id')).confirmLabel,
        'OK',
      );
    });

    test('Indonesian and English guides have the same shape', () {
      final List<FTesterGuideStep> en = FTesterGuide.defaultSteps;
      final List<FTesterGuideStep> id = FTesterGuide.defaultStepsId;
      expect(id.length, en.length);
      for (int i = 0; i < en.length; i++) {
        expect(id[i].emphasize, en[i].emphasize, reason: 'step ${i + 1}');
        expect(id[i].description, isNotNull);
      }
    });
  });

  group('default content', () {
    test('steps are in the intended order', () {
      expect(
        FTesterGuide.defaultSteps.map((FTesterGuideStep s) => s.title),
        <String>[
          'Follow the intended flow',
          'Record your screen',
          'Reproduce the issue',
          'Verify expected vs actual results',
          'Verify the data source',
          'Inspect API calls and errors',
          'Check related behavior',
          'Attach evidence and protect sensitive data',
          'Write an actionable report and retest fixes',
        ],
      );
    });

    test('never presents a 200 or an empty response as proof', () {
      final String api =
          FTesterGuide.defaultSteps
              .firstWhere(
                (FTesterGuideStep s) => s.title.startsWith('Inspect API'),
              )
              .description!;
      expect(api, contains("doesn't prove"));
    });

    testWidgets('an empty note is hidden', (WidgetTester tester) async {
      await FTesterGuideStore.instance.configure(
        const FTesterGuide(note: ''),
        null,
      );
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.textContaining('returned for further'), findsNothing);
      expect(find.text("You're in a testing environment"), findsOneWidget);
    });
  });

  testWidgets(
    'stays usable on a small screen (no overflow, buttons reachable)',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(960, 1440); // 320 x 480 logical
      addTearDown(tester.view.reset);

      await FTesterGuideStore.instance.configure(const FTesterGuide(), null);
      await tester.pumpWidget(_app());
      await tester.pump();

      expect(find.text("You're in a testing environment"), findsOneWidget);
      // Long content scrolls inside the dialog; the actions stay on screen.
      await tester.drag(
        find.text('Follow the intended flow'),
        const Offset(0, -200),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Got it'));
      await tester.pump();
      expect(find.text("You're in a testing environment"), findsNothing);
    },
  );

  testWidgets('the sensitive-data step is highlighted as a warning', (
    WidgetTester tester,
  ) async {
    await FTesterGuideStore.instance.configure(const FTesterGuide(), null);
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(
      FTesterGuide.defaultSteps.where((FTesterGuideStep s) => s.emphasize),
      hasLength(1),
    );
  });

  group('inspector menu', () {
    testWidgets('can reopen the guide and toggle startup', (
      WidgetTester tester,
    ) async {
      await FTesterGuideStore.instance.configure(const FTesterGuide(), null);
      FTesterGuideStore.instance.markShownThisSession();
      await tester.pumpWidget(const MaterialApp(home: NetworkLogListScreen()));

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Tester guide'), findsOneWidget);
      expect(find.text('Show guide at startup'), findsOneWidget);

      await tester.tap(find.text('Tester guide'));
      await tester.pumpAndSettle();
      expect(find.text("You're in a testing environment"), findsOneWidget);
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
      await tester.pumpWidget(const MaterialApp(home: NetworkLogListScreen()));
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
          builder:
              (BuildContext context) => TextButton(
                onPressed: () => showTesterGuideDialog(context),
                child: const Text('open'),
              ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text("You're in a testing environment"), findsOneWidget);
  });
}
