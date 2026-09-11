import 'dart:math';

import 'package:fnetwork_inspector/src/model/fnetwork_profile.dart';
import 'package:flutter/foundation.dart';

/// Global fault-injection ("chaos") settings: add latency to every request,
/// throttle bandwidth (optionally via a named [FNetworkProfile] like 3G/4G),
/// and randomly fail a fraction of them. Only consulted when the inspector is
/// enabled, so it is a no-op in release builds.
class FChaosStore with ChangeNotifier {
  FChaosStore._();

  static final FChaosStore instance = FChaosStore._();

  /// Overridable for deterministic tests.
  Random random = Random();

  bool _enabled = false;
  int _latencyMs = 0;
  int _downloadKbps = 0;
  int _uploadKbps = 0;
  FNetworkProfile _profile = FNetworkProfile.none;
  double _failRate = 0;
  int _failStatus = 500;
  String _failBody = '{"error":"chaos"}';
  String _failContentType = 'application/json';

  bool get enabled => _enabled;
  set enabled(bool v) => _set(() => _enabled = v, _enabled != v);

  /// Extra round-trip latency added to every request while [enabled].
  /// Setting this directly (rather than via [applyProfile]) marks the
  /// profile as [FNetworkProfile.none] ("Custom").
  int get latencyMs => _latencyMs;
  set latencyMs(int v) {
    final int c = v < 0 ? 0 : v;
    if (_latencyMs == c) return;
    _latencyMs = c;
    _profile = FNetworkProfile.none;
    notifyListeners();
  }

  /// Throttled download throughput in kbps. 0 = unthrottled.
  int get downloadKbps => _downloadKbps;
  set downloadKbps(int v) {
    final int c = v < 0 ? 0 : v;
    if (_downloadKbps == c) return;
    _downloadKbps = c;
    _profile = FNetworkProfile.none;
    notifyListeners();
  }

  /// Throttled upload throughput in kbps. 0 = unthrottled.
  int get uploadKbps => _uploadKbps;
  set uploadKbps(int v) {
    final int c = v < 0 ? 0 : v;
    if (_uploadKbps == c) return;
    _uploadKbps = c;
    _profile = FNetworkProfile.none;
    notifyListeners();
  }

  /// The currently applied network condition preset. [FNetworkProfile.none]
  /// means latency/bandwidth are set manually ("Custom").
  FNetworkProfile get profile => _profile;

  /// True while an [FNetworkProfile.offline] simulation is in effect: every
  /// real request fails with a connection error, bypassing [failRate].
  bool get isOffline => _enabled && _profile == FNetworkProfile.offline;

  /// Applies a named network condition preset (latency + bandwidth) in one
  /// shot. Pass [FNetworkProfile.none] to clear it back to manual latency
  /// with no bandwidth throttling.
  void applyProfile(FNetworkProfile p) {
    final FNetworkProfilePreset? preset = FNetworkProfilePreset.byProfile[p];
    _profile = p;
    if (preset != null) {
      _latencyMs = preset.latencyMs;
      _downloadKbps = preset.downloadKbps;
      _uploadKbps = preset.uploadKbps;
    } else {
      _downloadKbps = 0;
      _uploadKbps = 0;
    }
    notifyListeners();
  }

  /// Fraction of requests (0..1) forced to fail while [enabled].
  double get failRate => _failRate;
  set failRate(double v) {
    final double c = v.clamp(0.0, 1.0);
    _set(() => _failRate = c, _failRate != c);
  }

  int get failStatus => _failStatus;
  set failStatus(int v) => _set(() => _failStatus = v, _failStatus != v);

  String get failBody => _failBody;
  set failBody(String v) => _set(() => _failBody = v, _failBody != v);

  String get failContentType => _failContentType;
  set failContentType(String v) =>
      _set(() => _failContentType = v, _failContentType != v);

  /// Base round-trip latency to apply right now (0 when disabled).
  int get activeDelayMs => _enabled ? _latencyMs : 0;

  /// Extra delay simulating throttled upload bandwidth for a request body of
  /// [bytes] length. 0 when disabled, unthrottled, or empty.
  int uploadDelayMs(int bytes) {
    if (!_enabled || _uploadKbps <= 0 || bytes <= 0) return 0;
    return ((bytes * 8) / _uploadKbps).round();
  }

  /// Extra delay simulating throttled download bandwidth for a response body
  /// of [bytes] length. 0 when disabled, unthrottled, or empty.
  int downloadDelayMs(int bytes) {
    if (!_enabled || _downloadKbps <= 0 || bytes <= 0) return 0;
    return ((bytes * 8) / _downloadKbps).round();
  }

  /// Whether this particular request should be forced to fail with
  /// [failStatus]. Does not cover [isOffline] — callers should check that
  /// first, since offline bypasses the random roll entirely.
  bool shouldFail() =>
      _enabled && _failRate > 0 && random.nextDouble() < _failRate;

  void reset() {
    _enabled = false;
    _latencyMs = 0;
    _downloadKbps = 0;
    _uploadKbps = 0;
    _profile = FNetworkProfile.none;
    _failRate = 0;
    _failStatus = 500;
    _failBody = '{"error":"chaos"}';
    _failContentType = 'application/json';
    notifyListeners();
  }

  void _set(VoidCallback apply, bool changed) {
    if (!changed) return;
    apply();
    notifyListeners();
  }
}
