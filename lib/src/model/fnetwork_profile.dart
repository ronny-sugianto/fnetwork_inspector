/// Simulated network condition for chaos mode — models both round-trip
/// latency and throttled bandwidth, not just a flat delay.
enum FNetworkProfile {
  /// No profile applied. Chaos's manual latency/fail-rate settings are used
  /// as-is; no bandwidth throttling.
  none,

  /// Airplane-mode style outage: every request fails with a connection error,
  /// regardless of the configured failure rate.
  offline,

  /// 2G / GPRS-class connection.
  twoG,

  /// EDGE (2.5G) connection — faster than plain 2G, still very slow.
  edge,

  /// 3G connection.
  threeG,

  /// 4G / LTE connection.
  fourG,

  /// 5G / fast Wi-Fi-class connection.
  fiveG,
}

/// Approximate real-world figures for a [FNetworkProfile]. [latencyMs] is a
/// one-off round-trip delay applied once per request; [downloadKbps] /
/// [uploadKbps] throttle throughput and add extra delay proportional to
/// payload size (0 = unthrottled). Figures are ballpark, modeled after common
/// DevTools / Network Link Conditioner presets — real carriers vary widely.
class FNetworkProfilePreset {
  const FNetworkProfilePreset({
    required this.label,
    required this.latencyMs,
    required this.downloadKbps,
    required this.uploadKbps,
  });

  final String label;
  final int latencyMs;
  final int downloadKbps;
  final int uploadKbps;

  static const Map<FNetworkProfile, FNetworkProfilePreset> byProfile =
      <FNetworkProfile, FNetworkProfilePreset>{
    FNetworkProfile.offline: FNetworkProfilePreset(
      label: 'Offline',
      latencyMs: 0,
      downloadKbps: 0,
      uploadKbps: 0,
    ),
    FNetworkProfile.twoG: FNetworkProfilePreset(
      label: '2G',
      latencyMs: 800,
      downloadKbps: 50,
      uploadKbps: 20,
    ),
    FNetworkProfile.edge: FNetworkProfilePreset(
      label: 'Edge',
      latencyMs: 400,
      downloadKbps: 250,
      uploadKbps: 200,
    ),
    FNetworkProfile.threeG: FNetworkProfilePreset(
      label: '3G',
      latencyMs: 150,
      downloadKbps: 1000,
      uploadKbps: 500,
    ),
    FNetworkProfile.fourG: FNetworkProfilePreset(
      label: '4G',
      latencyMs: 40,
      downloadKbps: 6000,
      uploadKbps: 3000,
    ),
    FNetworkProfile.fiveG: FNetworkProfilePreset(
      label: '5G',
      latencyMs: 5,
      downloadKbps: 50000,
      uploadKbps: 20000,
    ),
  };
}
