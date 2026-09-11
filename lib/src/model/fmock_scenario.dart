import 'package:fnetwork_inspector/src/model/fmock_rule.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// A named snapshot of a set of [FMockRule]s. Apply one to swap the whole
/// mock configuration at once (e.g. "logged out", "empty list", "server 500").
@immutable
class FMockScenario {
  const FMockScenario({
    required this.id,
    required this.name,
    required this.rules,
  });

  factory FMockScenario.create({
    required String name,
    required List<FMockRule> rules,
  }) {
    return FMockScenario(id: const Uuid().v4(), name: name, rules: rules);
  }

  factory FMockScenario.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        (json['rules'] as List<dynamic>?) ?? const <dynamic>[];
    return FMockScenario(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Untitled',
      rules: raw
          .map(
            (dynamic e) =>
                FMockRule.fromJson((e as Map<dynamic, dynamic>).cast<String, dynamic>()),
          )
          .toList(),
    );
  }

  final String id;
  final String name;
  final List<FMockRule> rules;

  FMockScenario copyWith({String? name, List<FMockRule>? rules}) {
    return FMockScenario(
      id: id,
      name: name ?? this.name,
      rules: rules ?? this.rules,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'rules': rules.map((FMockRule r) => r.toJson()).toList(),
      };
}
