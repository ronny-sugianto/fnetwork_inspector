import 'dart:convert';

import 'package:fnetwork_inspector/src/core/fmock_store.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_meta.dart';
import 'package:fnetwork_inspector/src/model/fmock_rule.dart';
import 'package:fnetwork_inspector/src/model/fmock_scenario.dart';
import 'package:fnetwork_inspector/src/ui/widget/fnetwork_credit_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

const Color _bg = Color(0xFF0D1117);
const Color _surface = Color(0xFF161B22);
const Color _border = Color(0xFF30363D);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textMuted = Color(0xFF8B949E);
const Color _green = Color(0xFF3FB950);
const Color _red = Color(0xFFF85149);
const Color _orange = Color(0xFFD29922);
const Color _blue = Color(0xFF58A6FF);

const List<String> _methodOptions = <String>[
  'ANY',
  'GET',
  'POST',
  'PUT',
  'PATCH',
  'DELETE',
];

const List<String> _contentTypePresets = <String>[
  'application/json',
  'text/html',
  'text/plain',
  'application/xml',
  'application/octet-stream',
];

Color _methodColor(String method) {
  switch (method.toUpperCase()) {
    case 'GET':
      return _blue;
    case 'POST':
      return _green;
    case 'PUT':
    case 'PATCH':
      return _orange;
    case 'DELETE':
      return _red;
    default:
      return _textMuted;
  }
}

ThemeData _darkTheme() => ThemeData.dark().copyWith(
      scaffoldBackgroundColor: _bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _surface,
        foregroundColor: _textPrimary,
        elevation: 0,
      ),
      dividerColor: _border,
    );

/// Lists and manages in-memory [FMockRule]s.
class NetworkMockListScreen extends StatefulWidget {
  const NetworkMockListScreen({super.key});

  @override
  State<NetworkMockListScreen> createState() => _NetworkMockListScreenState();
}

class _NetworkMockListScreenState extends State<NetworkMockListScreen> {
  final FMockStore _store = FMockStore.instance;

