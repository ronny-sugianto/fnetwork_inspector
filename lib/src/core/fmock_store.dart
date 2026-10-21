import 'dart:async';
import 'dart:collection';
import 'package:fnetwork_inspector/src/core/fmock_persistence.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_meta.dart';
import 'package:fnetwork_inspector/src/model/fmock_bundle.dart';
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
  bool _restoredFromStorage = false;
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

  /// Distinct scenario groups, in the order they first appear. Ungrouped
  /// scenarios are not included.
  List<String> get scenarioGroups {
    final List<String> groups = <String>[];
    for (final FMockScenario s in _scenarios) {
      final String? g = s.group;
      if (g != null && !groups.contains(g)) groups.add(g);
    }
    return groups;
  }

  /// Snapshots the current rules into a scenario, optionally under [group]. If
  /// one with the same [name] **and group** exists it is overwritten. The
  /// new/updated scenario becomes the active one.
  FMockScenario saveAsScenario(String name, {String? group}) {
    final String? g = FMockScenario.cleanGroup(group);
    final List<FMockRule> snapshot =
        _rules.map((FMockRule r) => r.copyWith()).toList();
    final int existing = _scenarios.indexWhere(
      (FMockScenario s) => s.name == name && s.group == g,
    );
    final FMockScenario scenario;
    if (existing >= 0) {
      scenario = _scenarios[existing].copyWith(rules: snapshot);
      _scenarios[existing] = scenario;
    } else {
      scenario = FMockScenario.create(name: name, rules: snapshot, group: g);
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

  /// Moves a scenario into [group], or out of any group when it is null/blank.
  void setScenarioGroup(String id, String? group) {
    final int i = _scenarios.indexWhere((FMockScenario s) => s.id == id);
    if (i == -1) return;
    _scenarios[i] = _scenarios[i].copyWith(group: group);
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
        _restoredFromStorage = true;
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

  /// The full store state — live rules, scenarios and flags — as pretty JSON
  /// (a `.fnmock.json` file).
  String exportJson() => FMockBundle(
    rules: _rules,
    scenarios: _scenarios,
    enabled: _enabled,
    activeScenarioId: _activeScenarioId,
  ).toJsonString(credit: kFNetworkInspectorUrl);

  /// Just the given [scenarios] as a `.fnmock.json` file: importing it never
  /// touches live rules or the master switch.
  String exportScenariosJson(Iterable<FMockScenario> scenarios) => FMockBundle(
    scenarios: scenarios.toList(),
  ).toJsonString(credit: kFNetworkInspectorUrl);

  /// Scenarios in [group] (`null` = the ungrouped ones).
  List<FMockScenario> scenariosInGroup(String? group) =>
      _scenarios.where((FMockScenario s) => s.group == group).toList();

  /// Loads a mock file ([exportJson] / [exportScenariosJson] output, a file from
  /// an earlier version, or a bare JSON array of rules).
  ///
  /// With [merge] false (the default, and what persistence uses) every section
  /// the file contains **replaces** the store's. With [merge] true, incoming
  /// items are added and ones that already exist (same id, or same name in the
  /// same group) are updated in place; nothing else is touched.
  ///
  /// Throws [FormatException] if [source] is not a valid mock file.
  FMockImportSummary importJson(
    String source, {
    bool notify = true,
    bool merge = false,
  }) => importBundle(FMockBundle.parse(source), merge: merge, notify: notify);

  /// Applies an already parsed [bundle]; see [importJson] for [merge].
  FMockImportSummary importBundle(
    FMockBundle bundle, {
    bool merge = true,
    bool notify = true,
  }) {
    int rulesAdded = 0;
    int rulesUpdated = 0;
    int scenariosAdded = 0;
    int scenariosUpdated = 0;

    final List<FMockRule>? rules = bundle.rules;
    if (rules != null) {
      if (merge) {
        // Reversed so inserting at the front keeps the file's order.
        for (final FMockRule r in rules.reversed) {
          final int i = _rules.indexWhere((FMockRule e) => e.id == r.id);
          if (i >= 0) {
            _rules[i] = r;
            rulesUpdated++;
          } else {
            _rules.insert(0, r);
            rulesAdded++;
          }
        }
      } else {
        _rules
          ..clear()
          ..addAll(rules);
        rulesAdded = rules.length;
      }
    }

    final List<FMockScenario>? scenarios = bundle.scenarios;
    if (scenarios != null) {
      if (merge) {
        for (final FMockScenario s in scenarios) {
          _upsertScenario(s) ? scenariosUpdated++ : scenariosAdded++;
        }
      } else {
        _scenarios
          ..clear()
          ..addAll(scenarios);
        scenariosAdded = scenarios.length;
        if (_byId(_activeScenarioId) == null) _activeScenarioId = null;
      }
    }

    if (!merge) {
      if (bundle.enabled != null) _enabled = bundle.enabled!;
      if (bundle.activeScenarioId != null &&
          _byId(bundle.activeScenarioId) != null) {
        _activeScenarioId = bundle.activeScenarioId;
      }
    }

    if (notify) _changed();
    return FMockImportSummary(
      rulesAdded: rulesAdded,
      rulesUpdated: rulesUpdated,
      scenariosAdded: scenariosAdded,
      scenariosUpdated: scenariosUpdated,
    );
  }

  /// Replaces the scenario with the same id — or, failing that, the same name in
  /// the same group — or appends it. Returns true if it replaced one.
  bool _upsertScenario(FMockScenario s) {
    int i = _scenarios.indexWhere((FMockScenario e) => e.id == s.id);
    if (i < 0) {
      i = _scenarios.indexWhere(
        (FMockScenario e) => e.name == s.name && e.group == s.group,
      );
    }
    if (i < 0) {
      _scenarios.add(s);
      return false;
    }
    final String oldId = _scenarios[i].id;
    _scenarios[i] = s;
    if (_activeScenarioId == oldId) _activeScenarioId = s.id;
    return true;
  }

  /// Applies the app-supplied seeds from `FNetworkInspector.initialize`.
  ///
  /// * [rules] only seed an empty store (their ids are random, so re-adding
  ///   them every launch would duplicate them).
  /// * [scenarios] and [json] are upserted on every launch: the code is the
  ///   source of truth for the scenarios it defines, while scenarios a tester
  ///   created in the UI are left alone.
  /// * [activeScenarioId] is applied unless a previous session was restored
  ///   from persistence (the tester's last state wins).
  ///
  /// An unreadable [json] is reported with `debugPrint` and skipped rather than
  /// stopping the app from starting.
  void seed({
    List<FMockRule>? rules,
    List<FMockScenario>? scenarios,
    String? json,
    String? activeScenarioId,
  }) {
    if (rules != null && rules.isNotEmpty && _rules.isEmpty) {
      _rules.addAll(rules);
    }
    if (scenarios != null) {
      for (final FMockScenario s in scenarios) {
        _upsertScenario(s);
      }
    }
    if (json != null && json.trim().isNotEmpty) {
      try {
        importBundle(FMockBundle.parse(json), merge: true, notify: false);
      } on FormatException catch (e) {
        debugPrint('fnetwork_inspector: ignoring invalid mockJson: $e');
      }
    }
    if (activeScenarioId != null && !_restoredFromStorage) {
      if (_byId(activeScenarioId) != null) {
        final FMockScenario s = _byId(activeScenarioId)!;
        _rules
          ..clear()
          ..addAll(s.rules.map((FMockRule r) => r.copyWith()));
        _activeScenarioId = activeScenarioId;
      } else {
        debugPrint(
          'fnetwork_inspector: activeMockScenario "$activeScenarioId" not found',
        );
      }
    }
    _changed();
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
    _restoredFromStorage = false;
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
