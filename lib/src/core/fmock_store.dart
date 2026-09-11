import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:fnetwork_inspector/src/core/fmock_persistence.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_meta.dart';
import 'package:fnetwork_inspector/src/model/fmock_rule.dart';
import 'package:fnetwork_inspector/src/model/fmock_scenario.dart';
import 'package:flutter/foundation.dart';

/// In-memory registry of [FMockRule]s and named [FMockScenario]s.
///
/// Mocking is only consulted when the inspector is enabled (debug builds), so
/// rules can never affect a production build where the interceptor is a no-op.
class FMockStore with ChangeNotifier {
  FMockStore._();

  static final FMockStore instance = FMockStore._();

  bool _enabled = true;

  /// Master switch. When false, [match] always returns null regardless of rules.
  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _changed();
  }

  final List<FMockRule> _rules = <FMockRule>[];
  final List<FMockScenario> _scenarios = <FMockScenario>[];
  String? _activeScenarioId;

  FMockPersistence? _persistence;
  Timer? _saveTimer;

  UnmodifiableListView<FMockRule> get rules =>
      UnmodifiableListView<FMockRule>(_rules);

  UnmodifiableListView<FMockScenario> get scenarios =>
      UnmodifiableListView<FMockScenario>(_scenarios);

  String? get activeScenarioId => _activeScenarioId;

  FMockScenario? get activeScenario => _byId(_activeScenarioId);

  /// Number of rules that would currently intercept traffic.
  int get activeCount =>
      _enabled ? _rules.where((FMockRule r) => r.enabled).length : 0;

  // --- rule mutations -------------------------------------------------------

  void add(FMockRule rule) {
    _rules.insert(0, rule);
    _changed();
  }

  void addAll(Iterable<FMockRule> rules) {
    _rules.insertAll(0, rules);
    _changed();
  }

  void updateRule(FMockRule rule) {
    final int i = _rules.indexWhere((FMockRule e) => e.id == rule.id);
    if (i == -1) return;
    _rules[i] = rule;
    _changed();
  }

  void remove(String id) {
    _rules.removeWhere((FMockRule e) => e.id == id);
    _changed();
  }

  void toggle(String id) {
    final int i = _rules.indexWhere((FMockRule e) => e.id == id);
    if (i == -1) return;
    _rules[i] = _rules[i].copyWith(enabled: !_rules[i].enabled);
    _changed();
  }

  void clear() {
    _rules.clear();
    _changed();
  }

  // --- scenarios ---------------------------------------------------------

  void addScenarios(Iterable<FMockScenario> scenarios) {
    _scenarios.addAll(scenarios);
    _changed();
  }

  /// Snapshots the current rules into a scenario. If one with [name] exists it
  /// is overwritten. The new/updated scenario becomes the active one.
  FMockScenario saveAsScenario(String name) {
    final List<FMockRule> snapshot =
        _rules.map((FMockRule r) => r.copyWith()).toList();
    final int existing =
        _scenarios.indexWhere((FMockScenario s) => s.name == name);
    final FMockScenario scenario;
    if (existing >= 0) {
      scenario = _scenarios[existing].copyWith(rules: snapshot);
      _scenarios[existing] = scenario;
    } else {
      scenario = FMockScenario.create(name: name, rules: snapshot);
      _scenarios.add(scenario);
    }
    _activeScenarioId = scenario.id;
    _changed();
    return scenario;
  }

  /// Replaces the live rules with a copy of [id]'s rules.
  void applyScenario(String id) {
    final FMockScenario? scenario = _byId(id);
    if (scenario == null) return;
    _rules
      ..clear()
      ..addAll(scenario.rules.map((FMockRule r) => r.copyWith()));
    _activeScenarioId = id;
    _changed();
  }

  void renameScenario(String id, String name) {
    final int i = _scenarios.indexWhere((FMockScenario s) => s.id == id);
    if (i == -1) return;
    _scenarios[i] = _scenarios[i].copyWith(name: name);
    _changed();
  }

  void deleteScenario(String id) {
    _scenarios.removeWhere((FMockScenario s) => s.id == id);
    if (_activeScenarioId == id) _activeScenarioId = null;
    _changed();
  }

  /// Keeps the current rules but detaches them from the active scenario.
  void detachScenario() {
    if (_activeScenarioId == null) return;
    _activeScenarioId = null;
    _changed();
  }

  // --- persistence -------------------------------------------------------

  /// Wires up a storage delegate: loads any saved state now, then saves
  /// (debounced) on every change. Safe to call once during startup.
  Future<void> attachPersistence(FMockPersistence persistence) async {
    _persistence = persistence;
    final String? data = await persistence.load();
    if (data != null && data.trim().isNotEmpty) {
      try {
        importJson(data, notify: false);
      } catch (_) {
        // ignore corrupt payloads
      }
    }
    notifyListeners();
  }

  void _schedulePersist() {
    final FMockPersistence? p = _persistence;
    if (p == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      p.save(exportJson());
    });
  }

  // --- serialization ---------------------------------------------------------

  /// The full store state as pretty JSON (rules + scenarios + flags).
  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'version': 1,
      '_credit': kFNetworkInspectorUrl,
      'enabled': _enabled,
      'activeScenarioId': _activeScenarioId,
      'rules': _rules.map((FMockRule r) => r.toJson()).toList(),
      'scenarios': _scenarios.map((FMockScenario s) => s.toJson()).toList(),
    });
  }

  /// Loads state from [source] (output of [exportJson], or a bare JSON array of
  /// rules). Replaces everything unless [merge] is true.
  void importJson(String source, {bool notify = true, bool merge = false}) {
    final Object? decoded = jsonDecode(source);

    List<FMockRule> parseRules(List<dynamic> raw) => raw
        .map(
          (dynamic e) => FMockRule.fromJson(
            (e as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList();

    if (decoded is List) {
      final List<FMockRule> rules = parseRules(decoded);
      if (merge) {
        _rules.insertAll(0, rules);
      } else {
        _rules
          ..clear()
          ..addAll(rules);
      }
      if (notify) _changed();
      return;
    }

    final Map<String, dynamic> json =
        (decoded as Map<dynamic, dynamic>).cast<String, dynamic>();
    final List<FMockRule> rules =
        parseRules((json['rules'] as List<dynamic>?) ?? const <dynamic>[]);
    final List<FMockScenario> scenarios =
        ((json['scenarios'] as List<dynamic>?) ?? const <dynamic>[])
            .map(
              (dynamic e) => FMockScenario.fromJson(
                (e as Map<dynamic, dynamic>).cast<String, dynamic>(),
              ),
            )
            .toList();

    if (merge) {
      _rules.insertAll(0, rules);
      _scenarios.addAll(scenarios);
    } else {
      _rules
        ..clear()
        ..addAll(rules);
      _scenarios
        ..clear()
        ..addAll(scenarios);
      _enabled = json['enabled'] as bool? ?? true;
      _activeScenarioId = json['activeScenarioId'] as String?;
    }
    if (notify) _changed();
  }

  // --- matching -------------------------------------------------------

  /// First enabled rule matching the request, or null when mocking is off or
  /// nothing matches.
  FMockRule? match(String method, String path) {
    if (!_enabled) return null;
    for (final FMockRule rule in _rules) {
      if (rule.matches(method, path)) return rule;
    }
    return null;
  }

  /// First rule whose method + path pattern match the request, regardless of
  /// the master switch or the rule's own enabled flag. Used by the request
  /// detail screen to surface the rule behind a (possibly now-disabled) entry.
  FMockRule? ruleFor(String method, String path) {
    for (final FMockRule rule in _rules) {
      if (rule.patternMatches(method, path)) return rule;
    }
    return null;
  }

  // --- housekeeping -------------------------------------------------------

  /// Clears rules, scenarios and the persistence hook.
  void reset() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _persistence = null;
    _rules.clear();
    _scenarios.clear();
    _activeScenarioId = null;
    notifyListeners();
  }

  FMockScenario? _byId(String? id) {
    if (id == null) return null;
    for (final FMockScenario s in _scenarios) {
      if (s.id == id) return s;
    }
    return null;
  }

  void _changed() {
    notifyListeners();
    _schedulePersist();
  }
}
