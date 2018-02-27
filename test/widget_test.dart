// This is a basic Flutter widget test.
// To perform an interaction with a widget in your test, use the WidgetTester utility that Flutter
// provides. For example, you can send tap and scroll gestures. You can also use WidgetTester to
// find child widgets in the widget tree, read text, and verify that the values of widget properties
// are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/main.dart';

void main() {
  testWidgets('Drawer', (WidgetTester tester) async {
    await tester.pumpWidget(const CruiseMonkey());

    // Check that the drawer starts closed.
    expect(find.text('CruiseMonkey'), findsOneWidget);
    expect(find.text('Not logged in'), findsNothing);

    // Open the drawer.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Check that now we can see the text "not logged in", and can still see the appbar title.
    expect(find.text('CruiseMonkey'), findsOneWidget);
    expect(find.text('Not logged in'), findsOneWidget);
  });
}
