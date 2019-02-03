import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/models/user.dart';

import '../loggers.dart';
import '../mocks.dart';

void main() {
  testWidgets('CruiseModel', (WidgetTester tester) async {
    final List<String> log = <String>[];
    final LoggingTwitarrConfiguration config1 = LoggingTwitarrConfiguration(1, log);
    final LoggingTwitarrConfiguration config2 = LoggingTwitarrConfiguration(2, log);
    final CruiseModel model = CruiseModel(
      initialTwitarrConfiguration: config1,
      store: LoggingDataStore(log),
      onError: (String error) { log.add('error: $error'); },
    );
    model.addListener(() { log.add('model changed'); });
    expect(model.twitarrConfiguration, config1);
    log.add('--- select new configuration');
    model.selectTwitarrConfiguration(config2);
    log.add('--- idling, expect settings restore to change the model');
    await tester.idle();
    log.add('--- waiting one hour');
    await tester.pump(const Duration(hours: 1));
    log.add('--- login');
    model.login(username: 'aaa', password: 'bbb');
    log.add('--- idling');
    await tester.idle();
    log.add('--- waiting one hour');
    await tester.pump(const Duration(hours: 1));
    log.add('--- examining user');
    model.user.best.addListener(() { log.add('user updated'); });
    log.add('--- idling');
    await tester.idle();
    log.add('--- waiting 2 hours');
    await tester.pump(const Duration(hours: 2));
    log.add('--- end');
    model.dispose();
    expect(
      log,
      <String>[
        'LoggingDataStore.restoreSettings',
        '--- select new configuration',
        'LoggingTwitarr(1).dispose',
        'model changed',
        '--- idling, expect settings restore to change the model',
        'LoggingDataStore.restoreCredentials',
        'LoggingTwitarr(2).getCalendar(null)',
        '--- waiting one hour',
        '--- login',
        'LoggingTwitarr(2).login aaa / bbb',
        '--- idling',
        'LoggingDataStore.saveCredentials Credentials(aaa)',
        'model changed',
        'LoggingTwitarr(2).getCalendar(Credentials(aaa))',
        '--- waiting one hour',
        '--- examining user',
        '--- idling',
        'LoggingTwitarr(2).getAuthenticatedUser Credentials(aaa)',
        'user updated',
        '--- waiting 2 hours',
        'LoggingTwitarr(2).getAuthenticatedUser Credentials(aaa)',
        'user updated',
        'LoggingTwitarr(2).getAuthenticatedUser Credentials(aaa)',
        'user updated',
        '--- end',
        'LoggingTwitarr(2).dispose',
      ],
    );
  });

  testWidgets('CruiseModel autologin', (WidgetTester tester) async {
    final List<String> log = <String>[];
    final TrivialDataStore store = TrivialDataStore();
    store.storedCredentials = const Credentials(username: 'aaa', password: 'aaaaaa', key: 'blabla');
    final CruiseModel model = CruiseModel(
      initialTwitarrConfiguration: LoggingTwitarrConfiguration(1, log),
      store: store,
      onError: (String error) { log.add('error: $error'); },
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
        '--- idling (isLoggedIn = false)',
        'LoggingTwitarr(1).login aaa / aaaaaa',
        'model changed (isLoggedIn = true)',
        'LoggingTwitarr(1).getCalendar(Credentials(aaa))',
        '--- waiting one hour',
        '--- end',
        'LoggingTwitarr(1).dispose'
      ],
    );
  });
}
