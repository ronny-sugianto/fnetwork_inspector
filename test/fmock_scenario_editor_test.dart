import 'package:fnetwork_inspector/fnetwork_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FMockRule _r(String id, String path, {bool enabled = true}) =>
    FMockRule(id: id, pathPattern: path, enabled: enabled);

FMockScenario _s(
  String id,
  String name, {
  String? group,
  List<FMockRule> rules = const <FMockRule>[],
}) => FMockScenario(id: id, name: name, group: group, rules: rules);

void main() {
  setUp(() => FMockStore.instance.reset());
  tearDown(() => FMockStore.instance.reset());

  group('FMockStore scenario editing', () {
    test(
      'createScenario makes an empty, unapplied scenario with a unique name',
      () {
        final FMockStore s = FMockStore.instance;
        s.add(_r('live', '/live'));

        final FMockScenario a = s.createScenario('Empty list', group: 'G');
        final FMockScenario b = s.createScenario('Empty list', group: 'G');
        final FMockScenario c = s.createScenario('Empty list'); // other group

        expect(a.rules, isEmpty);
        expect(b.name, 'Empty list 2');
        expect(c.name, 'Empty list');
        expect(s.activeScenarioId, isNull);
        expect(s.rules.single.id, 'live', reason: 'live rules untouched');
      },
    );

    test('duplicateScenario copies below the source with fresh ids', () {
      final FMockStore s = FMockStore.instance;
      s.addScenarios(<FMockScenario>[
        _s('a', 'A', group: 'G', rules: <FMockRule>[_r('r1', '/1')]),
        _s('z', 'Z'),
      ]);

      final FMockScenario copy = s.duplicateScenario('a')!;
      final FMockScenario copy2 = s.duplicateScenario('a')!;

      expect(copy.name, 'A copy');
      expect(copy2.name, 'A copy 2');
      expect(copy.group, 'G');
      expect(copy.id, isNot('a'));
      expect(copy.rules.single.id, isNot('r1'));
      expect(copy.rules.single.pathPattern, '/1');
      expect(s.scenarios.map((FMockScenario e) => e.id).toList().last, 'z');
      expect(s.scenarios[1].id, copy2.id, reason: 'inserted right below');
      expect(s.duplicateScenario('missing'), isNull);
    });

    test('rule operations edit the scenario, not the live rules', () {
      final FMockStore s = FMockStore.instance;
      s.addScenarios(<FMockScenario>[_s('a', 'A')]);
      s.add(_r('live', '/live'));

      s.addScenarioRule('a', _r('r1', '/1'));
      s.addScenarioRule('a', _r('r2', '/2'));
      expect(s.scenarios.single.rules.map((FMockRule r) => r.id), <String>[
        'r2',
        'r1',
      ]);

      s.updateScenarioRule('a', _r('r1', '/changed'));
      s.toggleScenarioRule('a', 'r2');
      final List<FMockRule> rules = s.scenarios.single.rules;
      expect(
        rules.firstWhere((FMockRule r) => r.id == 'r1').pathPattern,
        '/changed',
      );
      expect(rules.firstWhere((FMockRule r) => r.id == 'r2').enabled, isFalse);

      s.removeScenarioRule('a', 'r2');
      expect(s.scenarios.single.rules.single.id, 'r1');

      expect(s.rules.single.id, 'live', reason: 'not applied → live untouched');

      // unknown ids are ignored
      s.addScenarioRule('nope', _r('x', '/x'));
      s.updateScenarioRule('a', _r('ghost', '/ghost'));
      expect(s.scenarios.single.rules.length, 1);
    });

    test('editing the applied scenario keeps the live rules in step', () {
      final FMockStore s = FMockStore.instance;
      s.addScenarios(<FMockScenario>[
        _s('a', 'A', rules: <FMockRule>[_r('r1', '/1')]),
      ]);
      s.applyScenario('a');

      s.addScenarioRule('a', _r('r2', '/2'));
      expect(s.rules.map((FMockRule r) => r.id), <String>['r2', 'r1']);

      s.toggleScenarioRule('a', 'r1');
      expect(
        s.rules.firstWhere((FMockRule r) => r.id == 'r1').enabled,
        isFalse,
      );

      s.removeScenarioRule('a', 'r2');
      expect(s.rules.map((FMockRule r) => r.id), <String>['r1']);
      expect(s.activeScenarioId, 'a');
    });
  });

  group('Scenarios screen', () {
    Future<void> pump(WidgetTester tester) =>
        tester.pumpWidget(const MaterialApp(home: MockScenarioListScreen()));

    testWidgets('+ creates an empty scenario and opens it', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      expect(find.text('No scenarios yet'), findsOneWidget);

      await tester.tap(find.byTooltip('New scenario'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Empty list');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(FMockStore.instance.scenarios.single.name, 'Empty list');
      expect(FMockStore.instance.activeScenarioId, isNull);
      expect(find.text('No rules in this scenario'), findsOneWidget);
    });

    testWidgets('tapping a row opens it; the play button applies it', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[
        _s('a', 'Alpha', rules: <FMockRule>[_r('r1', '/alpha')]),
      ]);
      await pump(tester);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('/alpha'), findsOneWidget, reason: 'detail shows rules');
      expect(
        FMockStore.instance.activeScenarioId,
        isNull,
        reason: 'not applied',
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Apply'));
      await tester.pumpAndSettle();
      expect(FMockStore.instance.activeScenarioId, 'a');
      expect(FMockStore.instance.rules.single.pathPattern, '/alpha');
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Detach'), findsOneWidget);
    });

    testWidgets('Duplicate and Delete from the row menu', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[_s('a', 'Alpha')]);
      await pump(tester);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      expect(find.text('Alpha copy'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(FMockStore.instance.scenarios.single.name, 'Alpha copy');
    });

    testWidgets('a group header can add a scenario straight into the group', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[
        _s('a', 'Alpha', group: 'Release 1'),
      ]);
      await pump(tester);

      await tester.tap(find.byTooltip('Group actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New scenario in group'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Beta');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final FMockScenario beta = FMockStore.instance.scenarios.firstWhere(
        (FMockScenario s) => s.name == 'Beta',
      );
      expect(beta.group, 'Release 1');
    });

    testWidgets('Save live rules as scenario', (WidgetTester tester) async {
      FMockStore.instance.add(_r('live', '/live'));
      await pump(tester);

      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save live rules as scenario…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Snapshot');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(FMockStore.instance.scenarios.single.rules.single.id, 'live');
    });
  });

  group('Scenario detail screen', () {
    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      const MaterialApp(home: NetworkScenarioDetailScreen(scenarioId: 'a')),
    );

    testWidgets('adds a rule to the scenario, not to the live rules', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[_s('a', 'Alpha')]);
      await pump(tester);

      await tester.tap(find.byTooltip('New rule'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '/posts');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        FMockStore.instance.scenarios.single.rules.single.pathPattern,
        '/posts',
      );
      expect(FMockStore.instance.rules, isEmpty);
      expect(find.text('/posts'), findsOneWidget);
    });

    testWidgets('toggle and delete rules; Apply puts them live', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[
        _s('a', 'Alpha', rules: <FMockRule>[_r('r1', '/1'), _r('r2', '/2')]),
      ]);
      await pump(tester);

      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      expect(FMockStore.instance.scenarios.single.rules.first.enabled, isFalse);

      await tester.tap(find.byTooltip('Delete').last);
      await tester.pump();
      expect(FMockStore.instance.scenarios.single.rules.length, 1);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(FMockStore.instance.activeScenarioId, 'a');
      expect(
        find.textContaining('edits here update the live rules'),
        findsOneWidget,
      );
    });

    testWidgets('Delete from the menu removes the scenario and goes back', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[_s('a', 'Alpha')]);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (BuildContext context) => TextButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => const NetworkScenarioDetailScreen(
                                scenarioId: 'a',
                              ),
                        ),
                      ),
                  child: const Text('open'),
                ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(FMockStore.instance.scenarios, isEmpty);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('Response Mocks screen', () {
    testWidgets('only deals with live rules: no scenario or import menus', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[_s('a', 'Alpha')]);
      FMockStore.instance.applyScenario('a');
      await tester.pumpWidget(const MaterialApp(home: NetworkMockListScreen()));

      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.textContaining('Scenario'), findsNothing);
      expect(find.text('Detach'), findsNothing);
    });
  });
}
