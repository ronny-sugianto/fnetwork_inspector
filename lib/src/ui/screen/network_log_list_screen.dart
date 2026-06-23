import 'package:fnetwork_inspector/src/core/fnetwork_store.dart';
import 'package:fnetwork_inspector/src/model/network_log.dart';
import 'package:fnetwork_inspector/src/ui/screen/network_log_detail_screen.dart';
import 'package:flutter/material.dart';

class NetworkLogListScreen extends StatefulWidget {
  const NetworkLogListScreen({super.key});

  @override
  State<NetworkLogListScreen> createState() => _NetworkLogListScreenState();
}

class _NetworkLogListScreenState extends State<NetworkLogListScreen> {
  final FNetworkStore _store = FNetworkStore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  NetworkLogStatus? _filterStatus;
  String? _filterMethod;

  static const Color _bg = Color(0xFF0D1117);
  static const Color _surface = Color(0xFF161B22);
  static const Color _border = Color(0xFF30363D);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textMuted = Color(0xFF8B949E);
  static const Color _green = Color(0xFF3FB950);
  static const Color _red = Color(0xFFF85149);
  static const Color _orange = Color(0xFFD29922);
  static const Color _blue = Color(0xFF58A6FF);

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
          _filterMethod == null ||
          log.method.toUpperCase() == _filterMethod;
      return matchesSearch && matchesStatus && matchesMethod;
    }).toList();
  }

  // Returns where the search matched (for badge indicator), null if matched path/method/status
  String? _getMatchSource(NetworkLog log) {
    if (_searchQuery.isEmpty) return null;
    final String q = _searchQuery.toLowerCase();
    if (log.path.toLowerCase().contains(q) ||
        _decodedPath(log.path).toLowerCase().contains(q) ||
        log.method.toLowerCase().contains(q) ||
        (log.statusCode?.toString().contains(q) ?? false)) {
      return null;
    }
    if (log.requestBody?.toLowerCase().contains(q) ?? false) {
      return 'req body';
    }
    if (log.responseBody?.toLowerCase().contains(q) ?? false) {
      return 'res body';
    }
    return null;
  }

  List<String> get _availableMethods {
    final Set<String> methods = <String>{};
    for (final NetworkLog log in _store.logs) {
      methods.add(log.method.toUpperCase());
    }
    return methods.toList()..sort();
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
          title: const Text(
            'Network Inspector',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          actions: <Widget>[
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
            _buildSearchAndFilter(),
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
          _buildChip(
            '${_store.loadingCount}',
            'Loading',
            _orange,
            NetworkLogStatus.loading,
          ),
          const SizedBox(width: 8),
          _buildChip(
            '${_store.successCount}',
            'Success',
            _green,
            NetworkLogStatus.success,
          ),
          const SizedBox(width: 8),
          _buildChip(
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

  Widget _buildChip(
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

  Widget _buildSearchAndFilter() {
    final List<String> methods = _availableMethods;
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
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
          if (methods.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _buildMethodChip(null, 'ALL'),
                  ...methods.map(
                    (String m) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _buildMethodChip(m, m),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMethodChip(String? method, String label) {
    final bool isActive = _filterMethod == method;
    final Color color = method != null ? _methodColor(method) : _textMuted;
    return GestureDetector(
      onTap: () => setState(() => _filterMethod = isActive ? null : method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? color : _border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? color : _textMuted,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            fontFamily: 'monospace',
          ),
        ),
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
                    _filterMethod != null
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