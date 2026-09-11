import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _surface = Color(0xFF161B22);
const Color _bgDeep = Color(0xFF0D1117);
const Color _border = Color(0xFF30363D);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textMuted = Color(0xFF8B949E);
const Color _blue = Color(0xFF58A6FF);

const Color _keyColor = Color(0xFF7EE787);
const Color _strColor = Color(0xFFA5D6FF);
const Color _numColor = Color(0xFF79C0FF);
const Color _kwColor = Color(0xFFFF7B72);
const Color _punct = Color(0xFF8B949E);
const Color _matchBg = Color(0x66D29922);

const int _maxRows = 2000;
const int _autoExpandDepth = 3;

/// Renders an HTTP body as a collapsible, syntax-highlighted JSON tree with
/// search and per-node copy. Falls back to plain selectable text when the
/// source is not a JSON object or array.
class JsonBodyView extends StatefulWidget {
  const JsonBodyView({super.key, required this.source});

  final String source;

  @override
  State<JsonBodyView> createState() => _JsonBodyViewState();
}

class _JsonBodyViewState extends State<JsonBodyView> {
  Object? _decoded;
  bool _isJson = false;
  bool _rawMode = false;
  bool _searchOpen = false;
  String _query = '';
  final Set<String> _collapsed = <String>{};
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(covariant JsonBodyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _collapsed.clear();
      _query = '';
      _searchCtrl.clear();
      _parse();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _parse() {
    _decoded = null;
    _isJson = false;
    try {
      final Object? d = jsonDecode(widget.source);
      if (d is Map || d is List) {
        _decoded = d;
        _isJson = true;
        _seedCollapse(d, r'$', 0);
      }
    } catch (_) {
      // not JSON — fall back to raw
    }
  }

  void _seedCollapse(Object? value, String path, int depth) {
    if (value is Map) {
      if (depth >= _autoExpandDepth && value.isNotEmpty) _collapsed.add(path);
      value.forEach(
        (dynamic k, dynamic v) => _seedCollapse(v, '$path.$k', depth + 1),
      );
    } else if (value is List) {
      if (depth >= _autoExpandDepth && value.isNotEmpty) _collapsed.add(path);
      for (int i = 0; i < value.length; i++) {
        _seedCollapse(value[i], '$path[$i]', depth + 1);
      }
    }
  }

  String get _pretty {
    if (!_isJson) return widget.source;
    try {
      return const JsonEncoder.withIndent('  ').convert(_decoded);
    } catch (_) {
      return widget.source;
    }
  }

  // --- search -------------------------------------------------------------

  Set<String> _searchVisible() {
    final String q = _query.toLowerCase();
    final Set<String> keep = <String>{};
    void walk(Object? value, String path, String? key, List<String> ancestors) {
      bool selfMatch = key != null && key.toLowerCase().contains(q);
      if (!selfMatch && value is! Map && value is! List) {
        selfMatch = _literal(value).toLowerCase().contains(q);
      }
      if (selfMatch) {
        keep.add(path);
        keep.addAll(ancestors);
      }
      final List<String> next = <String>[...ancestors, path];
      if (value is Map) {
        value.forEach(
          (dynamic k, dynamic v) => walk(v, '$path.$k', k.toString(), next),
        );
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          walk(value[i], '$path[$i]', '[$i]', next);
        }
      }
    }

    walk(_decoded, r'$', null, const <String>[]);
    return keep;
  }

  // --- flattening -------------------------------------------------------------

  List<_Row> _rows() {
    final Set<String>? keep = _query.isEmpty ? null : _searchVisible();
    final List<_Row> out = <_Row>[];

    void add(Object? value, String path, String? key, int depth) {
      if (out.length >= _maxRows) return;
      if (keep != null && !keep.contains(path)) return;
      final bool container = value is Map || value is List;
      final bool expanded =
          container && (keep != null || !_collapsed.contains(path));
      out.add(_Row(path, key, value, depth, container, expanded));
      if (!container || !expanded) return;
      if (value is Map) {
        value.forEach(
          (dynamic k, dynamic v) => add(v, '$path.$k', k.toString(), depth + 1),
        );
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          add(value[i], '$path[$i]', '[$i]', depth + 1);
        }
      }
    }

