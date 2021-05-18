import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/logic/photo_manager.dart';
import 'package:cruisemonkey/src/models/errors.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/progress.dart';
import 'package:cruisemonkey/src/views/profile_editor.dart';
import 'package:cruisemonkey/src/widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../loggers.dart';
import '../mocks.dart';

Future<void> main() async {
  final List<String> log = <String>[];
  LoggingTwitarrConfiguration.register(log);

  testWidgets('Profile Editor', (WidgetTester tester) async {
    log.clear();
    ProfileTestTwitarr twitarr;
    final CruiseModel model = CruiseModel(
      initialTwitarrConfiguration: ProfileTestTwitarrConfiguration(
        onTwitarr: (ProfileTestTwitarr value) {
          twitarr = value;
        },
      ),
      store: TrivialDataStore(log),
      onError: (UserFriendlyError error) { log.add('error: $error'); },
    );
    await model.login(username: 'username', password: 'password').asFuture();
    await tester.pumpWidget(
      MaterialApp(
        home: Cruise(
          cruiseModel: model,
          child: const ProfileEditor(),
        ),
      ),
    );
    log.add('--');
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Home location'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0.0, -1000.0));
    await tester.pumpAndSettle();
    log.add('--');
    expect(find.text('Home location'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);
    expect(find.text('override location set'), findsNothing);
    await tester.enterText(find.byType(TextField).at(3), 'Hello');
    twitarr.overrideHomeLocation = 'override location set';
    log.add('overridden');
    expect(find.text('Home location'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('override location set'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(log, <String>[
      'LoggingDataStore.restoreSettings',
      'LoggingTwitarr(0).login username / password',
      'LoggingDataStore.restoreCredentials',
      'LoggingDataStore.saveCredentials Credentials(username)',
      'LoggingTwitarr(0).getCalendar(Credentials(username))',
      'LoggingTwitarr(0).getAnnouncements()',
      'LoggingTwitarr(0).getSectionStatus()',
      'ProfileTestTwitarr(0).getUpdateIntervals()',
      'fetchProfilePicture',
      '--',
      'LoggingTwitarr(0).getAuthenticatedUser Credentials(username)',
      // this is where the ui subscribes to everything:
      'LoggingTwitarr(0).getAnnouncements()',
      'LoggingTwitarr(0).getSectionStatus()',
      'ProfileTestTwitarr(0).getUpdateIntervals()',
      '--',
      'overridden',
      'updateProfile null/null/null/null/Hello/null',
      'LoggingTwitarr(0).getAuthenticatedUser Credentials(username)'
    ]);
    expect(find.text('Home location'), findsOneWidget);
    expect(find.text('override location set'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);
  });
}

class ProfileTestTwitarrConfiguration extends LoggingTwitarrConfiguration {
  const ProfileTestTwitarrConfiguration({ this.onTwitarr }) : super(0);

  final ValueSetter<ProfileTestTwitarr> onTwitarr;

  @override
  Twitarr createTwitarr() {
    final ProfileTestTwitarr result = ProfileTestTwitarr(this, LoggingTwitarrConfiguration.log);
    if (onTwitarr != null)
      onTwitarr(result);
    return result;
  }
}

class ProfileTestTwitarr extends LoggingTwitarr {
  ProfileTestTwitarr(ProfileTestTwitarrConfiguration configuration, List<String> log) : super(configuration, log);

  @override
  Progress<AuthenticatedUser> login({
    @required String username,
    @required String password,
    @required PhotoManager photoManager,
  }) {
    super.login(username: username, password: password, photoManager: photoManager);
    return Progress<AuthenticatedUser>.completed(AuthenticatedUser(
      username: username,
      role: Role.user,
      credentials: Credentials(
        username: username,
        password: password,
        key: 'blablabla',
      ),
    ));
  }
}
