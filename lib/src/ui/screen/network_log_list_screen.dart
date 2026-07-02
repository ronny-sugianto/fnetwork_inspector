import 'package:fnetwork_inspector/src/core/fnetwork_store.dart';
import 'package:fnetwork_inspector/src/model/network_log.dart';
import 'package:fnetwork_inspector/src/ui/screen/network_log_detail_screen.dart';
import 'package:flutter/material.dart';

class NetworkLogListScreen extends StatefulWidget {
  const NetworkLogListScreen({super.key, this.onOverlayClose});

  /// When non-null a close (×) button is shown as the AppBar leading widget
  /// and tapping it calls this callback. Used by [FNetworkInspectorOverlay].
  final VoidCallback? onOverlayClose;

  @override
  State<NetworkLogListScreen> createState() => _NetworkLogListScreenState();
}

class _NetworkLogListScreenState extends State<NetworkLogListScreen> {
  final FNetworkStore _store = FNetworkStore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  NetworkLogStatus? _filterStatus;
  final Set<String> _filterMethods = <String>{};
  final Set<String> _filterPathSections = <String>{};

  static const Color _bg = Color(0xFF0D1117);
  static const Color _surface = Color(0xFF161B22);
  static const Color _border = Color(0xFF30363D);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textMuted = Color(0xFF8B949E);
  static const Color _green = Color(0xFF3FB950);
  static const Color _red = Color(0xFFF85149);
  static const Color _orange = Color(0xFFD29922);
  static const Color _blue = Color(0xFF58A6FF);

  int get _activeFilterCount =>
      (_filterMethods.isNotEmpty ? 1 : 0) +
      (_filterPathSections.isNotEmpty ? 1 : 0);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _decodedPath(String path) {
    try {
      return Uri.decodeComponent(path);
    } catch (_) {
      return path;
    }
  }

  List<NetworkLog> get _filteredLogs {
    final String q = _searchQuery.toLowerCase();
    return _store.logs.where((NetworkLog log) {
      final bool matchesSearch =
          q.isEmpty ||
          log.path.toLowerCase().contains(q) ||
          _decodedPath(log.path).toLowerCase().contains(q) ||
          log.method.toLowerCase().contains(q) ||
          (log.statusCode?.toString().contains(q) ?? false) ||
          (log.requestBody?.toLowerCase().contains(q) ?? false) ||
          (log.responseBody?.toLowerCase().contains(q) ?? false);
      final bool matchesStatus =
          _filterStatus == null || log.status == _filterStatus;
      final bool matchesMethod =
          _filterMethods.isEmpty ||
          _filterMethods.contains(log.method.toUpperCase());
      final bool matchesPathSection =
          _filterPathSections.isEmpty ||
          _filterPathSections.contains(_pathSection(log.path));
      return matchesSearch && matchesStatus && matchesMethod && matchesPathSection;
    }).toList();
  }

  String? _getMatchSource(NetworkLog log) {
    if (_searchQuery.isEmpty) return null;
    final String q = _searchQuery.toLowerCase();
    if (log.path.toLowerCase().contains(q) ||
        _decodedPath(log.path).toLowerCase().contains(q) ||
        log.method.toLowerCase().contains(q) ||
        (log.statusCode?.toString().contains(q) ?? false)) {
      return null;
    }
    if (log.requestBody?.toLowerCase().contains(q) ?? false) return 'req body';
    if (log.responseBody?.toLowerCase().contains(q) ?? false) return 'res body';
    return null;
  }

  List<String> get _availableMethods {
    final Set<String> methods = <String>{};
    for (final NetworkLog log in _store.logs) {
      methods.add(log.method.toUpperCase());
    }
    return methods.toList()..sort();
  }

