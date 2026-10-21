import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:fnetwork_inspector/src/core/fmock_store.dart';
import 'package:fnetwork_inspector/src/model/fmock_bundle.dart';
import 'package:fnetwork_inspector/src/model/fmock_scenario.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

const Color _surface = Color(0xFF161B22);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textMuted = Color(0xFF8B949E);
const Color _red = Color(0xFFF85149);
const Color _blue = Color(0xFF58A6FF);

/// Opens the system file picker for a mock file. A variable so tests can swap
/// in a fake.
@visibleForTesting
Future<XFile?> Function() mockFilePicker = _pickMockFile;

Future<XFile?> _pickMockFile() => openFile(
  acceptedTypeGroups: const <XTypeGroup>[
    XTypeGroup(
      label: 'fnetwork mocks ($kFMockFileExtension)',
      // `.fnmock.json` ends in `.json`, which is what pickers can filter on.
      extensions: <String>['json'],
      mimeTypes: <String>['application/json'],
      uniformTypeIdentifiers: <String>['public.json'],
    ),
  ],
);

/// File name for [base]: `Order Summary` → `order-summary.fnmock.json`.
String mockFileName(String base) {
  final String slug = base
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${slug.isEmpty ? 'mocks' : slug}$kFMockFileExtension';
}

void _snack(ScaffoldMessengerState messenger, String message) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Shares [json] as a `.fnmock.json` file; falls back to the clipboard where
/// sharing isn't available.
Future<void> shareMockFile(
  BuildContext context, {
  required String json,
  required String fileName,
  required String subject,
}) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
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
        subject: subject,
      ),
    );
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: json));
    _snack(
      messenger,
      "Sharing isn't available — copied the JSON to the clipboard",
    );
  }
}

/// Shares [scenarios] as one `.fnmock.json` file named after [baseName].
Future<void> exportScenarioFile(
  BuildContext context,
  List<FMockScenario> scenarios,
  String baseName,
) => shareMockFile(
  context,
  json: FMockStore.instance.exportScenariosJson(scenarios),
  fileName: mockFileName(baseName),
  subject: 'fnetwork mocks: $baseName',
);

/// Picks a mock file and imports it (after asking merge vs replace).
Future<void> importMocksFromFile(BuildContext context) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final XFile? file;
  try {
    file = await mockFilePicker();
  } catch (e) {
    _snack(messenger, 'Could not open the file picker: $e');
    return;
  }
  if (file == null) return;
  final String text;
  try {
    text = await file.readAsString();
  } catch (e) {
    _snack(messenger, 'Could not read ${file.name}');
    return;
  }
  if (!context.mounted) return;
  await importMocksFromSource(context, text, sourceName: file.name);
}

/// Parses [source], shows what it contains, and — after the tester picks
/// **Merge** or **Replace** — imports it.
Future<void> importMocksFromSource(
  BuildContext context,
  String source, {
  String? sourceName,
}) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final FMockBundle bundle;
  try {
    bundle = FMockBundle.parse(source);
  } on FormatException catch (e) {
    _snack(messenger, 'Invalid mocks file: ${e.message}');
    return;
  }
  if (bundle.isEmpty) {
    _snack(messenger, 'The file has no rules or scenarios');
    return;
  }
  final bool? merge = await _confirmImport(context, bundle, sourceName);
  if (merge == null || !context.mounted) return;
  final FMockImportSummary summary = FMockStore.instance.importBundle(
    bundle,
    merge: merge,
  );
  _snack(messenger, 'Imported: ${summary.describe()}');
}

/// Returns true for Merge, false for Replace, null for Cancel.
Future<bool?> _confirmImport(
  BuildContext context,
  FMockBundle bundle,
  String? sourceName,
) {
  final FMockStore store = FMockStore.instance;
  final List<FMockScenario> scenarios = bundle.scenarios ?? <FMockScenario>[];
  final List<String> contents = <String>[
    if (scenarios.isNotEmpty)
      '${scenarios.length} scenario${scenarios.length == 1 ? '' : 's'}',
    if (bundle.ruleCount > 0)
      '${bundle.ruleCount} rule${bundle.ruleCount == 1 ? '' : 's'}',
  ];
  final List<String> replaced = <String>[
    if (bundle.scenarios != null)
      'all ${store.scenarios.length} current scenarios',
    if (bundle.rules != null) 'all ${store.rules.length} current rules',
  ];

  Widget bullet(String t) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Text(
      '•  $t',
      style: const TextStyle(color: _textMuted, fontSize: 12, height: 1.35),
    ),
  );

  return showDialog<bool>(
    context: context,
    builder:
        (BuildContext ctx) => AlertDialog(
          backgroundColor: _surface,
          title: const Text(
            'Import mocks',
            style: TextStyle(color: _textPrimary, fontSize: 15),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (sourceName != null)
                  Text(
                    sourceName,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Contains ${contents.join(' and ')}.',
                  style: const TextStyle(color: _textPrimary, fontSize: 13),
                ),
                for (final FMockScenario s in scenarios.take(6))
                  bullet(s.group == null ? s.name : '${s.group} › ${s.name}'),
                if (scenarios.length > 6)
                  bullet('… and ${scenarios.length - 6} more'),
                const SizedBox(height: 14),
                const Text(
                  'Merge adds what is new and updates items that already exist '
                  '(same id, or same name in the same group). Nothing else changes.',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Replace removes ${replaced.join(' and ')} and uses the file\'s '
                  'instead.',
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: _textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Replace', style: TextStyle(color: _red)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: _blue),
              child: const Text(
                'Merge',
                style: TextStyle(color: Color(0xFF0D1117)),
              ),
            ),
          ],
        ),
  );
}
