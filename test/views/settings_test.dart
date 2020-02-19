import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform/platform.dart';

import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/logic/notifications.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/errors.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/network/rest.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/network/settings.dart';
import 'package:cruisemonkey/src/views/settings.dart';
import 'package:cruisemonkey/src/widgets.dart';

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
      initialTwitarrConfiguration: const RestTwitarrConfiguration(baseUrl: 'https://example.com/'),
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
    expect(model.twitarrConfiguration, const RestTwitarrConfiguration(baseUrl: 'https://example.com/'));
    log.add('--');
    expect(find.text('URL is not valid'), findsNothing);
    expect(find.text('https://example.com/'), findsOneWidget);
    await tester.tap(find.text('Twit-arr server on Nieuw Amsterdam'));
    await tester.pump();
    expect(model.twitarrConfiguration, kShipTwitarr);
    log.add('--');
    await tester.enterText(find.text('https://example.com/'), 'bla');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('https://example.com/'), findsNothing);
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
      'LoggingTwitarr(26).login aaa / aaaaaa', // the 26 comes from the TestCruiseModel.selectTwitarrConfiguration method below
      'LoggingDataStore.saveCredentials Credentials(aaa)',
      'LoggingTwitarr(26).getCalendar(Credentials(aaa))',
      'LoggingTwitarr(26).getAnnouncements()',
      'LoggingTwitarr(26).getSectionStatus()',
      '--',
      'LoggingTwitarr(26).dispose()',
      'LoggingDataStore.saveCredentials null',
      'LoggingDataStore.saveSetting Setting.server rest:Bhttp://10.114.238.135/',
      'LoggingTwitarr(28).getCalendar(null)',
      'LoggingTwitarr(28).getAnnouncements()',
      'LoggingTwitarr(28).getSectionStatus()',
      '--',
      '--',
      'LoggingTwitarr(28).dispose()',
      'LoggingDataStore.saveSetting Setting.server rest:Chttp://invalid',
      'LoggingTwitarr(20).getCalendar(null)',
      'LoggingTwitarr(20).getAnnouncements()',
      'LoggingTwitarr(20).getSectionStatus()',
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
