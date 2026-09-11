import 'package:fnetwork_inspector/src/core/fmock_store.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_meta.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_store.dart';
import 'package:fnetwork_inspector/src/model/fmock_rule.dart';
import 'package:fnetwork_inspector/src/model/network_log.dart';
import 'package:fnetwork_inspector/src/ui/screen/network_mock_list_screen.dart';
import 'package:fnetwork_inspector/src/ui/widget/fnetwork_credit_footer.dart';
import 'package:fnetwork_inspector/src/ui/widget/json_body_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Appends the credit line to text that is about to leave the app (clipboard or
/// share sheet). The on-screen previews stay clean.
String _curlForShare(String curl) => '$curl\n\n# $kFNetworkInspectorCreditLine';

String _reportForShare(String report) =>
    '$report\n\n---\n$kFNetworkInspectorCreditLine';

class NetworkLogDetailScreen extends StatelessWidget {
  const NetworkLogDetailScreen({super.key, required this.requestId});

  final String requestId;

  static const Color _bg = Color(0xFF0D1117);
  static const Color _surface = Color(0xFF161B22);
  static const Color _border = Color(0xFF30363D);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textMuted = Color(0xFF8B949E);
  static const Color _green = Color(0xFF3FB950);
  static const Color _red = Color(0xFFF85149);
  static const Color _orange = Color(0xFFD29922);
  static const Color _blue = Color(0xFF58A6FF);

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

  String _buildCurl(NetworkLog log) {
    final StringBuffer curl = StringBuffer();
    curl.write("curl -X ${log.method} '${log.baseUrl}${log.path}'");
    if (log.requestHeaders != null) {
      for (final MapEntry<String, dynamic> entry
          in log.requestHeaders!.entries) {
        if (entry.key.toLowerCase() == 'content-length') continue;
        curl.write(" \\\n  -H '${entry.key}: ${entry.value}'");
      }
    }
    if (log.requestBody != null && log.requestBody!.isNotEmpty) {
      final String escaped = log.requestBody!.replaceAll("'", "'\\''");
      curl.write(" \\\n  -d '$escaped'");
    }
    return curl.toString();
  }

  String _buildFullReport(NetworkLog log) {
    final StringBuffer sb = StringBuffer();
    sb.writeln('=== REQUEST ===');
    sb.writeln('${log.method} ${log.baseUrl}${log.path}');
    sb.writeln('Time: ${log.startTime.toLocal().toString().split('.').first}');

    if (log.requestHeaders != null && log.requestHeaders!.isNotEmpty) {
      sb.writeln('\n--- Request Headers ---');
      for (final MapEntry<String, dynamic> e in log.requestHeaders!.entries) {
        sb.writeln('${e.key}: ${e.value}');
      }
    }

    if (log.requestBody != null && log.requestBody!.isNotEmpty) {
      sb.writeln('\n--- Request Body ---');
      sb.writeln(log.requestBody);
    }

    sb.writeln('\n=== RESPONSE ===');
    if (log.statusCode != null) sb.writeln('Status: ${log.statusCode}');
    if (log.durationMs != null) sb.writeln('Duration: ${log.durationMs}ms');
    if (log.errorMessage != null) sb.writeln('Error: ${log.errorMessage}');

    if (log.responseHeaders != null && log.responseHeaders!.isNotEmpty) {
      sb.writeln('\n--- Response Headers ---');
      for (final MapEntry<String, dynamic> e in log.responseHeaders!.entries) {
        sb.writeln('${e.key}: ${e.value}');
      }
    }

    if (log.responseBody != null && log.responseBody!.isNotEmpty) {
      sb.writeln('\n--- Response Body ---');
      sb.writeln(log.responseBody);
    }

    return sb.toString().trim();
  }

  String _contentTypeOf(NetworkLog log) {
    final Map<String, dynamic>? headers = log.responseHeaders;
    if (headers != null) {
      for (final MapEntry<String, dynamic> e in headers.entries) {
        if (e.key.toLowerCase() == 'content-type') {
          return e.value.toString().split(';').first.trim();
        }
      }
    }
    return 'application/json';
  }

