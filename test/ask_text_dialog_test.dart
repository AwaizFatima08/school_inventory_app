import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_inventory/features/common/ui_helpers.dart';

/// Regression: confirming the note dialog crashed with
/// "_dependents.isEmpty" because the controller was disposed mid-animation.
void main() {
  Future<String?> open(WidgetTester tester, {bool required = false}) async {
    String? result = 'untouched';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await askText(context, title: 'Note', required: required),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('OK returns the typed note and closes cleanly', (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await askText(context, title: 'Note'),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  short of stock  ');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, 'short of stock');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('required note blocks OK until 3+ letters', (tester) async {
    await open(tester, required: true);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Please write at least 3 letters'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Expired stock');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Cancel returns null', (tester) async {
    String? result = 'x';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await askText(context, title: 'Note'),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
