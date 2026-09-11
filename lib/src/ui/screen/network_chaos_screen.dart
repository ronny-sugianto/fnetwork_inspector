import 'package:fnetwork_inspector/src/core/fchaos_store.dart';
import 'package:fnetwork_inspector/src/model/fnetwork_profile.dart';
import 'package:fnetwork_inspector/src/ui/widget/fnetwork_credit_footer.dart';
import 'package:flutter/material.dart';

const Color _bg = Color(0xFF0D1117);
const Color _surface = Color(0xFF161B22);
const Color _border = Color(0xFF30363D);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textMuted = Color(0xFF8B949E);
const Color _green = Color(0xFF3FB950);
const Color _red = Color(0xFFF85149);
const Color _orange = Color(0xFFD29922);
const Color _blue = Color(0xFF58A6FF);

const List<int> _statusPresets = <int>[400, 401, 403, 404, 429, 500, 502, 503];

/// Tune global fault injection: extra latency on every request and a random
/// failure rate. Great for exercising loading states, timeouts and retry logic.
class NetworkChaosScreen extends StatefulWidget {
  const NetworkChaosScreen({super.key});

  @override
  State<NetworkChaosScreen> createState() => _NetworkChaosScreenState();
}

class _NetworkChaosScreenState extends State<NetworkChaosScreen> {
  final FChaosStore _chaos = FChaosStore.instance;
  late final TextEditingController _body;
  late final TextEditingController _contentType;

  @override
  void initState() {
    super.initState();
    _body = TextEditingController(text: _chaos.failBody);
    _contentType = TextEditingController(text: _chaos.failContentType);
  }

