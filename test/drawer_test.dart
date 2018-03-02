import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/main.dart';
import 'package:cruisemonkey/src/network/network.dart';

import 'mocks.dart';

void main() {
  testWidgets('Drawer', (WidgetTester tester) async {
    final Twitarr twitarr = new TestTwitarr();
    await tester.pumpWidget(new CruiseMonkey(twitarr: twitarr));

    // Check that the drawer starts closed.
    expect(find.text('CruiseMonkey'), findsOneWidget);
    expect(find.text('Not logged in'), findsNothing);

    // Open the drawer.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Check that now we can see the text "not logged in", and can still see the appbar title.
    expect(find.text('CruiseMonkey'), findsOneWidget);
    expect(find.text('Not logged in'), findsOneWidget);

    await tester.pumpWidget(const Placeholder());
    twitarr.dispose();
  });
}