  String _stripQuery(String path) {
    final int q = path.indexOf('?');
    return q == -1 ? path : path.substring(0, q);
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final RegExp _hexPattern = RegExp(r'^[0-9a-f]+$', caseSensitive: false);
  static final RegExp _digitsPattern = RegExp(r'^\d+$');
  static final RegExp _longDigitRunPattern = RegExp(r'\d{4,}');
  static final RegExp _alphanumericPattern = RegExp(r'^[A-Za-z0-9]+$');

  /// True for segments that look like dynamic ids (numbers, uuids, hashes, codes like "Y002129").
  bool _looksLikeDynamicId(String segment) {
    if (_digitsPattern.hasMatch(segment)) return true;
    if (_uuidPattern.hasMatch(segment)) return true;
    if (segment.length >= 16 && _hexPattern.hasMatch(segment)) return true;
    if (_alphanumericPattern.hasMatch(segment) &&
        _longDigitRunPattern.hasMatch(segment)) {
      return true;
    }
    return false;
  }

  /// Last segment that isn't a dynamic id, walking backwards; falls back to the true last segment.
  String? _pathSection(String path) {
    final List<String> segs = _stripQuery(path)
        .split('/')
        .where((String s) => s.isNotEmpty)
        .toList();
    if (segs.isEmpty) return null;
    for (int i = segs.length - 1; i >= 0; i--) {
      if (!_looksLikeDynamicId(segs[i])) return segs[i];
    }
    return segs.last;
  }

  List<String> get _availablePathSections {
    final Set<String> sections = <String>{};
    for (final NetworkLog log in _store.logs) {
      final String? seg = _pathSection(log.path);
      if (seg != null) sections.add(seg);
    }
    if (sections.length <= 1) return <String>[];
    return sections.toList()..sort();
  }

  Color _statusColor(NetworkLogStatus status) {
    switch (status) {
      case NetworkLogStatus.loading:
        return _orange;
      case NetworkLogStatus.success:
        return _green;
      case NetworkLogStatus.error:
        return _red;
    }
  }

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

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheet) {
            final List<String> methods = _availableMethods;
            final List<String> sections = _availablePathSections;

            void toggleMethod(String m) {
              setState(() {
                if (_filterMethods.contains(m)) {
                  _filterMethods.remove(m);
                } else {
                  _filterMethods.add(m);
                }
              });
              setSheet(() {});
            }

            void toggleSection(String s) {
              setState(() {
                if (_filterPathSections.contains(s)) {
                  _filterPathSections.remove(s);
                } else {
                  _filterPathSections.add(s);
                }
              });
              setSheet(() {});
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        const Text(
                          'Filter',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (_filterMethods.isNotEmpty || _filterPathSections.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _filterMethods.clear();
                                _filterPathSections.clear();
                              });
                              setSheet(() {});
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (methods.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 20),
                      const Text(
                        'METHOD',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: methods.map((String m) {
                          final bool active = _filterMethods.contains(m);
                          final Color c = _methodColor(m);
                          return GestureDetector(
                            onTap: () => toggleMethod(m),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
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
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (sections.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 20),
                      const Text(
                        'PATH',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: sections.map((String s) {
                          final bool active = _filterPathSections.contains(s);
                          return GestureDetector(
                            onTap: () => toggleSection(s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? _blue.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: active ? _blue : _border,
                                  width: active ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  color: active ? _blue : _textMuted,
                                  fontSize: 12,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<NetworkLog> logs = _filteredLogs;

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
      child: Scaffold(
        appBar: AppBar(
          leading: widget.onOverlayClose != null
              ? IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Close inspector',
                  onPressed: widget.onOverlayClose,
                )
              : null,
          title: const Text(
            'Network Inspector',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          actions: <Widget>[
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.tune, size: 20),
                  tooltip: 'Filter',
                  onPressed: _showFilterSheet,
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh',
              onPressed: () => setState(() {}),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Clear all',
              onPressed: () {
                _store.clear();
                setState(() {});
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _border),
          ),
        ),
        body: Column(
          children: <Widget>[
            _buildSummaryBar(),
            _buildSearchBar(),
            Expanded(
              child: logs.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          Container(height: 1, color: _border),
                      itemBuilder: (BuildContext context, int index) {
                        return _buildLogTile(context, logs[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          _buildStatusChip(
            '${_store.loadingCount}',
            'Loading',
            _orange,
            NetworkLogStatus.loading,
          ),
          const SizedBox(width: 8),
          _buildStatusChip(
            '${_store.successCount}',
            'Success',
            _green,
            NetworkLogStatus.success,
          ),
          const SizedBox(width: 8),
          _buildStatusChip(
            '${_store.errorCount}',
            'Error',
            _red,
            NetworkLogStatus.error,
          ),
          const Spacer(),
          Text(
            '${_store.logs.length} requests',
            style: const TextStyle(color: _textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    String count,
    String label,
    Color color,
    NetworkLogStatus status,
  ) {
    final bool isActive = _filterStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = isActive ? null : status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : _border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              '$count $label',
              style: TextStyle(
                color: isActive ? color : _textMuted,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: _textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search path, body, status code...',
          hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: _textMuted, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: _textMuted, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: _surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
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
        onChanged: (String v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildLogTile(BuildContext context, NetworkLog log) {
    final Color statusColor = _statusColor(log.status);
    final Color methodColor = _methodColor(log.method);
    final String? matchSource = _getMatchSource(log);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NetworkLogDetailScreen(requestId: log.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 3,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
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
                          color: methodColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.method,
                          style: TextStyle(
                            color: methodColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.path,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
                        log.statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 11),
                      ),
                      if (matchSource != null) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _blue.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '~ $matchSource',
                            style: const TextStyle(
                              color: _blue,
                              fontSize: 9,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        _formatTime(log.startTime),
                        style: const TextStyle(color: _textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: _textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.wifi_off, color: _textMuted, size: 40),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty ||
                    _filterStatus != null ||
                    _filterMethods.isNotEmpty ||
                    _filterPathSections.isNotEmpty
                ? 'No matching requests'
                : 'No requests yet',
            style: const TextStyle(color: _textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final DateTime local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }
}
