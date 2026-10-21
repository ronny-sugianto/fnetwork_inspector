import 'package:fnetwork_inspector/src/model/fmock_rule.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// A named snapshot of a set of [FMockRule]s. Apply one to swap the whole
/// mock configuration at once (e.g. "logged out", "empty list", "server 500").
///
/// Scenarios can be organised under a [group] (e.g. a feature or release such
/// as "Checkout Revamp v2.0"); the Scenarios screen lists them under
/// one header per group. Scenarios without a group appear under "Other".
@immutable
class FMockScenario {
  const FMockScenario({
    required this.id,
    required this.name,
    required this.rules,
    this.group,
  });

  factory FMockScenario.create({
    required String name,
    required List<FMockRule> rules,
    String? group,
  }) {
    return FMockScenario(
      id: const Uuid().v4(),
      name: name,
      rules: rules,
      group: cleanGroup(group),
    );
  }

  factory FMockScenario.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        (json['rules'] as List<dynamic>?) ?? const <dynamic>[];
    return FMockScenario(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Untitled',
      group: cleanGroup(json['group'] as String?),
      rules:
          raw
              .map(
                (dynamic e) => FMockRule.fromJson(
                  (e as Map<dynamic, dynamic>).cast<String, dynamic>(),
                ),
              )
              .toList(),
    );
  }

  final String id;
  final String name;
  final List<FMockRule> rules;

  /// Optional group this scenario is listed under. `null` = ungrouped.
  final String? group;

  /// Trims [group]; blank becomes `null` (ungrouped).
  static String? cleanGroup(String? group) {
    final String? g = group?.trim();
    return (g == null || g.isEmpty) ? null : g;
  }

  /// Pass `group: null` to move the scenario out of its group.
  FMockScenario copyWith({
    String? name,
    List<FMockRule>? rules,
    Object? group = _keep,
  }) {
    return FMockScenario(
      id: id,
      name: name ?? this.name,
      rules: rules ?? this.rules,
      group:
          identical(group, _keep) ? this.group : cleanGroup(group as String?),
    );
  }

  static const Object _keep = Object();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    if (group != null) 'group': group,
    'rules': rules.map((FMockRule r) => r.toJson()).toList(),
  };
}
