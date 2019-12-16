import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/models/errors.dart';
import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/views/stream.dart';
import 'package:cruisemonkey/src/views/attach_image.dart';
import 'package:cruisemonkey/src/widgets.dart';

import '../loggers.dart';
import '../mocks.dart';

void main() {
  final List<String> log = <String>[];
  LoggingTwitarrConfiguration.register(log);

  testWidgets('Twitarr page', (WidgetTester tester) async {
    log.clear();
    final CruiseModel model = CruiseModel(
      initialTwitarrConfiguration: const LoggingTwitarrConfiguration(0),
      store: TrivialDataStore(log),
      onError: (UserFriendlyError error) { log.add('error: $error'); },
    );
    await model.login(username: 'username', password: 'password').asFuture();

    await tester.pumpWidget(
      MaterialApp(
        home: Now.fixed(
          dateTime: DateTime(2019),
          child: Cruise(
            cruiseModel: model,
            child: const TweetStreamView(),
          ),
        ),
      ),
    );

    expect(find.text('Twitarr'), findsOneWidget);
    expect(find.text('Image attachments'), findsNothing);

    await tester.tap(find.byType(AttachImageButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Image attachments'), findsOneWidget);

    await tester.pumpWidget(Container());
    model.dispose();
    await tester.idle(); // give timers time to be canceled
  });
}