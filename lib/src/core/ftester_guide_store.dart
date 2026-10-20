import 'dart:convert';

import 'package:fnetwork_inspector/src/core/finspector_storage.dart';
import 'package:fnetwork_inspector/src/model/ftester_guide.dart';
import 'package:flutter/foundation.dart';

/// Holds the configured [FTesterGuide]s (one per audience) and whether the
/// guide should pop up at startup.
class FTesterGuideStore with ChangeNotifier {
  FTesterGuideStore._();

  static final FTesterGuideStore instance = FTesterGuideStore._();

  static const String storageKey = 'fnetwork_inspector.tester_guide';

  List<FTesterGuide> _guides = const <FTesterGuide>[];
  int _selected = 0;
  FInspectorStorage? _storage;

  /// The guide version the tester chose "don't show again" for, if any.
  int? _hiddenVersion;
  bool _shownThisSession = false;

  /// All configured guides (more than one → the dialog shows an audience
  /// switcher).
  List<FTesterGuide> get guides => _guides;

  int get selectedIndex => _selected;

  /// The guide for the currently selected audience, or null when none is
  /// configured.
  FTesterGuide? get guide => _guides.isEmpty ? null : _guides[_selected];

  /// Highest [FTesterGuide.version] among the configured guides: bumping any
  /// of them makes the guide appear once more.
  int get contentVersion => _guides.fold<int>(
    0,
    (int max, FTesterGuide g) => g.version > max ? g.version : max,
  );

  /// Whether the guide is set to appear at startup (the menu switch). A guide
  /// hidden at an older version is considered visible again.
  bool get showAtStartup {
    if (_guides.isEmpty) return false;
    final int? hidden = _hiddenVersion;
    return hidden == null || hidden < contentVersion;
  }

  /// Startup should show it now: enabled, and not already shown this session.
  bool get shouldAutoShow => showAtStartup && !_shownThisSession;

  /// Call once the startup dialog has been displayed.
  void markShownThisSession() => _shownThisSession = true;

  Future<void> configure(FTesterGuide guide, FInspectorStorage? storage) =>
      configureAll(<FTesterGuide>[guide], storage);

  Future<void> configureAll(
    List<FTesterGuide> guides,
    FInspectorStorage? storage,
  ) async {
    _guides = List<FTesterGuide>.unmodifiable(guides);
    _storage = storage;
    _hiddenVersion = null;
    _selected = 0;
    if (storage != null) {
      try {
        final String? raw = await storage.read(storageKey);
        if (raw != null && raw.isNotEmpty) {
          final Object? json = jsonDecode(raw);
          if (json is Map<String, dynamic>) {
            _hiddenVersion = (json['hiddenVersion'] as num?)?.toInt();
            final Object? label = json['selected'];
            if (label is String) {
              final int i = _guides.indexWhere(
                (FTesterGuide g) => g.label == label,
              );
              if (i >= 0) _selected = i;
            }
          }
        }
      } catch (_) {
        // ignore unreadable/corrupt state
      }
    }
    notifyListeners();
  }

  void setShowAtStartup(bool value) {
    if (_guides.isEmpty) return;
    _hiddenVersion = value ? null : contentVersion;
    notifyListeners();
    _persist();
  }

  /// Switches the audience shown in the dialog (remembered across launches).
  void select(int index) {
    if (_guides.isEmpty) return;
    final int i = index.clamp(0, _guides.length - 1);
    if (i == _selected) return;
    _selected = i;
    notifyListeners();
    _persist();
  }

  void _persist() {
    final FInspectorStorage? s = _storage;
    if (s == null) return;
    final String? label = guide?.label;
    s.write(
      storageKey,
      jsonEncode(<String, dynamic>{
        'hiddenVersion': _hiddenVersion,
        if (_guides.length > 1 && label != null) 'selected': label,
      }),
    );
  }

  void reset() {
    _guides = const <FTesterGuide>[];
    _selected = 0;
    _storage = null;
    _hiddenVersion = null;
    _shownThisSession = false;
    notifyListeners();
  }
}
