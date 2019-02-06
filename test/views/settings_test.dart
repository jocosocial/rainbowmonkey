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
    final TrivialDataStore store = TrivialDataStore();
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
          child: const Settings(),
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
      'LoggingTwitarr(497174609).login aaa / aaaaaa',
      'LoggingTwitarr(497174609).getCalendar(Credentials(aaa))',
      'LoggingTwitarr(497174609).getAnnouncements()',
      '--',
      'LoggingTwitarr(497174609).dispose',
      'LoggingTwitarr(1064653154).getCalendar(null)',
      'LoggingTwitarr(1064653154).getAnnouncements()',
      '--',
      '--',
      'LoggingTwitarr(1064653154).dispose',
      'LoggingTwitarr(274681805).getCalendar(null)',
      'LoggingTwitarr(274681805).getAnnouncements()',
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
    super.selectTwitarrConfiguration(LoggingTwitarrConfiguration(newConfiguration.hashCode));
  }
}
