
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/views/profile.dart';
import 'package:cruisemonkey/src/widgets.dart';

import '../loggers.dart';
import '../mocks.dart';

Future<void> main() async {
  testWidgets('Profile Editor', (WidgetTester tester) async {
    final List<String> log = <String>[];
    ProfileTestTwitarr twitarr;
    final CruiseModel model = new CruiseModel(
      twitarrConfiguration: ProfileTestTwitarrConfiguration(
        log,
        onTwitarr: (ProfileTestTwitarr value) {
          twitarr = value;
        },
      ),
      store: const TestDataStore(),
    );
    await model.login(username: 'username', password: 'password').asFuture();
    await tester.pumpWidget(
      new MaterialApp(
        home: new Cruise(
          cruiseModel: model,
          child: const Profile(),
        ),
      ),
    );
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Current location'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0.0, -200.0));
    await tester.pump();
    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);
    expect(find.text('override location set'), findsNothing);
    await tester.enterText(find.byType(TextField).at(3), 'Hello');
    twitarr.overrideCurrentLocation = 'override location set';
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(log, <String>[
      'LoggingTwitarr(0).login username / password',
      'fetchProfilePicture',
      'updateProfile Hello/null/null/null/null/null/null/null',
      'LoggingTwitarr(0).getAuthenticatedUser Credentials(username)'
    ]);
    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);
    expect(find.text('override location set'), findsOneWidget);
  });
}

class ProfileTestTwitarrConfiguration extends LoggingTwitarrConfiguration {
  const ProfileTestTwitarrConfiguration(List<String> log, { this.onTwitarr }) : super(0, log);

  final ValueSetter<ProfileTestTwitarr> onTwitarr;

  @override
  Twitarr createTwitarr() {
    final ProfileTestTwitarr result = ProfileTestTwitarr(this, log);
    if (onTwitarr != null)
      onTwitarr(result);
    return result;
  }
}

class ProfileTestTwitarr extends LoggingTwitarr {
  ProfileTestTwitarr(ProfileTestTwitarrConfiguration configuration, List<String> log) : super(configuration, log);
}
