import 'package:fnetwork_inspector/fnetwork_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, String source) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: JsonBodyView(source: source)),
      ),
    ),
  );
}

void main() {
  testWidgets('non-JSON body renders raw, no tree toolbar', (
    WidgetTester tester,
  ) async {
    await _pump(tester, 'plain text, not json');

    expect(find.text('plain text, not json'), findsOneWidget);
    expect(find.text('Tree'), findsNothing);
    expect(find.text('Raw'), findsNothing);
  });

  testWidgets('JSON object shows tree with keys and a Raw toggle', (
    WidgetTester tester,
  ) async {
    await _pump(tester, '{"name":"ada","age":36,"active":true}');

    expect(find.text('Tree'), findsOneWidget);
    expect(find.text('Raw'), findsOneWidget);
    expect(find.textContaining('name'), findsWidgets);

    await tester.tap(find.text('Raw'));
    await tester.pump();
    // Pretty-printed output is indented.
    expect(find.textContaining('  "name": "ada"'), findsOneWidget);
  });

  testWidgets('collapse all hides nested keys, expand all restores them', (
    WidgetTester tester,
  ) async {
    await _pump(tester, '{"outer":{"inner":"v"}}');

    expect(find.textContaining('inner'), findsWidgets);

    await tester.tap(find.byTooltip('Collapse all'));
    await tester.pump();
    expect(find.textContaining('inner'), findsNothing);

    await tester.tap(find.byTooltip('Expand all'));
    await tester.pump();
    expect(find.textContaining('inner'), findsWidgets);
  });

  testWidgets('tree renders inside a bounded internal scroll view', (
    WidgetTester tester,
  ) async {
    final String big =
        '{${List<String>.generate(200, (int i) => '"k$i":$i').join(',')}}';
    await _pump(tester, big);
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('search filters rows to matches and their ancestors', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      '{"alpha":{"keep":"yes"},"beta":{"drop":"no"}}',
    );

    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'keep');
    await tester.pump();

    expect(find.textContaining('keep'), findsWidgets);
    expect(find.textContaining('drop'), findsNothing);
    expect(find.textContaining('beta'), findsNothing);
  });
}