  Future<void> _openEditor({FMockRule? rule}) async {
    final FMockRule? result = await Navigator.of(context).push(
      MaterialPageRoute<FMockRule>(
        builder: (_) => MockRuleEditScreen(initial: rule),
      ),
    );
    if (result == null) return;
    if (rule == null) {
      _store.add(result);
    } else {
      _store.updateRule(result);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveAsScenario() async {
    if (_store.rules.isEmpty) {
      _snack('Add at least one rule first');
      return;
    }
    final String? name = await promptText(
      context,
      title: 'Save as scenario',
      hint: 'e.g. Server error',
      initial: _store.activeScenario?.name ?? '',
    );
    if (name == null || name.trim().isEmpty) return;
    _store.saveAsScenario(name.trim());
    _snack('Scenario "${name.trim()}" saved');
  }

  Future<void> _exportJson() async {
    final String json = _store.exportJson();
    final String fileName =
        'fnetwork-mocks-${DateTime.now().millisecondsSinceEpoch}.json';
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile.fromData(
              utf8.encode(json),
              mimeType: 'application/json',
              name: fileName,
            ),
          ],
          fileNameOverrides: <String>[fileName],
          subject: 'fnetwork mocks',
        ),
      );
    } catch (_) {
      Clipboard.setData(ClipboardData(text: json));
      _snack('Copied mocks JSON to clipboard');
    }
  }

  Future<void> _importJson() async {
    final String? json = await promptText(
      context,
      title: 'Import mocks (JSON)',
      hint: 'Paste exported JSON…',
      multiline: true,
      confirmLabel: 'Import',
    );
    if (json == null || json.trim().isEmpty) return;
    try {
      _store.importJson(json);
      _snack('Mocks imported');
    } catch (_) {
      _snack('Invalid JSON');
    }
  }

  Future<void> _openScenarios() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MockScenarioListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _darkTheme(),
      child: AnimatedBuilder(
        animation: _store,
        builder: (BuildContext context, _) {
          final List<FMockRule> rules = _store.rules;
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Response Mocks',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              actions: <Widget>[
                Text(
                  _store.enabled ? 'On' : 'Off',
                  style: TextStyle(
                    color: _store.enabled ? _green : _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: _store.enabled,
                  onChanged: (bool v) => _store.enabled = v,
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 22),
                  tooltip: 'New mock',
                  onPressed: () => _openEditor(),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: 'More',
                  color: _surface,
                  onSelected: (String value) {
                    switch (value) {
                      case 'save_scenario':
                        _saveAsScenario();
                      case 'scenarios':
                        _openScenarios();
                      case 'export':
                        _exportJson();
                      case 'import':
                        _importJson();
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'save_scenario',
                      child: _MenuRow(Icons.bookmark_add_outlined,
                          'Save as scenario…'),
                    ),
                    PopupMenuItem<String>(
                      value: 'scenarios',
                      child: _MenuRow(
                        Icons.layers_outlined,
                        'Scenarios (${_store.scenarios.length})',
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'export',
                      child: _MenuRow(Icons.ios_share, 'Export (JSON)'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'import',
                      child: _MenuRow(Icons.file_download_outlined,
                          'Import (JSON)…'),
                    ),
                  ],
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: _border),
              ),
            ),
            body: Column(
              children: <Widget>[
                if (_store.activeScenario != null) _buildScenarioBanner(),
                if (!_store.enabled) _buildDisabledBanner(),
                Expanded(
                  child: rules.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          itemCount: rules.length,
                          separatorBuilder: (_, _) =>
                              Container(height: 1, color: _border),
                          itemBuilder: (BuildContext context, int i) =>
                              _buildTile(rules[i]),
                        ),
                ),
              ],
            ),
            bottomNavigationBar: const FNetworkCreditFooter(),
          );
        },
      ),
    );
  }

  Widget _buildDisabledBanner() {
    return Container(
      width: double.infinity,
      color: _orange.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Text(
        'Mocking is off — rules below are inactive.',
        style: TextStyle(color: _orange, fontSize: 12),
      ),
    );
  }

  Widget _buildScenarioBanner() {
    return Container(
      width: double.infinity,
      color: _blue.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: <Widget>[
          const Icon(Icons.layers, size: 14, color: _blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  const TextSpan(
                    text: 'Scenario: ',
                    style: TextStyle(color: _textMuted, fontSize: 12),
                  ),
                  TextSpan(
                    text: _store.activeScenario!.name,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: _store.detachScenario,
            style: TextButton.styleFrom(
              foregroundColor: _textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Detach', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.bolt_outlined, color: _textMuted, size: 40),
            const SizedBox(height: 12),
            const Text(
              'No mock rules',
              style: TextStyle(color: _textMuted, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add one here, or use "Mock this response"\nfrom a captured request.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New mock'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                side: const BorderSide(color: _border),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(FMockRule rule) {
    final Color mColor = _methodColor(rule.method ?? 'ANY');
    final Color statusColor = rule.statusCode >= 200 && rule.statusCode < 300
        ? _green
        : (rule.statusCode >= 400 ? _red : _orange);
    final bool dim = !rule.enabled || !_store.enabled;

    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: InkWell(
        onTap: () => _openEditor(rule: rule),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Switch(
                value: rule.enabled,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (_) => _store.toggle(rule.id),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: mColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            rule.method ?? 'ANY',
                            style: TextStyle(
                              color: mColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rule.pathPattern,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Text(
                          '${rule.statusCode}',
                          style: TextStyle(color: statusColor, fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rule.contentType +
                                (rule.isBase64 ? ' · base64' : '') +
                                (rule.delayMs > 0 ? ' · ${rule.delayMs}ms' : ''),
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: _textMuted,
                tooltip: 'Delete',
                onPressed: () => _store.remove(rule.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Create / edit a single [FMockRule]. Pops the edited rule, or null on cancel.
class MockRuleEditScreen extends StatefulWidget {
  const MockRuleEditScreen({super.key, this.initial, this.title});

  final FMockRule? initial;

  /// Overrides the app-bar title. Defaults to "New Mock" / "Edit Mock".
  final String? title;

  @override
  State<MockRuleEditScreen> createState() => _MockRuleEditScreenState();
}

class _MockRuleEditScreenState extends State<MockRuleEditScreen> {
  late String _method;
  late final TextEditingController _path;
  late final TextEditingController _status;
  late final TextEditingController _contentType;
  late final TextEditingController _body;
  late final TextEditingController _delay;
  late bool _isBase64;
  String? _error;

  @override
  void initState() {
    super.initState();
    final FMockRule? r = widget.initial;
    _method = r?.method ?? 'ANY';
    _path = TextEditingController(text: r?.pathPattern ?? '');
    _status = TextEditingController(text: '${r?.statusCode ?? 200}');
    _contentType =
        TextEditingController(text: r?.contentType ?? 'application/json');
    _body = TextEditingController(text: r?.body ?? '');
    _delay = TextEditingController(text: '${r?.delayMs ?? 0}');
    _isBase64 = r?.isBase64 ?? false;
  }

  @override
  void dispose() {
    _path.dispose();
    _status.dispose();
    _contentType.dispose();
    _body.dispose();
    _delay.dispose();
    super.dispose();
  }

  void _save() {
    final String path = _path.text.trim();
    if (path.isEmpty) {
      setState(() => _error = 'Path pattern is required.');
      return;
    }
    final int? status = int.tryParse(_status.text.trim());
    if (status == null || status < 100 || status > 599) {
      setState(() => _error = 'Status code must be 100–599.');
      return;
    }
    final int delay = int.tryParse(_delay.text.trim()) ?? 0;
    final String contentType = _contentType.text.trim().isEmpty
        ? 'application/octet-stream'
        : _contentType.text.trim();
    final String? method = _method == 'ANY' ? null : _method;

    final FMockRule result = widget.initial == null
        ? FMockRule.create(
            pathPattern: path,
            method: method,
            statusCode: status,
            contentType: contentType,
            body: _body.text,
            isBase64: _isBase64,
            delayMs: delay < 0 ? 0 : delay,
          )
        : widget.initial!.copyWith(
            pathPattern: path,
            method: method,
            statusCode: status,
            contentType: contentType,
            body: _body.text,
            isBase64: _isBase64,
            delayMs: delay < 0 ? 0 : delay,
          );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _darkTheme(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title ??
                (widget.initial == null ? 'New Mock' : 'Edit Mock'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: _blue,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
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
            if (_error != null) ...<Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _red.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: _red, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const _Label('METHOD'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _methodOptions.map((String m) {
                final bool active = _method == m;
                final Color c = _methodColor(m);
                return GestureDetector(
                  onTap: () => setState(() => _method = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? c.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: active ? c : _border,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      m,
                      style: TextStyle(
                        color: active ? c : _textMuted,
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
            const SizedBox(height: 20),
            const _Label('PATH PATTERN'),
            const SizedBox(height: 8),
            _field(
              _path,
              hint: '/api/v1/users/*  or  /profiles/',
              mono: true,
            ),
            const SizedBox(height: 6),
            const Text(
              'Contains "*" → glob match. Otherwise substring match. Query string is ignored.',
              style: TextStyle(color: _textMuted, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _Label('STATUS CODE'),
                      const SizedBox(height: 8),
                      _field(
                        _status,
                        hint: '200',
                        keyboardType: TextInputType.number,
                        mono: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _Label('DELAY (ms)'),
                      const SizedBox(height: 8),
                      _field(
                        _delay,
                        hint: '0',
                        keyboardType: TextInputType.number,
                        mono: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _Label('CONTENT-TYPE'),
            const SizedBox(height: 8),
            _field(_contentType, hint: 'application/json', mono: true),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _contentTypePresets.map((String ct) {
                return GestureDetector(
                  onTap: () => setState(() => _contentType.text = ct),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      ct,
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                const _Label('RESPONSE BODY'),
                const Spacer(),
                const Text(
                  'base64',
                  style: TextStyle(color: _textMuted, fontSize: 11),
                ),
                Switch(
                  value: _isBase64,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (bool v) => setState(() => _isBase64 = v),
                ),
              ],
            ),
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
                minLines: 8,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: _isBase64
                      ? 'Base64-encoded bytes (e.g. an image or PDF)…'
                      : '{ "message": "mocked" }',
                  hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
                  contentPadding: const EdgeInsets.all(12),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isBase64
                  ? 'Served as raw bytes. Invalid base64 resolves to an empty body.'
                  : 'Served as text. JSON content-types are decoded before delivery.',
              style: const TextStyle(
                color: _textMuted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    bool mono = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: _textPrimary,
        fontSize: 13,
        fontFamily: mono ? 'monospace' : null,
      ),
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

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: _textMuted),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: _textPrimary, fontSize: 13)),
      ],
    );
  }
}

/// Small reusable single/multi-line text prompt. Returns the entered text, or
/// null on cancel.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? hint,
  String initial = '',
  bool multiline = false,
  String confirmLabel = 'Save',
}) {
  final TextEditingController controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: _surface,
      title: Text(
        title,
        style: const TextStyle(color: _textPrimary, fontSize: 15),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: multiline ? 8 : 1,
        minLines: multiline ? 4 : 1,
        style: TextStyle(
          color: _textPrimary,
          fontSize: 13,
          fontFamily: multiline ? 'monospace' : null,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: _border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: _blue),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel', style: TextStyle(color: _textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: Text(confirmLabel, style: const TextStyle(color: _blue)),
        ),
      ],
    ),
  );
}

/// Lists saved [FMockScenario]s: tap to apply, per-row menu to rename / share /
/// delete, and a button to snapshot the current rules as a new scenario.
class MockScenarioListScreen extends StatefulWidget {
  const MockScenarioListScreen({super.key});

  @override
  State<MockScenarioListScreen> createState() => _MockScenarioListScreenState();
}

class _MockScenarioListScreenState extends State<MockScenarioListScreen> {
  final FMockStore _store = FMockStore.instance;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveCurrent() async {
    if (_store.rules.isEmpty) {
      _snack('Add at least one rule first');
      return;
    }
    final String? name = await promptText(
      context,
      title: 'Save as scenario',
      hint: 'e.g. Empty list',
    );
    if (name == null || name.trim().isEmpty) return;
    _store.saveAsScenario(name.trim());
    _snack('Scenario "${name.trim()}" saved');
  }

  Future<void> _rename(FMockScenario s) async {
    final String? name = await promptText(
      context,
      title: 'Rename scenario',
      initial: s.name,
    );
    if (name == null || name.trim().isEmpty) return;
    _store.renameScenario(s.id, name.trim());
  }

  Future<void> _share(FMockScenario s) async {
    final String json = const JsonEncoder.withIndent('  ').convert(
      <String, dynamic>{
        'version': 1,
        '_credit': kFNetworkInspectorUrl,
        'scenarios': <dynamic>[s.toJson()],
      },
    );
    final String fileName =
        'scenario-${s.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}.json';
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile.fromData(
              utf8.encode(json),
              mimeType: 'application/json',
              name: fileName,
            ),
          ],
          fileNameOverrides: <String>[fileName],
          subject: 'fnetwork scenario: ${s.name}',
        ),
      );
    } catch (_) {
      Clipboard.setData(ClipboardData(text: json));
      _snack('Copied scenario JSON to clipboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _darkTheme(),
      child: AnimatedBuilder(
        animation: _store,
        builder: (BuildContext context, _) {
          final List<FMockScenario> list = _store.scenarios;
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Scenarios',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                  tooltip: 'Save current rules as scenario',
                  onPressed: _saveCurrent,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: _border),
              ),
            ),
            body: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.layers_outlined,
                              color: _textMuted, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                            'No scenarios yet',
                            style: TextStyle(color: _textMuted, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Build up some mock rules, then save them\nas a named scenario to switch back to later.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _textMuted, fontSize: 12, height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _saveCurrent,
                            icon: const Icon(Icons.bookmark_add_outlined,
                                size: 18),
                            label: const Text('Save current rules'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _blue,
                              side: const BorderSide(color: _border),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        Container(height: 1, color: _border),
                    itemBuilder: (BuildContext context, int i) =>
                        _buildTile(list[i]),
                  ),
            bottomNavigationBar: const FNetworkCreditFooter(),
          );
        },
      ),
    );
  }

  Widget _buildTile(FMockScenario s) {
    final bool active = _store.activeScenarioId == s.id;
    return InkWell(
      onTap: () {
        _store.applyScenario(s.id);
        Navigator.of(context).pop();
        _snack('Applied "${s.name}"');
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          s.name,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (active) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _green.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: _green,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${s.rules.length} rule${s.rules.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: _textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: _textMuted),
              color: _surface,
              onSelected: (String v) {
                switch (v) {
                  case 'apply':
                    _store.applyScenario(s.id);
                    _snack('Applied "${s.name}"');
                  case 'rename':
                    _rename(s);
                  case 'share':
                    _share(s);
                  case 'delete':
                    _store.deleteScenario(s.id);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'apply',
                  child: _MenuRow(Icons.play_arrow, 'Apply'),
                ),
                const PopupMenuItem<String>(
                  value: 'rename',
                  child: _MenuRow(Icons.edit_outlined, 'Rename'),
                ),
                const PopupMenuItem<String>(
                  value: 'share',
                  child: _MenuRow(Icons.ios_share, 'Share (JSON)'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: _MenuRow(Icons.delete_outline, 'Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
