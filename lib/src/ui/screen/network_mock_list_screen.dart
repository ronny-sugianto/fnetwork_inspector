import 'package:fnetwork_inspector/src/core/fmock_store.dart';
import 'package:fnetwork_inspector/src/model/fmock_rule.dart';
import 'package:fnetwork_inspector/src/ui/screen/mock_common.dart';
import 'package:fnetwork_inspector/src/ui/widget/fnetwork_credit_footer.dart';
import 'package:flutter/material.dart';

export 'package:fnetwork_inspector/src/ui/screen/mock_common.dart'
    show promptText;

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

/// Lists and manages the live, in-memory [FMockRule]s — the ones that are
/// answering requests right now.
///
/// Named sets of rules (and importing / exporting them) live on
/// [MockScenarioListScreen].
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: mockDarkTheme(),
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
                    color: _store.enabled ? mockGreen : mockTextMuted,
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
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: mockBorder),
              ),
            ),
            body: Column(
              children: <Widget>[
                if (!_store.enabled) _buildDisabledBanner(),
                Expanded(
                  child:
                      rules.isEmpty
                          ? _buildEmpty()
                          : ListView.separated(
                            itemCount: rules.length,
                            separatorBuilder:
                                (_, _) =>
                                    Container(height: 1, color: mockBorder),
                            itemBuilder:
                                (BuildContext context, int i) => MockRuleTile(
                                  rule: rules[i],
                                  dim: !rules[i].enabled || !_store.enabled,
                                  onTap: () => _openEditor(rule: rules[i]),
                                  onToggle: () => _store.toggle(rules[i].id),
                                  onDelete: () => _store.remove(rules[i].id),
                                ),
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
      color: mockOrange.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Text(
        'Mocking is off — rules below are inactive.',
        style: TextStyle(color: mockOrange, fontSize: 12),
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
            const Icon(Icons.bolt_outlined, color: mockTextMuted, size: 40),
            const SizedBox(height: 12),
            const Text(
              'No mock rules',
              style: TextStyle(color: mockTextMuted, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add one here, or use "Mock this response"\nfrom a captured request.',
              textAlign: TextAlign.center,
              style: TextStyle(color: mockTextMuted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New mock'),
              style: OutlinedButton.styleFrom(
                foregroundColor: mockBlue,
                side: const BorderSide(color: mockBorder),
              ),
            ),
          ],
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
    _contentType = TextEditingController(
      text: r?.contentType ?? 'application/json',
    );
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
    final String contentType =
        _contentType.text.trim().isEmpty
            ? 'application/octet-stream'
            : _contentType.text.trim();
    final String? method = _method == 'ANY' ? null : _method;

    final FMockRule result =
        widget.initial == null
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
      data: mockDarkTheme(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title ?? (widget.initial == null ? 'New Mock' : 'Edit Mock'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: mockBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: mockBorder),
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
                  color: mockRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: mockRed.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: mockRed, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const _Label('METHOD'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  _methodOptions.map((String m) {
                    final bool active = _method == m;
                    final Color c = mockMethodColor(m);
                    return GestureDetector(
                      onTap: () => setState(() => _method = m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              active
                                  ? c.withValues(alpha: 0.15)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: active ? c : mockBorder,
                            width: active ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          m,
                          style: TextStyle(
                            color: active ? c : mockTextMuted,
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
            _field(_path, hint: '/api/v1/users/*  or  /profiles/', mono: true),
            const SizedBox(height: 6),
            const Text(
              'Contains "*" → glob match. Otherwise substring match. Query string is ignored.',
              style: TextStyle(color: mockTextMuted, fontSize: 11, height: 1.4),
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
              children:
                  _contentTypePresets.map((String ct) {
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
                          border: Border.all(color: mockBorder),
                        ),
                        child: Text(
                          ct,
                          style: const TextStyle(
                            color: mockTextMuted,
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
                  style: TextStyle(color: mockTextMuted, fontSize: 11),
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
                color: mockSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: mockBorder),
              ),
              child: TextField(
                controller: _body,
                maxLines: null,
                minLines: 8,
                style: const TextStyle(
                  color: mockTextPrimary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText:
                      _isBase64
                          ? 'Base64-encoded bytes (e.g. an image or PDF)…'
                          : '{ "message": "mocked" }',
                  hintStyle: const TextStyle(
                    color: mockTextMuted,
                    fontSize: 12,
                  ),
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
                color: mockTextMuted,
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
        color: mockTextPrimary,
        fontSize: 13,
        fontFamily: mono ? 'monospace' : null,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: mockTextMuted, fontSize: 13),
        filled: true,
        fillColor: mockSurface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: mockBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: mockBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: mockBlue),
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
        color: mockTextMuted,
        fontSize: 10,
        letterSpacing: 1,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
