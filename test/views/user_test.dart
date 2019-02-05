import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/main.dart';
import 'package:cruisemonkey/src/widgets.dart';

import '../mocks.dart';

void main() {
  testWidgets('Accounts page', (WidgetTester tester) async {
    final TestCruiseModel model = TestCruiseModel();
    await tester.pumpWidget(
      Cruise(
        cruiseModel: model,
        child: const CruiseMonkeyHome(),
      ),
    );

    // Check that the app starts on the Accounts page
    expect(find.text('ABOUT CRUISEMONKEY'), findsOneWidget);
    expect(find.text('Welcome to'), findsOneWidget);

    // To go another tab.
    await tester.tap(find.byIcon(Icons.directions_boat));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Check that the Accounts page is gone.
    expect(find.text('ABOUT CRUISEMONKEY'), findsNothing);
    expect(find.text('Welcome to'), findsNothing);
  });
}