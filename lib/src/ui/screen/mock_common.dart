import 'package:fnetwork_inspector/src/core/fmock_store.dart';
import 'package:fnetwork_inspector/src/model/fmock_rule.dart';
import 'package:fnetwork_inspector/src/model/fmock_scenario.dart';
import 'package:fnetwork_inspector/src/ui/mock_file_actions.dart';
import 'package:flutter/material.dart';

const Color mockBg = Color(0xFF0D1117);
const Color mockSurface = Color(0xFF161B22);
const Color mockBorder = Color(0xFF30363D);
const Color mockTextPrimary = Color(0xFFE6EDF3);
const Color mockTextMuted = Color(0xFF8B949E);
const Color mockGreen = Color(0xFF3FB950);
const Color mockRed = Color(0xFFF85149);
const Color mockOrange = Color(0xFFD29922);
const Color mockBlue = Color(0xFF58A6FF);

Color mockMethodColor(String method) {
  switch (method.toUpperCase()) {
    case 'GET':
      return mockBlue;
    case 'POST':
      return mockGreen;
    case 'PUT':
    case 'PATCH':
      return mockOrange;
    case 'DELETE':
      return mockRed;
    default:
      return mockTextMuted;
  }
}

ThemeData mockDarkTheme() => ThemeData.dark().copyWith(
  scaffoldBackgroundColor: mockBg,
  appBarTheme: const AppBarTheme(
    backgroundColor: mockSurface,
    foregroundColor: mockTextPrimary,
    elevation: 0,
  ),
  dividerColor: mockBorder,
);

/// One rule in a list: method / path / status summary, an enable switch and a
/// delete button. Used by both the live rules and a scenario's rules.
class MockRuleTile extends StatelessWidget {
  const MockRuleTile({
    super.key,
    required this.rule,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    this.dim = false,
  });

  final FMockRule rule;

  /// Greys the row out, e.g. while mocking is switched off globally.
  final bool dim;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color mColor = mockMethodColor(rule.method ?? 'ANY');
    final Color statusColor =
        rule.statusCode >= 200 && rule.statusCode < 300
            ? mockGreen
            : (rule.statusCode >= 400 ? mockRed : mockOrange);

    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Switch(
                value: rule.enabled,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (_) => onToggle(),
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
                              color: mockTextPrimary,
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
                                (rule.delayMs > 0
                                    ? ' · ${rule.delayMs}ms'
                                    : ''),
                            style: const TextStyle(
                              color: mockTextMuted,
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
                color: mockTextMuted,
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MockMenuRow extends StatelessWidget {
  const MockMenuRow(this.icon, this.label, {super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: mockTextMuted),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: mockTextPrimary, fontSize: 13),
          ),
        ),
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
    builder:
        (BuildContext ctx) => AlertDialog(
          backgroundColor: mockSurface,
          title: Text(
            title,
            style: const TextStyle(color: mockTextPrimary, fontSize: 15),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: multiline ? 8 : 1,
            minLines: multiline ? 4 : 1,
            style: TextStyle(
              color: mockTextPrimary,
              fontSize: 13,
              fontFamily: multiline ? 'monospace' : null,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: mockTextMuted, fontSize: 13),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: mockBorder),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: mockBlue),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: mockTextMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(
                confirmLabel,
                style: const TextStyle(color: mockBlue),
              ),
            ),
          ],
        ),
  );
}

/// Asks the tester to paste the contents of a mock file, then imports it.
Future<void> promptAndImportMocksText(BuildContext context) async {
  final String? text = await promptText(
    context,
    title: 'Import mocks from text',
    hint: 'Paste the contents of a .fnmock.json file…',
    multiline: true,
    confirmLabel: 'Next',
  );
  if (text == null || text.trim().isEmpty || !context.mounted) return;
  await importMocksFromSource(context, text);
}

/// Result of [promptScenarioDetails].
typedef ScenarioDetails = ({String name, String? group});

/// Asks for a scenario's name and (optional) group. Existing [groups] are
/// offered as quick picks. Returns null on cancel.
Future<ScenarioDetails?> promptScenarioDetails(
  BuildContext context, {
  required String title,
  String initialName = '',
  String? initialGroup,
  List<String> groups = const <String>[],
  String? nameHint,
}) {
  final TextEditingController name = TextEditingController(text: initialName);
  final TextEditingController group = TextEditingController(
    text: initialGroup ?? '',
  );

  InputDecoration deco(String label, String? hint) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: mockTextMuted, fontSize: 12),
    hintText: hint,
    hintStyle: const TextStyle(color: mockTextMuted, fontSize: 13),
    isDense: true,
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: mockBorder),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: mockBlue),
    ),
  );
  const TextStyle fieldStyle = TextStyle(color: mockTextPrimary, fontSize: 13);

  return showDialog<ScenarioDetails>(
    context: context,
    builder:
        (BuildContext ctx) => AlertDialog(
          backgroundColor: mockSurface,
          title: Text(
            title,
            style: const TextStyle(color: mockTextPrimary, fontSize: 15),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: name,
                  autofocus: true,
                  style: fieldStyle,
                  decoration: deco('Name', nameHint),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: group,
                  style: fieldStyle,
                  decoration: deco(
                    'Group (optional)',
                    'e.g. Checkout Revamp v2.0',
                  ),
                ),
                if (groups.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final String g in groups)
                        GestureDetector(
                          onTap: () => group.text = g,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: mockBorder),
                            ),
                            child: Text(
                              g,
                              style: const TextStyle(
                                color: mockTextMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: mockTextMuted),
              ),
            ),
            TextButton(
              onPressed: () {
                final String n = name.text.trim();
                if (n.isEmpty) return;
                Navigator.of(
                  ctx,
                ).pop((name: n, group: FMockScenario.cleanGroup(group.text)));
              },
              child: const Text('Save', style: TextStyle(color: mockBlue)),
            ),
          ],
        ),
  );
}

/// Prompts for a new name / group for [s] and applies the change.
Future<void> editScenarioDetails(BuildContext context, FMockScenario s) async {
  final FMockStore store = FMockStore.instance;
  final ScenarioDetails? details = await promptScenarioDetails(
    context,
    title: 'Rename / group',
    initialName: s.name,
    initialGroup: s.group,
    groups: store.scenarioGroups,
  );
  if (details == null) return;
  if (details.name != s.name) store.renameScenario(s.id, details.name);
  store.setScenarioGroup(s.id, details.group);
}
