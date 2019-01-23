import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/logic/cruise.dart';

import '../loggers.dart';



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
        'LoggingDataStore.restoreCredentials',
        '--- select new configuration',
        'LoggingTwitarr(1).logout',
        'LoggingTwitarr(2).getCalendar',
        'model changed',
        '--- idling, expect settings restore to change the model',
        'model changed',
        'LoggingTwitarr(1).dispose',
        '--- waiting one hour',
        '--- login',
        'LoggingTwitarr(2).login aaa / bbb',
        'model changed',
        '--- idling',
        'LoggingDataStore.saveCredentials Credentials(aaa)',
        'model changed',
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
}
