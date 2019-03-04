import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/main.dart';
import 'package:cruisemonkey/src/models/errors.dart';
import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/widgets.dart';

import '../loggers.dart';
import '../mocks.dart';

void main() {
  final List<String> log = <String>[];
  LoggingTwitarrConfiguration.register(log);

  testWidgets('Accounts page', (WidgetTester tester) async {
    log.clear();
    final CruiseModel model = CruiseModel(
      initialTwitarrConfiguration: const LoggingTwitarrConfiguration(0),
      store: TrivialDataStore(log),
      onError: (UserFriendlyError error) { log.add('error: $error'); },
    );

    await tester.pumpWidget(
      Now.fixed(
        dateTime: DateTime(2019),
        child: Cruise(
          cruiseModel: model,
          child: const CruiseMonkeyHome(),
        ),
      ),
    );

    // Check that the app starts on the Accounts page
    expect(find.text('ABOUT RAINBOW MONKEY'), findsOneWidget);
    expect(find.text('Welcome to'), findsOneWidget);

    expect(
      tester.getRect(find.text('Enjoy the cruise!')),
      Rect.fromLTRB(281.0, 276.8, 519.0, 290.8),
    );

    // To go another tab.
    await tester.tap(find.byIcon(Icons.directions_boat));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Check that the Accounts page is gone.
    expect(find.text('ABOUT RAINBOW MONKEY'), findsNothing);
    expect(find.text('Welcome to'), findsNothing);

    await tester.pumpWidget(Container());
    model.dispose();
    await tester.idle(); // give timers time to be canceled
  });
}