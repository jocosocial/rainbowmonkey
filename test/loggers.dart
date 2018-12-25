import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/logic/photo_manager.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/calendar.dart';
import 'package:cruisemonkey/src/models/seamail.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/progress.dart';

class LoggingDataStore implements DataStore {
  LoggingDataStore(this.log);

  final List<String> log;

  @override
  Progress<void> saveCredentials(Credentials value) {
    log.add('LoggingDataStore.saveCredentials $value');
    return Progress<void>.completed(null);
  }
  @override
  Progress<Credentials> restoreCredentials() {
    log.add('LoggingDataStore.restoreCredentials');
    return Progress<Credentials>.completed(null);
  }
}

@immutable
class LoggingTwitarrConfiguration extends TwitarrConfiguration {
  const LoggingTwitarrConfiguration(this.id, this.log);

  final int id;

  final List<String> log;

  @override
  Twitarr createTwitarr() => LoggingTwitarr(this, log);

  @override
  String toString() => 'LoggingTwitarrConfiguration($id)';
}

class LoggingTwitarr extends Twitarr {
  LoggingTwitarr(this._configuration, this.log);

  final LoggingTwitarrConfiguration _configuration;

  final List<String> log;

  String overrideCurrentLocation;

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
    log.add('LoggingTwitarr(${_configuration.id}).createAccount $username / $password / $email / $securityQuestion / $securityAnswer');
    return Progress<AuthenticatedUser>.completed(AuthenticatedUser(
      username: username,
      email: email,
      currentLocation: overrideCurrentLocation,
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
    log.add('LoggingTwitarr(${_configuration.id}).login $username / $password');
    return Progress<AuthenticatedUser>.completed(AuthenticatedUser(
      username: username,
      email: '<email for $username>',
      currentLocation: overrideCurrentLocation,
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
    log.add('LoggingTwitarr(${_configuration.id}).logout');
    return Progress<AuthenticatedUser>.completed(null);
  }

  @override
  Progress<AuthenticatedUser> getAuthenticatedUser(Credentials credentials, PhotoManager photoManager) {
    log.add('LoggingTwitarr(${_configuration.id}).getAuthenticatedUser $credentials');
    return Progress<AuthenticatedUser>.completed(AuthenticatedUser(
      username: credentials.username,
      email: '<email for ${credentials.username}>',
      currentLocation: overrideCurrentLocation,
      credentials: credentials,
    ));
  }

  @override
  Progress<Calendar> getCalendar() {
    log.add('LoggingTwitarr(${_configuration.id}).getCalendar');
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
  Progress<void> updateProfile({
    @required Credentials credentials,
    String currentLocation,
    String displayName,
    String email,
    bool emailPublic,
    String homeLocation,
    String realName,
    String roomNumber,
    bool vcardPublic,
  }) {
    log.add('updateProfile $currentLocation/$displayName/$email/$emailPublic/$homeLocation/$realName/$roomNumber/$vcardPublic');
    return Progress<void>.completed(null);
  }

  @override
  Progress<void> updatePassword({
    @required Credentials credentials,
    @required String oldPassword,
    @required String newPassword,
  }) {
    log.add('updatePassword');
    return null;
  }

  @override
  Progress<List<User>> getUserList(String searchTerm) {
    log.add('getUserList');
    return null;
  }

  @override
  void dispose() {
    log.add('LoggingTwitarr(${_configuration.id}).dispose');
  }
}
