import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/calendar.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/network/rest.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/progress.dart';
import 'package:cruisemonkey/src/views/settings.dart';
import 'package:cruisemonkey/src/widgets.dart';

Future<void> main() async {
  testWidgets('Settings', (WidgetTester tester) async {
    final TestCruiseModel model = TestCruiseModel();
    await tester.pumpWidget(
      new MaterialApp(
        home: new Cruise(
          cruiseModel: model,
          child: const Settings(),
        ),
      ),
    );
    expect(model.twitarrConfiguration, null);
    await tester.tap(find.text('prosedev.com test server'));
    await tester.pump();
    expect(model.twitarrConfiguration, const RestTwitarrConfiguration(baseUrl: 'http://drang.prosedev.com:3000/'));
    await tester.tap(find.text('example.com'));
    await tester.pump();
    expect(model.twitarrConfiguration, const RestTwitarrConfiguration(baseUrl: 'http://example.com/'));
  });
}

class TestDataStore implements DataStore {
  @override
  Progress<void> saveCredentials(Credentials value) => null;
  @override
  Progress<Credentials> restoreCredentials() => null;
}

class TestCruiseModel extends ChangeNotifier implements CruiseModel {
  @override
  final Duration rarePollInterval = Duration.zero;
  @override
  final Duration frequentPollInterval = Duration.zero;
  @override
  final DataStore store = TestDataStore();

  @override
  TwitarrConfiguration get twitarrConfiguration => _twitarrConfiguration;
  TwitarrConfiguration _twitarrConfiguration;
  @override
  void selectTwitarrConfiguration(TwitarrConfiguration newConfiguration) {
    _twitarrConfiguration = newConfiguration;
    notifyListeners();
  }

  @override
  Progress<Credentials> createAccount({
    @required String username,
    @required String password,
    @required String email,
    @required String securityQuestion,
    @required String securityAnswer,
  }) => null;

  @override
  Progress<Credentials> login({
    @required String username,
    @required String password,
  }) => null;

  @override
  Progress<Credentials> logout() => null;
  @override
  ContinuousProgress<User> get user => null;
  @override
  ContinuousProgress<Calendar> get calendar => null;
}
