import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:fnetwork_inspector/fnetwork_inspector.dart';
import 'package:fnetwork_inspector/src/ui/mock_file_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String _release = 'Checkout Revamp v2.0';

FMockScenario _s(String id, String name, {String? group, String path = '/x'}) =>
    FMockScenario(
      id: id,
      name: name,
      group: group,
      rules: <FMockRule>[FMockRule(id: '$id-r', pathPattern: path)],
    );

String _file(List<FMockScenario> scenarios) =>
    FMockStore.instance.exportScenariosJson(scenarios);

void main() {
  setUp(() => FMockStore.instance.reset());
  tearDown(() => FMockStore.instance.reset());

  group('FMockBundle.parse', () {
    test('reads the current envelope', () {
      final FMockBundle b = FMockBundle.parse(
        _file(<FMockScenario>[_s('a', 'A', group: _release)]),
      );
      expect(b.rules, isNull, reason: 'scenario files have no rules section');
      expect(b.scenarios!.single.group, _release);
      expect(b.enabled, isNull);
    });

    test('still reads files from earlier versions and bare rule lists', () {
      expect(
        FMockBundle.parse(
          '{"rules":[{"id":"r","pathPattern":"/a"}]}',
        ).ruleCount,
        1,
      );
      expect(FMockBundle.parse('[{"id":"r","pathPattern":"/a"}]').ruleCount, 1);
    });

    test('rejects things that are not mock files, with a readable reason', () {
      for (final MapEntry<String, String> c
          in <String, String>{
            'nope {': 'Not valid JSON',
            '42': 'Expected a JSON object',
            '{"type":"something.else","scenarios":[]}':
                'Not a fnetwork_inspector',
            '{"version":2,"scenarios":[]}': 'Unsupported file version',
            '{"hello":"world"}': 'No "rules", "scenarios" or "groups"',
            '{"scenarios":[42]}': 'Malformed entry',
          }.entries) {
        expect(
          () => FMockBundle.parse(c.key),
          throwsA(
            isA<FormatException>().having(
              (FormatException e) => e.message,
              'message',
              contains(c.value),
            ),
          ),
          reason: c.key,
        );
      }
    });

    test('groups nest their scenarios; the group name is not repeated', () {
      final Map<String, dynamic> json =
          jsonDecode(
                _file(<FMockScenario>[
                  _s('a', 'A', group: _release),
                  _s('b', 'B', group: _release),
                  _s('c', 'C', group: 'Other release'),
                  _s('d', 'D'),
                ]),
              )
              as Map<String, dynamic>;

      final List<dynamic> groups = json['groups'] as List<dynamic>;
      expect(
        groups.map((dynamic g) => (g as Map<String, dynamic>)['name']),
        <String>[_release, 'Other release'],
      );
      final Map<String, dynamic> first = groups.first as Map<String, dynamic>;
      expect((first['scenarios'] as List<dynamic>).length, 2);
      expect(
        (first['scenarios'] as List<dynamic>).every(
          (dynamic s) => !(s as Map<String, dynamic>).containsKey('group'),
        ),
        isTrue,
      );
      expect(
        ((json['scenarios'] as List<dynamic>).single
            as Map<String, dynamic>)['name'],
        'D',
      );
    });

    test('nested groups round trip, and the flat form still parses', () {
      final FMockBundle b = FMockBundle.parse(
        _file(<FMockScenario>[_s('a', 'A', group: _release), _s('d', 'D')]),
      );
      expect(b.scenarios!.map((FMockScenario s) => s.group), <String?>[
        _release,
        null,
      ]);

      final FMockBundle flat = FMockBundle.parse(
        '{"scenarios":[{"id":"x","name":"X","group":"G","rules":[]}]}',
      );
      expect(flat.scenarios!.single.group, 'G');
    });

    test(
      'a group name wins; a blank name means ungrouped; groups-only works',
      () {
        final FMockBundle b = FMockBundle.parse(
          '{"groups":['
          '{"name":"G","scenarios":[{"id":"a","name":"A","group":"ignored"}]},'
          '{"name":"  ","scenarios":[{"id":"b","name":"B"}]},'
          '{"name":"Empty"}'
          ']}',
        );
        expect(b.rules, isNull);
        expect(b.scenarios!.map((FMockScenario s) => s.group), <String?>[
          'G',
          null,
        ]);
      },
    );

    test('an empty scenario list is still a scenarios section', () {
      final FMockBundle b = FMockBundle.parse(_file(<FMockScenario>[]));
      expect(b.scenarios, isEmpty);
      expect(b.scenarios, isNotNull);
    });

    test('exported files carry type, version and the credit', () {
      final Map<String, dynamic> json =
          jsonDecode(FMockStore.instance.exportJson()) as Map<String, dynamic>;
      expect(json['type'], kFMockFileType);
      expect(json['version'], 1);
      expect(json['_credit'], contains('rons.my.id'));
    });
  });

  group('import: merge vs replace', () {
    test(
      'merge adds new, updates same id / same name+group, keeps the rest',
      () {
        final FMockStore s = FMockStore.instance;
        s.addScenarios(<FMockScenario>[
          _s('keep', 'Keep me'),
          _s('p', 'Order Summary', group: _release, path: '/old'),
          _s('q', 'Wishlist', group: _release),
        ]);
        s.add(FMockRule.create(pathPattern: '/live'));

        final FMockImportSummary r = s.importJson(
          _file(<FMockScenario>[
            _s(
              'p',
              'Order Summary renamed',
              group: _release,
              path: '/new',
            ), // same id
            _s(
              'zzz',
              'Wishlist',
              group: _release,
              path: '/metu2',
            ), // same name+group
            _s('fresh', 'Fresh'),
          ]),
          merge: true,
        );

        expect(r.scenariosUpdated, 2);
        expect(r.scenariosAdded, 1);
        expect(s.scenarios.length, 4);
        expect(
          s.scenarios.map((FMockScenario e) => e.name),
          contains('Keep me'),
        );
        expect(
          s.scenarios
              .firstWhere((FMockScenario e) => e.id == 'p')
              .rules
              .single
              .pathPattern,
          '/new',
        );
        expect(
          s.scenarios.firstWhere((FMockScenario e) => e.name == 'Wishlist').id,
          'zzz',
          reason: 'the file\'s id wins so applyScenario(id) works afterwards',
        );
        expect(
          s.rules.single.pathPattern,
          '/live',
          reason: 'live rules untouched',
        );
      },
    );

    test('importing the same file twice does not duplicate anything', () {
      final String file = _file(<FMockScenario>[_s('a', 'A'), _s('b', 'B')]);
      FMockStore.instance.importJson(file, merge: true);
      final FMockImportSummary again = FMockStore.instance.importJson(
        file,
        merge: true,
      );
      expect(FMockStore.instance.scenarios.length, 2);
      expect(again.scenariosAdded, 0);
      expect(again.scenariosUpdated, 2);
    });

    test('merge keeps the active scenario active when it is updated', () {
      final FMockStore s = FMockStore.instance;
      s.addScenarios(<FMockScenario>[_s('old', 'A')]);
      s.applyScenario('old');
      s.importJson(_file(<FMockScenario>[_s('new', 'A')]), merge: true);
      expect(s.activeScenarioId, 'new');
    });

    test('replace swaps only the sections the file contains', () {
      final FMockStore s = FMockStore.instance;
      s.addScenarios(<FMockScenario>[_s('a', 'A'), _s('b', 'B')]);
      s.add(FMockRule.create(pathPattern: '/live'));
      s.enabled = false;

      s.importJson(_file(<FMockScenario>[_s('c', 'C')])); // scenarios-only file

      expect(s.scenarios.map((FMockScenario e) => e.id), <String>['c']);
      expect(s.rules.single.pathPattern, '/live', reason: 'no rules section');
      expect(s.enabled, isFalse, reason: 'no flags in a scenarios-only file');
    });

    test('merge keeps the file\'s rule order and upserts by id', () {
      final FMockStore s = FMockStore.instance;
      s.add(FMockRule(id: 'exists', pathPattern: '/old'));
      final FMockImportSummary r = s.importJson(
        '[{"id":"n1","pathPattern":"/1"},{"id":"exists","pathPattern":"/new"},'
        '{"id":"n2","pathPattern":"/2"}]',
        merge: true,
      );
      expect(r.rulesAdded, 2);
      expect(r.rulesUpdated, 1);
      expect(s.rules.map((FMockRule e) => e.pathPattern), <String>[
        '/1',
        '/2',
        '/new',
      ]);
    });

    test('summary reads naturally', () {
      expect(const FMockImportSummary().describe(), 'Nothing to import');
      expect(
        const FMockImportSummary(
          scenariosAdded: 2,
          scenariosUpdated: 1,
          rulesAdded: 1,
        ).describe(),
        '2 scenarios added, 1 updated, 1 rule added',
      );
    });
  });

  group('seed (initialize)', () {
    test('scenarios and mockJson are upserted on every launch', () {
      final FMockStore s = FMockStore.instance;
      s.seed(scenarios: <FMockScenario>[_s('a', 'A', path: '/v1')]);
      // a tester also made one in the UI
      s.addScenarios(<FMockScenario>[_s('mine', 'Mine')]);

      // next launch, the code changed
      s.seed(
        scenarios: <FMockScenario>[_s('a', 'A', path: '/v2')],
        json: _file(<FMockScenario>[_s('b', 'B')]),
      );

      expect(s.scenarios.length, 3);
      expect(
        s.scenarios
            .firstWhere((FMockScenario e) => e.id == 'a')
            .rules
            .single
            .pathPattern,
        '/v2',
      );
    });

    test('mockRules only seed an empty store', () {
      final FMockStore s = FMockStore.instance;
      s.seed(rules: <FMockRule>[FMockRule.create(pathPattern: '/a')]);
      s.seed(rules: <FMockRule>[FMockRule.create(pathPattern: '/b')]);
      expect(s.rules.single.pathPattern, '/a');
    });

    test('activeScenarioId applies the scenario at startup', () {
      final FMockStore s = FMockStore.instance;
      s.seed(
        scenarios: <FMockScenario>[_s('a', 'A', path: '/applied')],
        activeScenarioId: 'a',
      );
      expect(s.activeScenarioId, 'a');
      expect(s.rules.single.pathPattern, '/applied');
    });

    test('an unknown activeScenarioId is ignored, not fatal', () {
      FMockStore.instance.seed(activeScenarioId: 'missing');
      expect(FMockStore.instance.activeScenarioId, isNull);
    });

    test('a restored session wins over activeScenarioId', () async {
      final FMockStore s = FMockStore.instance;
      s.addScenarios(<FMockScenario>[_s('a', 'A', path: '/seed')]);
      final _Mem mem = _Mem()..data = s.exportJson();
      s.reset();
      await s.attachPersistence(mem); // restores the saved session

      s.seed(
        scenarios: <FMockScenario>[_s('a', 'A', path: '/seed')],
        activeScenarioId: 'a',
      );
      expect(s.activeScenarioId, isNull, reason: 'tester\'s last state wins');
    });

    test('invalid mockJson is skipped instead of crashing startup', () {
      FMockStore.instance.seed(
        scenarios: <FMockScenario>[_s('a', 'A')],
        json: '{ definitely not json',
      );
      expect(FMockStore.instance.scenarios.length, 1);
    });
  });

  group('file names', () {
    test('are slugged and end in .fnmock.json', () {
      expect(mockFileName('Order Summary'), 'order-summary.fnmock.json');
      expect(mockFileName(_release), 'checkout-revamp-v2-0.fnmock.json');
      expect(mockFileName('  !!  '), 'mocks.fnmock.json');
    });
  });

  group('import from file (UI)', () {
    late Future<XFile?> Function() original;
    setUp(() => original = mockFilePicker);
    tearDown(() => mockFilePicker = original);

    Future<void> pumpScenarios(WidgetTester tester) =>
        tester.pumpWidget(const MaterialApp(home: MockScenarioListScreen()));

    Future<void> openImportFile(WidgetTester tester) async {
      // The Scaffold builds its body before the app bar, so the app bar's
      // menu is the last ⋮ in the tree.
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import from file…'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows what the file contains, then merges', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[_s('keep', 'Keep me')]);
      mockFilePicker =
          () async => XFile.fromData(
            utf8.encode(
              _file(<FMockScenario>[
                _s('a', 'Order Summary', group: _release),
                _s('b', 'Wishlist', group: _release),
              ]),
            ),
            name: 'checkout-revamp.fnmock.json',
          );
      await pumpScenarios(tester);
      await openImportFile(tester);

      expect(find.text('Import mocks'), findsOneWidget);
      expect(find.textContaining('Contains 2 scenarios'), findsOneWidget);
      expect(find.textContaining('$_release › Wishlist'), findsOneWidget);
      expect(
        find.textContaining('Replace removes all 1 current scenarios'),
        findsOneWidget,
      );

      await tester.tap(find.text('Merge'));
      await tester.pumpAndSettle();

      expect(FMockStore.instance.scenarios.length, 3, reason: 'kept + 2 new');
      expect(find.textContaining('2 scenarios added'), findsOneWidget);
      expect(find.text(_release), findsOneWidget, reason: 'group header shown');
    });

    testWidgets('Replace overwrites the scenarios', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[_s('keep', 'Keep me')]);
      mockFilePicker =
          () async => XFile.fromData(
            utf8.encode(_file(<FMockScenario>[_s('a', 'Only me')])),
            name: 'x.fnmock.json',
          );
      await pumpScenarios(tester);
      await openImportFile(tester);
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(
        FMockStore.instance.scenarios.map((FMockScenario e) => e.name),
        <String>['Only me'],
      );
    });

    testWidgets('Cancel and a cancelled picker change nothing', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[_s('keep', 'Keep me')]);
      mockFilePicker =
          () async => XFile.fromData(
            utf8.encode(_file(<FMockScenario>[_s('a', 'New')])),
            name: 'x.fnmock.json',
          );
      await pumpScenarios(tester);
      await openImportFile(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(FMockStore.instance.scenarios.length, 1);

      mockFilePicker = () async => null; // user dismissed the picker
      await openImportFile(tester);
      expect(find.text('Import mocks'), findsNothing);
      expect(FMockStore.instance.scenarios.length, 1);
    });

    testWidgets('an invalid file shows a readable error and changes nothing', (
      WidgetTester tester,
    ) async {
      FMockStore.instance.addScenarios(<FMockScenario>[_s('keep', 'Keep me')]);
      mockFilePicker =
          () async => XFile.fromData(
            utf8.encode('{"hello":"world"}'),
            name: 'bad.json',
          );
      await pumpScenarios(tester);
      await openImportFile(tester);

      expect(find.textContaining('Invalid mocks file'), findsOneWidget);
      expect(find.text('Import mocks'), findsNothing);
      expect(FMockStore.instance.scenarios.length, 1);
    });
  });
}

class _Mem implements FMockPersistence {
  String? data;

  @override
  Future<String?> load() async => data;

  @override
  Future<void> save(String json) async => data = json;
}
