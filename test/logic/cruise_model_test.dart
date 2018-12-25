import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/logic/photo_manager.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/calendar.dart';
import 'package:cruisemonkey/src/models/seamail.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/progress.dart';

final List<String> log = <String>[];

void main() {
  testWidgets('CruiseModel', (WidgetTester tester) async {
    log.clear();
    final CruiseModel model = CruiseModel(
      twitarrConfiguration: const TestTwitarrConfiguration(1),
      store: const TestDataStore(),
    );
    model.addListener(() { log.add('notification'); });
    expect(model.twitarrConfiguration, const TestTwitarrConfiguration(1));
    log.add('--- select new configuration');
    model.selectTwitarrConfiguration(const TestTwitarrConfiguration(2));
    log.add('--- idling');
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
    log.add('--- waiting 20 minutes');
    await tester.pump(const Duration(minutes: 20));
    log.add('--- end');
    model.dispose();
    expect(
      log,
      <String>[
        'TestDataStore.restoreCredentials',
        '--- select new configuration',
        'TestTwitarr(1).logout',
        'notification',
        '--- idling',
        'TestTwitarr(1).dispose',
        '--- waiting one hour',
        '--- login',
        'TestTwitarr(2).login aaa / bbb',
        'notification',
        '--- idling',
        'TestDataStore.saveCredentials Credentials(aaa)',
        '--- waiting one hour',
        '--- examining user',
        '--- idling',
        'TestTwitarr(2).getAuthenticatedUser Credentials(aaa)',
        'user updated',
        '--- waiting 20 minutes',
        'TestTwitarr(2).getAuthenticatedUser Credentials(aaa)',
        'user updated',
        'TestTwitarr(2).getAuthenticatedUser Credentials(aaa)',
        'user updated',
        '--- end',
        'TestTwitarr(2).dispose',
      ],
    );
  });
}

class TestDataStore implements DataStore {
  const TestDataStore();
  @override
  Progress<void> saveCredentials(Credentials value) {
    log.add('TestDataStore.saveCredentials $value');
    return Progress<void>.completed(null);
  }
  @override
  Progress<Credentials> restoreCredentials() {
    log.add('TestDataStore.restoreCredentials');
    return Progress<Credentials>.completed(null);
  }
}

@immutable
class TestTwitarrConfiguration extends TwitarrConfiguration {
  const TestTwitarrConfiguration(this.id);
  final int id;
  @override
  Twitarr createTwitarr() => TestTwitarr(this);
  @override
  String toString() => 'TestTwitarrConfiguration($id)';
}

class TestTwitarr extends Twitarr {
  TestTwitarr(this._configuration);

  final TestTwitarrConfiguration _configuration;

  @override
  double debugLatency = 0.0;

  @override
  double debugReliability = 1.0;

  @override
  TwitarrConfiguration get configuration => _configuration;

  int _stamp = 0;

  @override
  Progress<AuthenticatedUser> createAccount({
    @required String username,
    @required String password,
    @required String email,
    @required String securityQuestion,
    @required String securityAnswer,
  }) {
    log.add('TestTwitarr(${_configuration.id}).createAccount $username / $password / $email / $securityQuestion / $securityAnswer');
    return Progress<AuthenticatedUser>.completed(AuthenticatedUser(
      username: username,
      email: email,
      credentials: Credentials(
        username: username,
        password: password,
        key: '<key for $username>',
        loginTimestamp: DateTime.fromMillisecondsSinceEpoch(_stamp += 1),
      ),
    ));
  }

  @override
  Progress<AuthenticatedUser> login({
    @required String username,
    @required String password,
    @required PhotoManager photoManager,
  }) {
    log.add('TestTwitarr(${_configuration.id}).login $username / $password');
    return Progress<AuthenticatedUser>.completed(AuthenticatedUser(
      username: username,
      email: '<email for $username>',
      credentials: Credentials(
        username: username,
        password: password,
        key: '<key for $username>',
        loginTimestamp: DateTime.fromMillisecondsSinceEpoch(_stamp += 1),
      ),
    ));
  }

  @override
  Progress<AuthenticatedUser> logout() {
    log.add('TestTwitarr(${_configuration.id}).logout');
    return Progress<AuthenticatedUser>.completed(null);
  }

  @override
  Progress<AuthenticatedUser> getAuthenticatedUser(Credentials credentials, PhotoManager photoManager) {
    log.add('TestTwitarr(${_configuration.id}).getAuthenticatedUser $credentials');
    return Progress<AuthenticatedUser>.completed(AuthenticatedUser(
      username: credentials.username,
      email: '<email for ${credentials.username}>',
      credentials: credentials,
    ));
  }

  @override
  Progress<Calendar> getCalendar() {
    log.add('TestTwitarr(${_configuration.id}).getCalendar');
    return const Progress<Calendar>.idle();
  }

  @override
  Future<void> updateSeamailThreads(
    Credentials credentials,
    Seamail seamail,
    PhotoManager photoManager,
    CancelationSignal cancelationSignal,
  ) async {
    log.add('updateSeamailThreads');
  }

  @override
  Progress<SeamailThread> newSeamail(
    Credentials credentials,
    Seamail seamail,
    PhotoManager photoManager,
    Set<User> users,
    String subject,
    String message,
  ) {
    log.add('newSeamail');
    return null;
  }

  @override
  Progress<Uint8List> fetchProfilePicture(String username) {
    log.add('fetchProfilePicture');
    return null;
  }

  @override
  Progress<List<User>> getUserList(String searchTerm) {
    log.add('getUserList');
    return null;
  }

  @override
  void dispose() {
    log.add('TestTwitarr(${_configuration.id}).dispose');
  }
}
