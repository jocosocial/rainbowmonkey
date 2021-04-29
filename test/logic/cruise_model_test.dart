import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/logic/seamail.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/errors.dart';
import 'package:cruisemonkey/src/models/user.dart';

import 'package:flutter_test/flutter_test.dart';

import '../loggers.dart';
import '../mocks.dart';

void main() {
  final List<String> log = <String>[];
  LoggingTwitarrConfiguration.register(log);

  testWidgets('CruiseModel', (WidgetTester tester) async {
    log.clear();
    const LoggingTwitarrConfiguration config1 = LoggingTwitarrConfiguration(1);
    const LoggingTwitarrConfiguration config2 = LoggingTwitarrConfiguration(2);
    final CruiseModel model = CruiseModel(
      initialTwitarrConfiguration: config1,
      store: TrivialDataStore(log),
      onError: (UserFriendlyError error) { log.add('error: $error'); },
    );
    model.addListener(() { log.add('model changed'); });
    expect(model.twitarrConfiguration, config1);
    log.add('--- select new configuration');
    model.selectTwitarrConfiguration(config2);
    log.add('--- idling, expect settings restore to change the model');
    await tester.idle();
    log.add('--- waiting ten minutes');
    await tester.pump(const Duration(minutes: 10));
    log.add('--- login');
    model.login(username: 'aaa', password: 'bbb');
    log.add('--- idling');
    await tester.idle();
    log.add('--- waiting ten minutes');
    await tester.pump(const Duration(minutes: 10));
    log.add('--- examining user');
    model.user.best.addListener(() { log.add('user updated'); });
    log.add('--- idling');
    await tester.idle();
    log.add('--- waiting 20 minutes');
    await tester.pump(const Duration(minutes: 20));
    log.add('--- end');
    model.dispose();
    expect(
      log,
      <String>[
        'LoggingDataStore.restoreSettings',
        '--- select new configuration',
        'LoggingTwitarr(1).dispose()',
        'model changed',
        '--- idling, expect settings restore to change the model',
        'LoggingDataStore.restoreCredentials',
        'LoggingTwitarr(2).getCalendar(null)',
        'LoggingTwitarr(2).getAnnouncements()',
        'LoggingTwitarr(2).getSectionStatus()',
        'LoggingTwitarr(2).getUpdateIntervals()',
        '--- waiting ten minutes',
        '--- login',
        'LoggingTwitarr(2).login aaa / bbb',
        '--- idling',
        'LoggingDataStore.saveCredentials Credentials(aaa)',
        'model changed',
        'LoggingTwitarr(2).getCalendar(Credentials(aaa))',
        '--- waiting ten minutes',
        '--- examining user',
        '--- idling',
        'LoggingTwitarr(2).getAuthenticatedUser Credentials(aaa)',
        'user updated',
        '--- waiting 20 minutes',
        'LoggingTwitarr(2).getAuthenticatedUser Credentials(aaa)',
        'user updated',
        'LoggingTwitarr(2).getAuthenticatedUser Credentials(aaa)',
        'user updated',
        '--- end',
        'LoggingTwitarr(2).dispose()',
      ],
    );
  });

  testWidgets('CruiseModel autologin', (WidgetTester tester) async {
    log.clear();
    final TrivialDataStore store = TrivialDataStore(log);
    store.storedCredentials = const Credentials(username: 'aaa', password: 'aaaaaa', key: 'blabla');
    final CruiseModel model = CruiseModel(
      initialTwitarrConfiguration: const LoggingTwitarrConfiguration(1),
      store: store,
      onError: (UserFriendlyError error) { log.add('error: $error'); },
    );
    model.addListener(() { log.add('model changed (isLoggedIn = ${model.isLoggedIn})'); });
    log.add('--- idling (isLoggedIn = ${model.isLoggedIn})');
    await tester.idle();
    log.add('--- waiting one hour');
    await tester.pump(const Duration(hours: 1));
    log.add('--- end');
    model.dispose();
    expect(
      log,
      <String>[
        'LoggingDataStore.restoreSettings',
        '--- idling (isLoggedIn = false)',
        'LoggingDataStore.restoreCredentials',
        'LoggingTwitarr(1).login aaa / aaaaaa',
        'LoggingDataStore.saveCredentials Credentials(aaa)',
        'model changed (isLoggedIn = true)',
        'LoggingTwitarr(1).getCalendar(Credentials(aaa))',
        'LoggingTwitarr(1).getAnnouncements()',
        'LoggingTwitarr(1).getSectionStatus()',
        'LoggingTwitarr(1).getUpdateIntervals()',
        '--- waiting one hour',
        '--- end',
        'LoggingTwitarr(1).dispose()'
      ],
    );
  });

  testWidgets('CruiseModel login again', (WidgetTester tester) async {
    log.clear();
    final TrivialDataStore store = TrivialDataStore(log);
    final CruiseModel model = CruiseModel(
      initialTwitarrConfiguration: const LoggingTwitarrConfiguration(0),
      store: store,
      onError: (UserFriendlyError error) { log.add('error: $error'); },
    );
    model.addListener(() { log.add('model changed (isLoggedIn = ${model.isLoggedIn})'); });
    log.add('--- idling');
    await tester.idle();
    final Seamail seamail0 = model.seamail;
    seamail0.addListener(() { log.add('seamail0 changed'); });
    log.add('--- waiting 1 minute');
    await tester.pump(const Duration(seconds: 60));
    log.add('--- logging in 1');
    model.login(username: 'user1', password: 'password1');
    log.add('--- idling');
    await tester.idle();
    final Seamail seamail1 = model.seamail;
    seamail1.addListener(() { log.add('seamail1 changed'); });
    log.add('--- waiting 1 minute');
    await tester.pump(const Duration(seconds: 60));
    log.add('--- logging in 2');
    model.login(username: 'user2', password: 'password2');
    log.add('--- idling');
    await tester.idle();
    final Seamail seamail2 = model.seamail;
    seamail2.addListener(() { log.add('seamail2 changed'); });
    log.add('--- waiting 1 minute');
    await tester.pump(const Duration(seconds: 60));
    log.add('--- ending');
    model.dispose();
    expect(
      log,
      <String>[
        'LoggingDataStore.restoreSettings',
        '--- idling',
        'LoggingDataStore.restoreCredentials',
        'LoggingTwitarr(0).getCalendar(null)',
        'LoggingTwitarr(0).getAnnouncements()',
        'LoggingTwitarr(0).getSectionStatus()',
        'LoggingTwitarr(0).getUpdateIntervals()',
        '--- waiting 1 minute',
        '--- logging in 1',
        'LoggingTwitarr(0).login user1 / password1',
        '--- idling',
        'LoggingDataStore.saveCredentials Credentials(user1)',
        'model changed (isLoggedIn = true)',
        'LoggingTwitarr(0).getCalendar(Credentials(user1))',
        'getSeamailThreads for Credentials(user1) from null',
        '--- waiting 1 minute',
        '--- logging in 2',
        'LoggingDataStore.saveCredentials null',
        'model changed (isLoggedIn = false)',
        'LoggingTwitarr(0).login user2 / password2',
        '--- idling',
        'LoggingTwitarr(0).getCalendar(null)',
        'LoggingDataStore.saveCredentials Credentials(user2)',
        'model changed (isLoggedIn = true)',
        'LoggingTwitarr(0).getCalendar(Credentials(user2))',
        'getSeamailThreads for Credentials(user2) from null',
        '--- waiting 1 minute',
        '--- ending',
        'LoggingTwitarr(0).dispose()'
      ],
    );
    expect(identical(seamail0, seamail1), isFalse);
    expect(identical(seamail1, seamail2), isFalse);
  });

  testWidgets('CruiseModel restore server', (WidgetTester tester) async {
    log.clear();
    final TrivialDataStore store = TrivialDataStore(log);
    store.storedSettings[Setting.server] = 'logger:1';
    store.storedCredentials = const Credentials(username: 'aaa', password: 'aaaaaa', key: 'blabla');
    final CruiseModel model = CruiseModel(
      initialTwitarrConfiguration: const LoggingTwitarrConfiguration(0),
      store: store,
      onError: (UserFriendlyError error) { log.add('error: $error'); },
    );
    model.addListener(() { log.add('model changed (isLoggedIn = ${model.isLoggedIn})'); });
    log.add('--- idling (isLoggedIn = ${model.isLoggedIn})');
    await tester.idle();
    log.add('--- waiting one hour');
    await tester.pump(const Duration(hours: 1));
    log.add('--- end');
    model.dispose();
    expect(
      log,
      <String>[
        'LoggingDataStore.restoreSettings',
        '--- idling (isLoggedIn = false)',
        'LoggingTwitarr(0).dispose()',
        'model changed (isLoggedIn = false)',
        'LoggingDataStore.restoreCredentials',
        'LoggingTwitarr(1).login aaa / aaaaaa',
        'LoggingDataStore.saveCredentials Credentials(aaa)',
        'model changed (isLoggedIn = true)',
        'LoggingTwitarr(1).getCalendar(Credentials(aaa))',
        'LoggingTwitarr(1).getAnnouncements()',
        'LoggingTwitarr(1).getSectionStatus()',
        'LoggingTwitarr(1).getUpdateIntervals()',
        '--- waiting one hour',
        '--- end',
        'LoggingTwitarr(1).dispose()'
      ],
    );
  });
}
