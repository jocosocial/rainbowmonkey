import 'dart:async';

import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/logic/notifications.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/errors.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/network/rest.dart';
import 'package:cruisemonkey/src/network/settings.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/views/settings.dart';
import 'package:cruisemonkey/src/widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform/platform.dart';

import '../loggers.dart';
import '../mocks.dart';

Future<void> main() async {
  final List<String> log = <String>[];
  Notifications.overridePlugin = FlutterLocalNotificationsPlugin.private(FakePlatform(operatingSystem: 'android'));
  RestTwitarrConfiguration.register();
  LoggingTwitarrConfiguration.register(log);

  testWidgets('Settings', (WidgetTester tester) async {
    log.clear();
    final TrivialDataStore store = TrivialDataStore(log);
    store.storedCredentials = const Credentials(username: 'aaa', password: 'aaaaaa', key: 'blabla');
    final CruiseModel model = _TestCruiseModel(
      initialTwitarrConfiguration: const RestTwitarrConfiguration(baseUrl: 'https://www.example.com/'),
      store: store,
      onError: (UserFriendlyError error) { throw Exception(error); },
      log: log,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Cruise(
          cruiseModel: model,
          child: Settings(store: store),
        ),
      ),
    );
    expect(model.twitarrConfiguration, const RestTwitarrConfiguration(baseUrl: 'https://www.example.com/'));
    log.add('--');
    expect(find.text('URL is not valid'), findsNothing);
    expect(find.text('https://www.example.com/'), findsOneWidget);
    await tester.tap(find.text('Twit-arr server on Nieuw Amsterdam'));
    await tester.pump();
    expect(model.twitarrConfiguration, kShipTwitarr);
    log.add('--');
    // try to enter an invalid url (bla), it should have no impact
    await tester.enterText(find.text('https://www.example.com/'), 'bla');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('https://www.example.com/'), findsNothing);
    expect(find.text('bla'), findsOneWidget);
    log.add('--');
    await tester.idle();
    expect(model.twitarrConfiguration, kShipTwitarr);
    await tester.enterText(find.text('bla'), 'http://invalid');
    await tester.pump();
    expect(find.text('bla'), findsNothing);
    expect(model.twitarrConfiguration, const RestTwitarrConfiguration(baseUrl: 'http://invalid'));
    log.add('--');
    await tester.idle();
    expect(log, <String>[
      'LoggingDataStore.restoreSettings',
      'LoggingDataStore.restoreCredentials',
      'LoggingTwitarr(30).login aaa / aaaaaa', // the 30 comes from the TestCruiseModel.selectTwitarrConfiguration method below ("rest:Chttps://www.example.com/".length)
      'LoggingDataStore.saveCredentials Credentials(aaa)',
      'LoggingTwitarr(30).getCalendar(Credentials(aaa))',
      'LoggingTwitarr(30).getAnnouncements()',
      'LoggingTwitarr(30).getSectionStatus()',
      'LoggingTwitarr(30).getUpdateIntervals()',
      '--',
      'LoggingTwitarr(30).dispose()',
      'LoggingDataStore.saveCredentials null',
      'LoggingDataStore.saveSetting Setting.server rest:Bhttps://twitarr.com/',
      'LoggingTwitarr(26).getCalendar(null)',
      'LoggingTwitarr(26).getAnnouncements()',
      'LoggingTwitarr(26).getSectionStatus()',
      'LoggingTwitarr(26).getUpdateIntervals()',
      '--',
      '--',
      'LoggingTwitarr(26).dispose()',
      'LoggingDataStore.saveSetting Setting.server rest:Chttp://invalid',
      'LoggingTwitarr(20).getCalendar(null)',
      'LoggingTwitarr(20).getAnnouncements()',
      'LoggingTwitarr(20).getSectionStatus()',
      'LoggingTwitarr(20).getUpdateIntervals()',
      '--'
    ]);
  });
}

class _TestCruiseModel extends CruiseModel {
  _TestCruiseModel({
    @required TwitarrConfiguration initialTwitarrConfiguration,
    @required DataStore store,
    @required ErrorCallback onError,
    @required this.log,
  }) : assert(log != null),
       super(
    initialTwitarrConfiguration: initialTwitarrConfiguration,
    store: store,
    onError: onError,
  );

  final List<String> log;

  @override
  TwitarrConfiguration get twitarrConfiguration => _twitarrConfiguration;
  TwitarrConfiguration _twitarrConfiguration;
  @override
  void selectTwitarrConfiguration(TwitarrConfiguration newConfiguration) {
    _twitarrConfiguration = newConfiguration;
    super.selectTwitarrConfiguration(LoggingTwitarrConfiguration(newConfiguration.toString().length));
  }
}