  Future<void> _mockFromResponse(BuildContext context, NetworkLog log) async {
    final FMockRule seed = FMockRule.create(
      pathPattern: log.path.split('?').first,
      method: log.method,
      statusCode: log.statusCode ?? 200,
      contentType: _contentTypeOf(log),
      body: log.responseBody ?? '',
    );
    final FMockRule? result = await Navigator.of(context).push(
      MaterialPageRoute<FMockRule>(
        builder: (_) =>
            MockRuleEditScreen(initial: seed, title: 'Mock this response'),
      ),
    );
    if (result == null || !context.mounted) return;
    FMockStore.instance.add(result);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mock rule added'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        FNetworkStore.instance,
        FMockStore.instance,
      ]),
      builder: (BuildContext context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final NetworkLog? log = FNetworkStore.instance.getLog(requestId);

    if (log == null) {
      return Theme(
        data: ThemeData.dark().copyWith(scaffoldBackgroundColor: _bg),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Request Detail'),
            backgroundColor: _surface,
          ),
          body: const Center(
            child: Text(
              'Request not found',
              style: TextStyle(color: _textMuted),
            ),
          ),
        ),
      );
    }

    final Color statusColor = _statusColor(log.status);
    final Color methodColor = _methodColor(log.method);
    final String curlCommand = _buildCurl(log);
    final String fullReport = _buildFullReport(log);
    final FMockRule? mockRule =
        FMockStore.instance.ruleFor(log.method, log.path);

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: _surface,
          foregroundColor: _textPrimary,
          elevation: 0,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: _blue,
          unselectedLabelColor: _textMuted,
          indicatorColor: _blue,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
        ),
        dividerColor: _border,
      ),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Row(
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
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.path,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              if (mockRule == null)
                IconButton(
                  icon: const Icon(Icons.bolt_outlined, size: 20),
                  tooltip: 'Mock this response',
                  onPressed: () => _mockFromResponse(context, log),
                ),
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 20),
                tooltip: 'Share full report',
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: _reportForShare(fullReport),
                    subject: 'API Report: ${log.shortLabel}',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 20),
                tooltip: 'Copy full report',
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: _reportForShare(fullReport)),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Full report copied to clipboard'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(49),
              child: Column(
                children: <Widget>[
                  Container(height: 1, color: _border),
                  const TabBar(
                    tabs: <Tab>[
                      Tab(text: 'Overview'),
                      Tab(text: 'Request'),
                      Tab(text: 'Response'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          body: TabBarView(
            children: <Widget>[
              _OverviewTab(
                log: log,
                statusColor: statusColor,
                curlCommand: curlCommand,
                fullReport: fullReport,
                mockRule: mockRule,
              ),
              _BodyTab(headers: log.requestHeaders, body: log.requestBody),
              _BodyTab(headers: log.responseHeaders, body: log.responseBody),
            ],
          ),
          bottomNavigationBar: const FNetworkCreditFooter(),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.log,
    required this.statusColor,
    required this.curlCommand,
    required this.fullReport,
    this.mockRule,
  });

  final NetworkLog log;
  final Color statusColor;
  final String curlCommand;
  final String fullReport;
  final FMockRule? mockRule;

  static const Color _surface = Color(0xFF161B22);
  static const Color _border = Color(0xFF30363D);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textMuted = Color(0xFF8B949E);
  static const Color _green = Color(0xFF3FB950);
  static const Color _red = Color(0xFFF85149);
  static const Color _orange = Color(0xFFD29922);
  static const Color _blue = Color(0xFF58A6FF);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: _StatusBadge(log: log, statusColor: statusColor)),
            if (log.isMocked) ...<Widget>[
              const SizedBox(width: 8),
              _OriginBadge('MOCK', _orange),
            ],
            if (log.isChaos) ...<Widget>[
              const SizedBox(width: 8),
              _OriginBadge('CHAOS', _red),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'REQUEST',
          children: <Widget>[
            _InfoRow(label: 'Method', value: log.method),
            _InfoRow(label: 'URL', value: '${log.baseUrl}${log.path}'),
            _InfoRow(
              label: 'Time',
              value: log.startTime.toLocal().toString().split('.').first,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'RESPONSE',
          children: <Widget>[
            if (log.statusCode != null)
              _InfoRow(label: 'Status', value: log.statusCode.toString()),
            if (log.durationMs != null)
              _InfoRow(label: 'Duration', value: '${log.durationMs}ms'),
            if (log.errorMessage != null)
              _InfoRow(label: 'Error', value: log.errorMessage!),
            if (log.status == NetworkLogStatus.loading)
              const _InfoRow(label: 'Status', value: 'In progress...'),
          ],
        ),
        if (mockRule != null) ...<Widget>[
          const SizedBox(height: 12),
          _buildMockSection(context, mockRule!),
        ],
        const SizedBox(height: 12),
        _Section(
          title: 'cURL',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: _curlForShare(curlCommand)),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('cURL copied'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Icon(
                  Icons.copy_outlined,
                  size: 16,
                  color: _textMuted,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => SharePlus.instance.share(
                  ShareParams(
                    text: _curlForShare(curlCommand),
                    subject: 'cURL: ${log.shortLabel}',
                  ),
                ),
                child: const Icon(
                  Icons.share_outlined,
                  size: 16,
                  color: _textMuted,
                ),
              ),
            ],
          ),
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _border),
              ),
              child: SelectableText(
                curlCommand,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF79C0FF),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMockSection(BuildContext context, FMockRule rule) {
    final bool masterOff = !FMockStore.instance.enabled;
    return _Section(
      title: 'MOCK',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            rule.enabled ? 'Active' : 'Off',
            style: TextStyle(
              color: rule.enabled ? _green : _textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Switch(
            value: rule.enabled,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (_) => FMockStore.instance.toggle(rule.id),
          ),
        ],
      ),
      children: <Widget>[
        _InfoRow(label: 'Rule', value: rule.label),
        _InfoRow(
          label: 'Body',
          value: rule.contentType + (rule.isBase64 ? ' · base64' : ''),
        ),
        if (rule.delayMs > 0)
          _InfoRow(label: 'Delay', value: '${rule.delayMs}ms'),
        if (masterOff)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Mocking is globally off — turn it on from the Mocks screen.',
              style: TextStyle(color: _orange, fontSize: 11),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _editMock(context, rule),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: const BorderSide(color: _border),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _deleteMock(context, rule),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _red,
                  side: const BorderSide(color: _border),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editMock(BuildContext context, FMockRule rule) async {
    final FMockRule? result = await Navigator.of(context).push(
      MaterialPageRoute<FMockRule>(
        builder: (_) => MockRuleEditScreen(initial: rule),
      ),
    );
    if (result != null) FMockStore.instance.updateRule(result);
  }

  Future<void> _deleteMock(BuildContext context, FMockRule rule) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            backgroundColor: _surface,
            title: const Text(
              'Delete mock rule?',
              style: TextStyle(color: _textPrimary, fontSize: 15),
            ),
            content: Text(
              rule.label,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _textMuted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete', style: TextStyle(color: _red)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    FMockStore.instance.remove(rule.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mock rule deleted'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _OriginBadge extends StatelessWidget {
  const _OriginBadge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.log, required this.statusColor});

  final NetworkLog log;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.statusLabel,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  static const Color _surface = Color(0xFF161B22);
  static const Color _border = Color(0xFF30363D);
  static const Color _textMuted = Color(0xFF8B949E);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                if (trailing != null) ...<Widget>[const Spacer(), trailing!],
              ],
            ),
          ),
          Container(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyTab extends StatelessWidget {
  const _BodyTab({this.headers, this.body});

  final Map<String, dynamic>? headers;
  final String? body;

  static const Color _textMuted = Color(0xFF8B949E);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: <Widget>[
        if (headers != null && headers!.isNotEmpty) ...<Widget>[
          _Section(
            title: 'HEADERS',
            children: headers!.entries
                .map(
                  (MapEntry<String, dynamic> e) =>
                      _InfoRow(label: e.key, value: e.value.toString()),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (body != null && body!.isNotEmpty)
          _Section(
            title: 'BODY',
            trailing: IconButton(
              icon: const Icon(
                Icons.copy_outlined,
                size: 16,
                color: _textMuted,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: body!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            children: <Widget>[
              JsonBodyView(source: body!),
            ],
          )
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No body',
                style: const TextStyle(color: _textMuted, fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  static const Color _textMuted = Color(0xFF8B949E);
  static const Color _textPrimary = Color(0xFFE6EDF3);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}