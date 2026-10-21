import 'dart:convert';

import 'package:fnetwork_inspector/src/model/fmock_rule.dart';
import 'package:fnetwork_inspector/src/model/fmock_scenario.dart';
import 'package:flutter/foundation.dart';

/// `type` value written into (and checked on) fnetwork_inspector mock files.
const String kFMockFileType = 'fnetwork_inspector.mocks';

/// Recommended extension for mock files, e.g. `checkout-revamp.fnmock.json`. They
/// are plain JSON, so they can be edited by hand and committed to a repo.
const String kFMockFileExtension = '.fnmock.json';

/// The content of a mock file: any mix of live [rules], named [scenarios] and
/// the master switch. A section that is `null` is simply absent from the file,
/// so importing it leaves that part of the store alone.
@immutable
class FMockBundle {
  const FMockBundle({
    this.rules,
    this.scenarios,
    this.enabled,
    this.activeScenarioId,
  });

  /// Parses a mock file. Accepts the current envelope, files written by earlier
  /// versions (no `type`), and a bare JSON array of rules.
  ///
  /// Throws a [FormatException] with a readable message for anything else.
  factory FMockBundle.parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('Not valid JSON (${e.message})');
    }

    try {
      if (decoded is List) {
        return FMockBundle(rules: _rules(decoded));
      }
      if (decoded is! Map) {
        throw const FormatException('Expected a JSON object');
      }
      final Map<String, dynamic> json = decoded.cast<String, dynamic>();

      final Object? type = json['type'];
      if (type != null && type != kFMockFileType) {
        throw FormatException(
          'Not a fnetwork_inspector mocks file '
          '(type: "$type")',
        );
      }
      final Object? version = json['version'];
      if (version is int && version > 1) {
        throw FormatException(
          'Unsupported file version $version; update '
          'fnetwork_inspector to import it',
        );
      }

      final Object? rawRules = json['rules'];
      final Object? rawScenarios = json['scenarios'];
      final Object? rawGroups = json['groups'];
      if (rawRules is! List && rawScenarios is! List && rawGroups is! List) {
        throw const FormatException(
          'No "rules", "scenarios" or "groups" found',
        );
      }
      return FMockBundle(
        rules: rawRules is List ? _rules(rawRules) : null,
        scenarios:
            rawScenarios is List || rawGroups is List
                ? <FMockScenario>[
                  // Same order as the file: each group's scenarios, then the
                  // loose ones (which may carry their own `group`).
                  if (rawGroups is List) ..._groups(rawGroups),
                  if (rawScenarios is List) ..._scenarios(rawScenarios, null),
                ]
                : null,
        enabled: json['enabled'] as bool?,
        activeScenarioId: json['activeScenarioId'] as String?,
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed entry ($e)');
    }
  }

  static List<FMockScenario> _scenarios(List<dynamic> raw, String? group) =>
      raw.map((dynamic e) {
        final FMockScenario scenario = FMockScenario.fromJson(
          (e as Map<dynamic, dynamic>).cast<String, dynamic>(),
        );
        // A group's name wins over any `group` on the scenario itself.
        return group == null ? scenario : scenario.copyWith(group: group);
      }).toList();

  /// `groups: [{name, scenarios: [...]}]`
  static List<FMockScenario> _groups(List<dynamic> raw) => <FMockScenario>[
    for (final dynamic g in raw)
      ..._scenarios(
        ((g as Map<dynamic, dynamic>)['scenarios'] as List<dynamic>?) ??
            const <dynamic>[],
        FMockScenario.cleanGroup(g['name'] as String?),
      ),
  ];

  static List<FMockRule> _rules(List<dynamic> raw) =>
      raw
          .map(
            (dynamic e) => FMockRule.fromJson(
              (e as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .toList();

  /// Live rules, or null when the file has no `rules` section.
  final List<FMockRule>? rules;

  /// Named scenarios, or null when the file has no `scenarios` section.
  final List<FMockScenario>? scenarios;

  /// Master switch, present in full exports only.
  final bool? enabled;

  /// Which scenario was active, present in full exports only.
  final String? activeScenarioId;

  int get ruleCount => rules?.length ?? 0;
  int get scenarioCount => scenarios?.length ?? 0;
  bool get isEmpty => ruleCount == 0 && scenarioCount == 0;

  Map<String, dynamic> toJson({String? credit}) => <String, dynamic>{
    'type': kFMockFileType,
    'version': 1,
    if (credit != null) '_credit': credit,
    if (enabled != null) 'enabled': enabled,
    if (activeScenarioId != null) 'activeScenarioId': activeScenarioId,
    if (rules != null)
      'rules': rules!.map((FMockRule r) => r.toJson()).toList(),
    if (scenarios != null) ..._scenariosJson(scenarios!),
  };

  /// Scenarios of a group are nested under it (`groups`) instead of repeating
  /// the group name on each one; ungrouped ones stay in `scenarios`.
  static Map<String, dynamic> _scenariosJson(List<FMockScenario> all) {
    final Map<String, List<FMockScenario>> grouped =
        <String, List<FMockScenario>>{};
    final List<FMockScenario> loose = <FMockScenario>[];
    for (final FMockScenario s in all) {
      if (s.group == null) {
        loose.add(s);
      } else {
        grouped.putIfAbsent(s.group!, () => <FMockScenario>[]).add(s);
      }
    }
    Map<String, dynamic> scenario(FMockScenario s) =>
        s.toJson()..remove('group');
    return <String, dynamic>{
      if (grouped.isNotEmpty)
        'groups': <Map<String, dynamic>>[
          for (final MapEntry<String, List<FMockScenario>> e in grouped.entries)
            <String, dynamic>{
              'name': e.key,
              'scenarios': e.value.map(scenario).toList(),
            },
        ],
      // An empty `scenarios` still means "this file has a scenarios section"
      // (so Replace can clear them) when there are no groups either.
      if (loose.isNotEmpty || grouped.isEmpty)
        'scenarios': loose.map(scenario).toList(),
    };
  }

  String toJsonString({String? credit}) =>
      const JsonEncoder.withIndent('  ').convert(toJson(credit: credit));
}

/// What an import changed; see `FMockStore.importBundle`.
@immutable
class FMockImportSummary {
  const FMockImportSummary({
    this.rulesAdded = 0,
    this.rulesUpdated = 0,
    this.scenariosAdded = 0,
    this.scenariosUpdated = 0,
  });

  final int rulesAdded;
  final int rulesUpdated;
  final int scenariosAdded;
  final int scenariosUpdated;

  bool get isEmpty =>
      rulesAdded + rulesUpdated + scenariosAdded + scenariosUpdated == 0;

  /// Short human description, e.g. `2 scenarios added, 1 updated`.
  String describe() {
    if (isEmpty) return 'Nothing to import';
    String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
    final List<String> parts = <String>[
      if (scenariosAdded > 0) '${plural(scenariosAdded, 'scenario')} added',
      if (scenariosUpdated > 0) '$scenariosUpdated updated',
      if (rulesAdded > 0) '${plural(rulesAdded, 'rule')} added',
      if (rulesUpdated > 0)
        '$rulesUpdated rule${rulesUpdated == 1 ? '' : 's'} updated',
    ];
    return parts.join(', ');
  }
}
