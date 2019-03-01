import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/basic_types.dart';
import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/network/rest.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/views/settings.dart';
import 'package:cruisemonkey/src/widgets.dart';

import '../loggers.dart';
import '../mocks.dart';

Future<void> main() async {
  final List<String> log = <String>[];
  RestTwitarrConfiguration.register();
  LoggingTwitarrConfiguration.register(log);

  testWidgets('Settings', (WidgetTester tester) async {
    log.clear();
    final TrivialDataStore store = TrivialDataStore(log);
    store.storedCredentials = const Credentials(username: 'aaa', password: 'aaaaaa', key: 'blabla');
    final CruiseModel model = _TestCruiseModel(
      initialTwitarrConfiguration: const RestTwitarrConfiguration(baseUrl: 'https://example.com/'),
      store: store,
      onError: (String error) { throw Exception(error); },
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
    await tester.tap(find.text('Automatically pick server'));
    await tester.pump();
    expect(model.twitarrConfiguration, const AutoTwitarrConfiguration());
    log.add('--');
    await tester.enterText(find.text('https://example.com/'), 'bla');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('https://example.com/'), findsNothing);
    expect(find.text('bla'), findsOneWidget);
    log.add('--');
    await tester.idle();
    expect(model.twitarrConfiguration, const AutoTwitarrConfiguration());
    await tester.enterText(find.text('bla'), 'http://invalid');
    await tester.pump();
    expect(find.text('bla'), findsNothing);
    expect(model.twitarrConfiguration, const RestTwitarrConfiguration(baseUrl: 'http://invalid'));
    log.add('--');
    await tester.idle();
    expect(log, <String>[
      'LoggingDataStore.restoreSettings',
      'LoggingDataStore.restoreCredentials',
      'LoggingTwitarr(25).login aaa / aaaaaa',
      'LoggingDataStore.saveCredentials Credentials(aaa)',
      'LoggingTwitarr(25).getCalendar(Credentials(aaa))',
      'LoggingTwitarr(25).getAnnouncements()',
      '--',
      'LoggingTwitarr(25).dispose',
      'LoggingDataStore.saveCredentials null',
      'LoggingDataStore.saveSetting Setting.server auto:',
      'LoggingTwitarr(5).getCalendar(null)',
      'LoggingTwitarr(5).getAnnouncements()',
      '--',
      '--',
      'LoggingTwitarr(5).dispose',
      'LoggingDataStore.saveSetting Setting.server rest:http://invalid',
      'LoggingTwitarr(19).getCalendar(null)',
      'LoggingTwitarr(19).getAnnouncements()',
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