  @override
  void dispose() {
    _body.dispose();
    _contentType.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: _surface,
          foregroundColor: _textPrimary,
          elevation: 0,
        ),
        dividerColor: _border,
      ),
      child: AnimatedBuilder(
        animation: _chaos,
        builder: (BuildContext context, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Chaos mode',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              actions: <Widget>[
                Text(
                  _chaos.enabled ? 'On' : 'Off',
                  style: TextStyle(
                    color: _chaos.enabled ? _green : _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: _chaos.enabled,
                  onChanged: (bool v) => _chaos.enabled = v,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: _border),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _summaryCard(),
                const SizedBox(height: 16),
                const _Label('NETWORK PROFILE'),
                const SizedBox(height: 4),
                const Text(
                  'Simulate a connection type instead of tuning raw ms — '
                  'sets latency and throttles bandwidth together.',
                  style: TextStyle(color: _textMuted, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <FNetworkProfile>[
                    FNetworkProfile.offline,
                    FNetworkProfile.twoG,
                    FNetworkProfile.edge,
                    FNetworkProfile.threeG,
                    FNetworkProfile.fourG,
                    FNetworkProfile.fiveG,
                  ].map(_profileChip).toList(),
                ),
                const SizedBox(height: 16),
                const _Label('ADDED LATENCY'),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Slider(
                        value: _chaos.latencyMs
                            .toDouble()
                            .clamp(0, 5000)
                            .toDouble(),
                        max: 5000,
                        divisions: 50,
                        activeColor: _blue,
                        label: '${_chaos.latencyMs} ms',
                        onChanged: (double v) =>
                            _chaos.latencyMs = v.round(),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${_chaos.latencyMs} ms',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _Label('DOWNLOAD SPEED'),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Slider(
                        value: _chaos.downloadKbps
                            .toDouble()
                            .clamp(0, 50000)
                            .toDouble(),
                        max: 50000,
                        divisions: 50,
                        activeColor: _blue,
                        label: _formatKbps(_chaos.downloadKbps),
                        onChanged: (double v) =>
                            _chaos.downloadKbps = v.round(),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        _formatKbps(_chaos.downloadKbps),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _Label('UPLOAD SPEED'),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Slider(
                        value: _chaos.uploadKbps
                            .toDouble()
                            .clamp(0, 50000)
                            .toDouble(),
                        max: 50000,
                        divisions: 50,
                        activeColor: _blue,
                        label: _formatKbps(_chaos.uploadKbps),
                        onChanged: (double v) =>
                            _chaos.uploadKbps = v.round(),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        _formatKbps(_chaos.uploadKbps),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _chaos.downloadKbps <= 0 && _chaos.uploadKbps <= 0
                      ? '0 = unthrottled (only latency applies).'
                      : 'Extra delay is estimated from payload size at this speed.',
                  style: const TextStyle(color: _textMuted, fontSize: 11),
                ),
                const SizedBox(height: 12),
                const _Label('FAILURE RATE'),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Slider(
                        value: (_chaos.failRate * 100).clamp(0, 100),
                        max: 100,
                        divisions: 100,
                        activeColor: _red,
                        label: '${(_chaos.failRate * 100).round()}%',
                        onChanged: (double v) => _chaos.failRate = v / 100,
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${(_chaos.failRate * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _Label('FAILURE STATUS'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _statusPresets.map((int s) {
                    final bool active = _chaos.failStatus == s;
                    return GestureDetector(
                      onTap: () => _chaos.failStatus = s,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? _red.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: active ? _red : _border,
                            width: active ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          '$s',
                          style: TextStyle(
                            color: active ? _red : _textMuted,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const _Label('FAILURE CONTENT-TYPE'),
                const SizedBox(height: 8),
                _textField(
                  _contentType,
                  hint: 'application/json',
                  onChanged: (String v) => _chaos.failContentType = v,
                ),
                const SizedBox(height: 16),
                const _Label('FAILURE BODY'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    controller: _body,
                    maxLines: null,
                    minLines: 5,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: '{ "error": "chaos" }',
                      hintStyle: TextStyle(color: _textMuted, fontSize: 12),
                      contentPadding: EdgeInsets.all(12),
                      border: InputBorder.none,
                    ),
                    onChanged: (String v) => _chaos.failBody = v,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Mock rules always win over chaos. Latency and bandwidth '
                  'delay are added on top of the real network time; the '
                  'Offline profile fails every request with a connection '
                  'error before it leaves the device, ignoring the failure '
                  'rate below.',
                  style: TextStyle(color: _textMuted, fontSize: 11, height: 1.5),
                ),
              ],
            ),
            bottomNavigationBar: const FNetworkCreditFooter(),
          );
        },
      ),
    );
  }

  Widget _summaryCard() {
    final int pct = (_chaos.failRate * 100).round();
    final bool offline = _chaos.isOffline;
    final FNetworkProfilePreset? preset =
        FNetworkProfilePreset.byProfile[_chaos.profile];
    final String text = !_chaos.enabled
        ? 'Chaos is off.'
        : offline
            ? 'Offline — every request fails with a connection error.'
            : <String>[
                if (preset != null) preset.label,
                if (_chaos.latencyMs > 0) '+${_chaos.latencyMs} ms',
                if (_chaos.downloadKbps > 0)
                  '↓${_formatKbps(_chaos.downloadKbps)}',
                if (_chaos.uploadKbps > 0)
                  '↑${_formatKbps(_chaos.uploadKbps)}',
                if (pct > 0)
                  '≈$pct% fail with ${_chaos.failStatus}'
                else
                  'no forced failures',
              ].join('  ·  ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (_chaos.enabled ? _orange : _textMuted).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (_chaos.enabled ? _orange : _border).withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _chaos.enabled ? _orange : _textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _profileChip(FNetworkProfile p) {
    final FNetworkProfilePreset preset = FNetworkProfilePreset.byProfile[p]!;
    final bool active = _chaos.profile == p;
    final Color color = p == FNetworkProfile.offline ? _red : _blue;
    return GestureDetector(
      onTap: () => _chaos.applyProfile(active ? FNetworkProfile.none : p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? color : _border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              preset.label,
              style: TextStyle(
                color: active ? color : _textPrimary,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            Text(
              p == FNetworkProfile.offline
                  ? 'no connection'
                  : '${preset.latencyMs}ms · ↓${_formatKbps(preset.downloadKbps)}',
              style: const TextStyle(color: _textMuted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  String _formatKbps(int kbps) {
    if (kbps <= 0) return 'Off';
    if (kbps >= 1000) return '${(kbps / 1000).toStringAsFixed(1)} Mbps';
    return '$kbps kbps';
  }

  Widget _textField(
    TextEditingController controller, {
    String? hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 13,
        fontFamily: 'monospace',
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
        filled: true,
        fillColor: _surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _textMuted,
        fontSize: 10,
        letterSpacing: 1,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
