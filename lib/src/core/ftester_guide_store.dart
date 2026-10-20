import 'dart:convert';

import 'package:fnetwork_inspector/src/core/finspector_storage.dart';
import 'package:fnetwork_inspector/src/model/ftester_guide.dart';
import 'package:flutter/foundation.dart';

/// Holds the configured [FTesterGuide] and whether it should pop up at startup.
class FTesterGuideStore with ChangeNotifier {
  FTesterGuideStore._();

  static final FTesterGuideStore instance = FTesterGuideStore._();

  static const String storageKey = 'fnetwork_inspector.tester_guide';

  FTesterGuide? _guide;
  FInspectorStorage? _storage;

  /// The guide version the tester chose "don't show again" for, if any.
  int? _hiddenVersion;
  bool _shownThisSession = false;

  FTesterGuide? get guide => _guide;

  /// Whether the guide is set to appear at startup (the menu switch). A guide
  /// hidden at an older version is considered visible again.
  bool get showAtStartup {
    final FTesterGuide? g = _guide;
    if (g == null) return false;
    final int? hidden = _hiddenVersion;
    return hidden == null || hidden < g.version;
  }

  /// Startup should show it now: enabled, and not already shown this session.
  bool get shouldAutoShow => showAtStartup && !_shownThisSession;

  /// Call once the startup dialog has been displayed.
  void markShownThisSession() => _shownThisSession = true;

  Future<void> configure(FTesterGuide guide, FInspectorStorage? storage) async {
    _guide = guide;
    _storage = storage;
    _hiddenVersion = null;
    if (storage != null) {
      try {
        final String? raw = await storage.read(storageKey);
        if (raw != null && raw.isNotEmpty) {
          final Object? json = jsonDecode(raw);
          if (json is Map<String, dynamic>) {
            _hiddenVersion = (json['hiddenVersion'] as num?)?.toInt();
          }
        }
      } catch (_) {
        // ignore unreadable/corrupt state
      }
    }
    notifyListeners();
  }

  void setShowAtStartup(bool value) {
    final FTesterGuide? g = _guide;
    if (g == null) return;
    _hiddenVersion = value ? null : g.version;
    notifyListeners();
    final FInspectorStorage? s = _storage;
    if (s != null) {
      s.write(
        storageKey,
        jsonEncode(<String, dynamic>{'hiddenVersion': _hiddenVersion}),
      );
    }
  }

  void reset() {
    _guide = null;
    _storage = null;
    _hiddenVersion = null;
    _shownThisSession = false;
    notifyListeners();
  }
}
