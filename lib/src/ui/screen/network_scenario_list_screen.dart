import 'package:fnetwork_inspector/src/core/fmock_store.dart';
import 'package:fnetwork_inspector/src/model/fmock_rule.dart';
import 'package:fnetwork_inspector/src/model/fmock_scenario.dart';
import 'package:fnetwork_inspector/src/ui/mock_file_actions.dart';
import 'package:fnetwork_inspector/src/ui/screen/mock_common.dart';
import 'package:fnetwork_inspector/src/ui/screen/network_scenario_detail_screen.dart';
import 'package:fnetwork_inspector/src/ui/widget/fnetwork_credit_footer.dart';
import 'package:flutter/material.dart';

/// Manages named [FMockScenario]s: create, open to edit their rules, apply,
/// duplicate, delete, and import / export them as `.fnmock.json` files.
/// Scenarios are listed under one collapsible header per [FMockScenario.group].
///
/// Applying a scenario copies its rules into the live set shown on
/// [NetworkMockListScreen].
class MockScenarioListScreen extends StatefulWidget {
  const MockScenarioListScreen({super.key});

  @override
  State<MockScenarioListScreen> createState() => _MockScenarioListScreenState();
}

class _MockScenarioListScreenState extends State<MockScenarioListScreen> {
  final FMockStore _store = FMockStore.instance;

