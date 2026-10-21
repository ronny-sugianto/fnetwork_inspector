import 'package:fnetwork_inspector/src/core/fmock_store.dart';
import 'package:fnetwork_inspector/src/model/fmock_rule.dart';
import 'package:fnetwork_inspector/src/model/fmock_scenario.dart';
import 'package:fnetwork_inspector/src/ui/mock_file_actions.dart';
import 'package:fnetwork_inspector/src/ui/screen/mock_common.dart';
import 'package:fnetwork_inspector/src/ui/screen/network_mock_list_screen.dart';
import 'package:fnetwork_inspector/src/ui/widget/fnetwork_credit_footer.dart';
import 'package:flutter/material.dart';

/// The rules inside one [FMockScenario]: add, edit, enable / disable and delete
/// them without touching the live rule set. Apply the scenario to put them
/// live; while it is applied, edits here update the live rules too.
class NetworkScenarioDetailScreen extends StatefulWidget {
  const NetworkScenarioDetailScreen({super.key, required this.scenarioId});

  final String scenarioId;

  @override
  State<NetworkScenarioDetailScreen> createState() =>
      _NetworkScenarioDetailScreenState();
}

class _NetworkScenarioDetailScreenState
    extends State<NetworkScenarioDetailScreen> {
  final FMockStore _store = FMockStore.instance;

  FMockScenario? get _scenario {
    for (final FMockScenario s in _store.scenarios) {
      if (s.id == widget.scenarioId) return s;
    }
    return null;
  }

  Future<void> _openEditor({FMockRule? rule}) async {
    final FMockRule? result = await Navigator.of(context).push(
      MaterialPageRoute<FMockRule>(
        builder: (_) => MockRuleEditScreen(initial: rule),
      ),
    );
    if (result == null) return;
    if (rule == null) {
      _store.addScenarioRule(widget.scenarioId, result);
    } else {
      _store.updateScenarioRule(widget.scenarioId, result);
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: mockDarkTheme(),
      child: AnimatedBuilder(
        animation: _store,
        builder: (BuildContext context, _) {
          final FMockScenario? s = _scenario;
          if (s == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Scenario')),
              body: const Center(
                child: Text(
                  'This scenario no longer exists',
                  style: TextStyle(color: mockTextMuted, fontSize: 13),
                ),
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(
                s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.add, size: 22),
                  tooltip: 'New rule',
                  onPressed: () => _openEditor(),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: 'More',
                  color: mockSurface,
                  onSelected: (String v) {
                    switch (v) {
                      case 'edit':
                        editScenarioDetails(context, s);
                      case 'duplicate':
                        _store.duplicateScenario(s.id);
                        _snack('Duplicated "${s.name}"');
                      case 'share':
                        exportScenarioFile(context, <FMockScenario>[s], s.name);
                      case 'delete':
                        _store.deleteScenario(s.id);
                        Navigator.of(context).pop();
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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: mockBorder),
              ),
            ),
            body: Column(
              children: <Widget>[
                _buildHeader(s),
                Expanded(
                  child:
                      s.rules.isEmpty
                          ? _buildEmpty()
                          : ListView.separated(
                            itemCount: s.rules.length,
                            separatorBuilder:
                                (_, _) =>
                                    Container(height: 1, color: mockBorder),
                            itemBuilder:
                                (BuildContext context, int i) => MockRuleTile(
                                  rule: s.rules[i],
                                  dim: !s.rules[i].enabled,
                                  onTap: () => _openEditor(rule: s.rules[i]),
                                  onToggle:
                                      () => _store.toggleScenarioRule(
                                        s.id,
                                        s.rules[i].id,
                                      ),
                                  onDelete:
                                      () => _store.removeScenarioRule(
                                        s.id,
                                        s.rules[i].id,
                                      ),
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

  Widget _buildHeader(FMockScenario s) {
    final bool active = _store.activeScenarioId == s.id;
    return Container(
      width: double.infinity,
      color: mockSurface,
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  s.group ?? 'No group',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: mockTextMuted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  active
                      ? 'Active — edits here update the live rules'
                      : 'Not applied — edits here do not affect live rules',
                  style: TextStyle(
                    color: active ? mockGreen : mockTextMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (active)
            TextButton(
              onPressed: _store.detachScenario,
              child: const Text('Detach', style: TextStyle(fontSize: 12)),
            )
          else
            FilledButton(
              onPressed: () {
                _store.applyScenario(s.id);
                _snack('Applied "${s.name}"');
              },
              style: FilledButton.styleFrom(
                backgroundColor: mockBlue,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'Apply',
                style: TextStyle(color: Color(0xFF0D1117)),
              ),
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
            const Icon(Icons.bolt_outlined, color: mockTextMuted, size: 40),
            const SizedBox(height: 12),
            const Text(
              'No rules in this scenario',
              style: TextStyle(color: mockTextMuted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New rule'),
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