    add(_decoded, r'$', null, 0);
    return out;
  }

  // --- actions -------------------------------------------------------------

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _toast('$label copied');
  }

  void _rowMenu(_Row row) {
    final String subtree = () {
      if (!row.isContainer) return _literal(row.value);
      try {
        return const JsonEncoder.withIndent('  ').convert(row.value);
      } catch (_) {
        return row.value.toString();
      }
    }();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.data_object, color: _textMuted),
              title: Text(
                row.isContainer ? 'Copy subtree (JSON)' : 'Copy value',
                style: const TextStyle(color: _textPrimary, fontSize: 14),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _copy(subtree, row.isContainer ? 'Subtree' : 'Value');
              },
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email, color: _textMuted),
              title: const Text(
                'Copy path',
                style: TextStyle(color: _textPrimary, fontSize: 14),
              ),
              subtitle: Text(
                row.path,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _copy(row.path, 'Path');
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_isJson) {
      return _rawContainer(SelectableText(
        widget.source,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: _textPrimary,
          height: 1.6,
        ),
      ));
    }

    final List<_Row> rows = _rawMode ? const <_Row>[] : _rows();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _toolbar(),
        if (_searchOpen && !_rawMode) ...<Widget>[
          const SizedBox(height: 8),
          _searchField(),
        ],
        const SizedBox(height: 8),
        if (_rawMode)
          _rawContainer(SelectableText(
            _pretty,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: _textPrimary,
              height: 1.6,
            ),
          ))
        else
          _rawContainer(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final _Row r in rows) _buildRow(r),
                if (rows.length >= _maxRows)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Output truncated — switch to Raw to see everything.',
                      style: TextStyle(color: _textMuted, fontSize: 11),
                    ),
                  ),
                if (rows.isEmpty && _query.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No matches',
                      style: TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _rawContainer(Widget child) {
    // Cap the height and scroll internally so the tree is always fully
    // reachable regardless of how the widget is nested.
    final double maxHeight =
        (MediaQuery.sizeOf(context).height * 0.55).clamp(240.0, 600.0);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _bgDeep,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Scrollbar(
          controller: _scrollCtrl,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    return Row(
      children: <Widget>[
        _segmented(),
        const Spacer(),
        if (!_rawMode) ...<Widget>[
          _iconBtn(
            _searchOpen ? Icons.search_off : Icons.search,
            'Search',
            () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) {
                _query = '';
                _searchCtrl.clear();
              }
            }),
          ),
          _iconBtn(
            Icons.unfold_more,
            'Expand all',
            () => setState(_collapsed.clear),
          ),
          _iconBtn(
            Icons.unfold_less,
            'Collapse all',
            () => setState(() {
              _collapsed.clear();
              _collapseAll(_decoded, r'$', 0);
            }),
          ),
        ],
        _iconBtn(
          Icons.copy_all,
          'Copy JSON',
          () => _copy(_pretty, 'JSON'),
        ),
      ],
    );
  }

  void _collapseAll(Object? value, String path, int depth) {
    if (value is Map) {
      if (depth >= 1 && value.isNotEmpty) _collapsed.add(path);
      value.forEach(
        (dynamic k, dynamic v) => _collapseAll(v, '$path.$k', depth + 1),
      );
    } else if (value is List) {
      if (depth >= 1 && value.isNotEmpty) _collapsed.add(path);
      for (int i = 0; i < value.length; i++) {
        _collapseAll(value[i], '$path[$i]', depth + 1);
      }
    }
  }

  Widget _segmented() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _segBtn('Tree', !_rawMode, () => setState(() => _rawMode = false)),
          _segBtn('Raw', _rawMode, () => setState(() => _rawMode = true)),
        ],
      ),
    );
  }

  Widget _segBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _blue.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? _blue : _textMuted,
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tip,
      color: _textMuted,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchCtrl,
      autofocus: true,
      style: const TextStyle(color: _textPrimary, fontSize: 12),
      decoration: InputDecoration(
        hintText: 'Filter keys and values…',
        hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
        prefixIcon: const Icon(Icons.search, color: _textMuted, size: 16),
        isDense: true,
        filled: true,
        fillColor: _surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _blue),
        ),
      ),
      onChanged: (String v) => setState(() => _query = v),
    );
  }

  Widget _buildRow(_Row row) {
    final double indent = row.depth * 14 + (row.isContainer ? 0 : 16);
    final List<InlineSpan> spans = <InlineSpan>[];

    if (row.key != null) {
      spans.addAll(_highlight(row.key!, _keyColor));
      spans.add(const TextSpan(text: ': ', style: TextStyle(color: _punct)));
    }
    if (row.isContainer) {
      final bool isMap = row.value is Map;
      final int n = isMap
          ? (row.value as Map<dynamic, dynamic>).length
          : (row.value as List<dynamic>).length;
      if (row.expanded) {
        spans.add(TextSpan(
          text: isMap ? '{' : '[',
          style: const TextStyle(color: _punct),
        ));
      } else {
        spans.add(TextSpan(
          text: isMap ? '{ … }' : '[ … ]',
          style: const TextStyle(color: _punct),
        ));
        spans.add(TextSpan(
          text: '  $n',
          style: const TextStyle(color: _textMuted, fontSize: 10),
        ));
      }
    } else {
      spans.addAll(_valueSpans(row.value));
    }

    final Widget text = Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        height: 1.7,
      ),
    );

    return InkWell(
      onTap: row.isContainer
          ? () => setState(() {
                if (!_collapsed.remove(row.path)) _collapsed.add(row.path);
              })
          : () => _copy(_literal(row.value), 'Value'),
      onLongPress: () => _rowMenu(row),
      child: Padding(
        padding: EdgeInsets.only(left: indent, top: 1, bottom: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (row.isContainer)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 2),
                child: Icon(
                  row.expanded
                      ? Icons.arrow_drop_down
                      : Icons.arrow_right,
                  size: 14,
                  color: _textMuted,
                ),
              ),
            Expanded(child: text),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _valueSpans(Object? value) {
    if (value == null) {
      return const <InlineSpan>[
        TextSpan(text: 'null', style: TextStyle(color: _kwColor)),
      ];
    }
    if (value is String) {
      return _highlight('"$value"', _strColor);
    }
    if (value is num) {
      return _highlight('$value', _numColor);
    }
    if (value is bool) {
      return _highlight('$value', _kwColor);
    }
    return _highlight('$value', _textPrimary);
  }

  List<InlineSpan> _highlight(String text, Color base) {
    final TextStyle style = TextStyle(color: base);
    if (_query.isEmpty) {
      return <InlineSpan>[TextSpan(text: text, style: style)];
    }
    final String lower = text.toLowerCase();
    final String q = _query.toLowerCase();
    final List<InlineSpan> out = <InlineSpan>[];
    int start = 0;
    int idx = lower.indexOf(q);
    while (idx >= 0) {
      if (idx > start) {
        out.add(TextSpan(text: text.substring(start, idx), style: style));
      }
      out.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: style.copyWith(backgroundColor: _matchBg, color: _textPrimary),
      ));
      start = idx + q.length;
      idx = lower.indexOf(q, start);
    }
    if (start < text.length) {
      out.add(TextSpan(text: text.substring(start), style: style));
    }
    return out;
  }
}

String _literal(Object? value) {
  if (value == null) return 'null';
  if (value is String) return value;
  return '$value';
}

class _Row {
  const _Row(
    this.path,
    this.key,
    this.value,
    this.depth,
    this.isContainer,
    this.expanded,
  );

  final String path;
  final String? key;
  final Object? value;
  final int depth;
  final bool isContainer;
  final bool expanded;
}