  // Groups the user collapsed (in memory only).
  final Set<String> _collapsed = <String>{};

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _open(FMockScenario s) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NetworkScenarioDetailScreen(scenarioId: s.id),
    ),
  );

  void _apply(FMockScenario s) {
    _store.applyScenario(s.id);
    _snack('Applied "${s.name}"');
  }

  /// Creates an empty scenario, then opens it so rules can be added.
  Future<void> _create({String? group}) async {
    final ScenarioDetails? details = await promptScenarioDetails(
      context,
      title: 'New scenario',
      nameHint: 'e.g. Empty list',
      initialGroup: group,
      groups: _store.scenarioGroups,
    );
    if (details == null || !mounted) return;
    final FMockScenario created = _store.createScenario(
      details.name,
      group: details.group,
    );
    await _open(created);
  }

  /// Snapshots the live rules as a scenario.
  Future<void> _saveCurrent() async {
    if (_store.rules.isEmpty) {
      _snack('There are no live rules to save');
      return;
    }
    final ScenarioDetails? details = await promptScenarioDetails(
      context,
      title: 'Save live rules as scenario',
      nameHint: 'e.g. Empty list',
      initialName: _store.activeScenario?.name ?? '',
      initialGroup: _store.activeScenario?.group,
      groups: _store.scenarioGroups,
    );
    if (details == null) return;
    _store.saveAsScenario(details.name, group: details.group);
    _snack('Scenario "${details.name}" saved');
  }

  Future<void> _exportEverything() => shareMockFile(
    context,
    json: _store.exportJson(),
    fileName: mockFileName('fnetwork-mocks'),
    subject: 'fnetwork mocks',
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: mockDarkTheme(),
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
                  icon: const Icon(Icons.add, size: 22),
                  tooltip: 'New scenario',
                  onPressed: _create,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: 'More',
                  color: mockSurface,
                  onSelected: (String v) {
                    switch (v) {
                      case 'save_current':
                        _saveCurrent();
                      case 'import_file':
                        importMocksFromFile(context);
                      case 'import_text':
                        promptAndImportMocksText(context);
                      case 'export_all':
                        exportScenarioFile(context, list, 'scenarios');
                      case 'export_everything':
                        _exportEverything();
                    }
                  },
                  itemBuilder:
                      (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'save_current',
                          child: MockMenuRow(
                            Icons.bookmark_add_outlined,
                            'Save live rules as scenario…',
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<String>(
                          value: 'import_file',
                          child: MockMenuRow(
                            Icons.file_open_outlined,
                            'Import from file…',
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'import_text',
                          child: MockMenuRow(
                            Icons.content_paste,
                            'Import from text…',
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem<String>(
                          value: 'export_all',
                          enabled: list.isNotEmpty,
                          child: const MockMenuRow(
                            Icons.ios_share,
                            'Export all scenarios',
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'export_everything',
                          child: MockMenuRow(
                            Icons.ios_share,
                            'Export everything (+ live rules)',
                          ),
                        ),
                      ],
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: mockBorder),
              ),
            ),
            body: Column(
              children: <Widget>[
                if (_store.activeScenario != null) _buildActiveBanner(),
                Expanded(
                  child: list.isEmpty ? _buildEmpty() : _buildList(list),
                ),
              ],
            ),
            bottomNavigationBar: const FNetworkCreditFooter(),
          );
        },
      ),
    );
  }

  Widget _buildActiveBanner() {
    return Container(
      width: double.infinity,
      color: mockBlue.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: <Widget>[
          const Icon(Icons.layers, size: 14, color: mockBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  const TextSpan(
                    text: 'Active: ',
                    style: TextStyle(color: mockTextMuted, fontSize: 12),
                  ),
                  TextSpan(
                    text: _store.activeScenario!.name,
                    style: const TextStyle(
                      color: mockTextPrimary,
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
              foregroundColor: mockTextMuted,
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
            const Icon(Icons.layers_outlined, color: mockTextMuted, size: 40),
            const SizedBox(height: 12),
            const Text(
              'No scenarios yet',
              style: TextStyle(color: mockTextMuted, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'A scenario is a named set of mock rules\n— switch the whole setup in one tap.',
              textAlign: TextAlign.center,
              style: TextStyle(color: mockTextMuted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New scenario'),
              style: OutlinedButton.styleFrom(
                foregroundColor: mockBlue,
                side: const BorderSide(color: mockBorder),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => importMocksFromFile(context),
              child: const Text(
                'Import from file…',
                style: TextStyle(color: mockTextMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<FMockScenario> list) {
    final List<String> groups = _store.scenarioGroups;
    // No groups at all: the plain list.
    if (groups.isEmpty) {
      return ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, _) => Container(height: 1, color: mockBorder),
        itemBuilder: (BuildContext context, int i) => _buildTile(list[i]),
      );
    }

    final List<Widget> children = <Widget>[];
    void section(
      String key,
      String title,
      List<FMockScenario> items, {
      required String fileBase,
      String? group,
    }) {
      if (items.isEmpty) return;
      final bool collapsed = _collapsed.contains(key);
      children.add(
        _groupHeader(
          title: title,
          count: items.length,
          collapsed: collapsed,
          onTap:
              () => setState(() {
                if (!_collapsed.remove(key)) _collapsed.add(key);
              }),
          onExport: () => exportScenarioFile(context, items, fileBase),
          onNew: () => _create(group: group),
        ),
      );
      if (collapsed) return;
      for (final FMockScenario s in items) {
        children.add(_buildTile(s));
        children.add(Container(height: 1, color: mockBorder));
      }
    }

    for (final String g in groups) {
      section(
        'group:$g',
        g,
        list.where((FMockScenario s) => s.group == g).toList(),
        fileBase: g,
        group: g,
      );
    }
    section(
      'other',
      'Other scenarios',
      list.where((FMockScenario s) => s.group == null).toList(),
      fileBase: 'other-scenarios',
    );
    return ListView(children: children);
  }

  Widget _groupHeader({
    required String title,
    required int count,
    required bool collapsed,
    required VoidCallback onTap,
    required VoidCallback onExport,
    required VoidCallback onNew,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: mockSurface,
        padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
        child: Row(
          children: <Widget>[
            Icon(
              collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 18,
              color: mockTextMuted,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: mockTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(color: mockTextMuted, fontSize: 11),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_horiz,
                size: 18,
                color: mockTextMuted,
              ),
              tooltip: 'Group actions',
              padding: EdgeInsets.zero,
              color: mockSurface,
              onSelected: (String v) => v == 'new' ? onNew() : onExport(),
              itemBuilder:
                  (BuildContext context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'new',
                      child: MockMenuRow(Icons.add, 'New scenario in group'),
                    ),
                    PopupMenuItem<String>(
                      value: 'export',
                      child: MockMenuRow(
                        Icons.ios_share,
                        'Export group (.fnmock.json)',
                      ),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(FMockScenario s) {
    final bool active = _store.activeScenarioId == s.id;
    final int on = s.rules.where((FMockRule r) => r.enabled).length;
    return InkWell(
      onTap: () => _open(s),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
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
                            color: mockTextPrimary,
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
                            color: mockGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: mockGreen.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: mockGreen,
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
                    s.rules.isEmpty
                        ? 'No rules yet'
                        : '${s.rules.length} rule${s.rules.length == 1 ? '' : 's'}'
                            '${on == s.rules.length ? '' : ' · $on on'}',
                    style: const TextStyle(color: mockTextMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              color: mockBlue,
              tooltip: 'Apply',
              onPressed: () => _apply(s),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: mockTextMuted),
              color: mockSurface,
              onSelected: (String v) {
                switch (v) {
                  case 'edit':
                    editScenarioDetails(context, s);
                  case 'duplicate':
                    _store.duplicateScenario(s.id);
                  case 'share':
                    exportScenarioFile(context, <FMockScenario>[s], s.name);
                  case 'delete':
                    _store.deleteScenario(s.id);
                }
              },
              itemBuilder:
                  (BuildContext context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: MockMenuRow(
                        Icons.edit_outlined,
                        'Rename / group…',
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'duplicate',
                      child: MockMenuRow(Icons.copy_outlined, 'Duplicate'),
                    ),
                    PopupMenuItem<String>(
                      value: 'share',
                      child: MockMenuRow(
                        Icons.ios_share,
                        'Export (.fnmock.json)',
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: MockMenuRow(Icons.delete_outline, 'Delete'),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }
}
