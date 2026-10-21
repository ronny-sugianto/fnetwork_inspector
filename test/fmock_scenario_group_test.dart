import 'package:fnetwork_inspector/fnetwork_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FMockScenario _s(String name, {String? group, String id = ''}) => FMockScenario(
  id: id.isEmpty ? name : id,
  name: name,
  group: group,
  rules: <FMockRule>[FMockRule.create(pathPattern: '/$name')],
);

const String _release = 'Health Plan Enhancement v2.0';

void main() {
  setUp(() => FMockStore.instance.reset());
  tearDown(() => FMockStore.instance.reset());

  group('FMockScenario.group', () {
    test('survives a JSON round trip; blank means ungrouped', () {
      final FMockScenario grouped = FMockScenario.fromJson(
        _s('a', group: _release).toJson(),
      );
      expect(grouped.group, _release);

      final Map<String, dynamic> plain = _s('b').toJson();
      expect(plain.containsKey('group'), isFalse);
      expect(FMockScenario.fromJson(plain).group, isNull);

      expect(
        FMockScenario.fromJson(<String, dynamic>{
          'name': 'c',
          'group': '  ',
        }).group,
        isNull,
      );
    });

    test('copyWith keeps, changes or clears the group', () {
      final FMockScenario s = _s('a', group: 'G');
      expect(s.copyWith(name: 'x').group, 'G');
      expect(s.copyWith(group: '  H ').group, 'H');
      expect(s.copyWith(group: null).group, isNull);
    });
  });

  group('FMockStore scenario groups', () {
    test('same name in different groups are different scenarios', () {
      final FMockStore s = FMockStore.instance;
      s.add(FMockRule.create(pathPattern: '/x'));
      s.saveAsScenario('Health Profile', group: _release);
      s.saveAsScenario('Health Profile', group: 'Other release');
      s.saveAsScenario('Health Profile'); // ungrouped
      expect(s.scenarios.length, 3);

      // Same name AND group overwrites.
      s.add(FMockRule.create(pathPattern: '/y'));
      s.saveAsScenario('Health Profile', group: _release);
      expect(s.scenarios.length, 3);
      expect(s.scenarios.first.rules.length, 2);
    });

    test('scenarioGroups keeps first-appearance order, skips ungrouped', () {
      FMockStore.instance.addScenarios(<FMockScenario>[
        _s('a', group: 'B'),
        _s('b'),
        _s('c', group: 'A'),
        _s('d', group: 'B'),
      ]);
      expect(FMockStore.instance.scenarioGroups, <String>['B', 'A']);
    });

    test('setScenarioGroup moves and clears', () {
      final FMockStore s = FMockStore.instance;
      s.addScenarios(<FMockScenario>[_s('a')]);
      s.setScenarioGroup('a', ' Release 1 ');
      expect(s.scenarios.single.group, 'Release 1');
      s.setScenarioGroup('a', '');
      expect(s.scenarios.single.group, isNull);
    });

    test('export / import keeps groups', () {
      final FMockStore s = FMockStore.instance;
      s.addScenarios(<FMockScenario>[_s('a', group: _release), _s('b')]);
      final String json = s.exportJson();
      s.reset();
      s.importJson(json);
      expect(s.scenarios.map((FMockScenario x) => x.group), <String?>[
        _release,
        null,
      ]);
    });
  });

  group('Scenarios screen', () {
    Future<void> pump(WidgetTester tester) =>
        tester.pumpWidget(const MaterialApp(home: MockScenarioListScreen()));

    testWidgets('lists scenarios under one header per group', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[
        _s('Tab Indicator badge', group: _release),
        _s('Health Profile', group: _release),
        _s('Health Score Result', group: _release),
        _s('Met-U', group: _release),
        _s('Logged out'),
      ]);
      await pump(tester);

      expect(find.text(_release), findsOneWidget);
      expect(find.text('Other scenarios'), findsOneWidget);
      expect(find.text('4'), findsOneWidget, reason: 'group count');
      for (final String n in <String>[
        'Tab Indicator badge',
        'Health Profile',
        'Health Score Result',
        'Met-U',
        'Logged out',
      ]) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
    });

    testWidgets('a group can be collapsed and expanded', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[
        _s('Health Profile', group: _release),
        _s('Logged out'),
      ]);
      await pump(tester);

      await tester.tap(find.text(_release));
      await tester.pump();
      expect(find.text('Health Profile'), findsNothing);
      expect(find.text('Logged out'), findsOneWidget);

      await tester.tap(find.text(_release));
      await tester.pump();
      expect(find.text('Health Profile'), findsOneWidget);
    });

    testWidgets('no groups: plain list, no "Other scenarios" header', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[_s('a'), _s('b')]);
      await pump(tester);
      expect(find.text('Other scenarios'), findsNothing);
      expect(find.text('a'), findsOneWidget);
    });

    testWidgets('Edit… moves a scenario into a new group', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[_s('Met-U')]);
      await pump(tester);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit…'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), _release);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(FMockStore.instance.scenarios.single.group, _release);
      expect(find.text(_release), findsOneWidget);
    });
  });
}
