import 'dart:async';
import 'dart:typed_data';

import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/logic/photo_manager.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/calendar.dart';
import 'package:cruisemonkey/src/models/seamail.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/progress.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class TestDataStore implements DataStore {
  const TestDataStore();

  @override
  Progress<void> saveCredentials(Credentials value) {
    return const Progress<void>.idle();
  }

  @override
  Progress<Credentials> restoreCredentials() {
    return const Progress<Credentials>.idle();
  }
}

class TestTwitarrConfiguration extends TwitarrConfiguration {
  const TestTwitarrConfiguration();

  @override
  Twitarr createTwitarr() => null;
}

class TestCruiseModel extends ChangeNotifier implements CruiseModel {
  TestCruiseModel({
    MutableContinuousProgress<AuthenticatedUser> user,
    MutableContinuousProgress<Calendar> calendar,
  }) : user = user ?? MutableContinuousProgress<AuthenticatedUser>(),
       calendar = calendar ?? MutableContinuousProgress<Calendar>();

  @override
  final Duration rarePollInterval = const Duration(minutes: 10);

  @override
  final Duration frequentPollInterval = const Duration(minutes: 1);

  @override
  final Duration maxSeamailUpdateDelay = null;

  @override
  final DataStore store = const TestDataStore();

  @override
  TwitarrConfiguration get twitarrConfiguration => const TestTwitarrConfiguration();

  @override
  double debugLatency = 0.0;

  @override
  double debugReliability = 1.0;

  @override
  void selectTwitarrConfiguration(TwitarrConfiguration newConfiguration) {
    assert(newConfiguration is TestTwitarrConfiguration);
  }

  @override
  Progress<Credentials> createAccount({
    @required String username,
    @required String password,
    @required String email,
    @required String securityQuestion,
    @required String securityAnswer,
  }) {
    return const Progress<Credentials>.idle();
  }

  @override
  Progress<Credentials> login({
    @required String username,
    @required String password,
  }) {
    return const Progress<Credentials>.idle();
  }

  @override
  Progress<Credentials> logout() {
    return const Progress<Credentials>.idle();
  }

  @override
  final MutableContinuousProgress<AuthenticatedUser> user;

  @override
  final MutableContinuousProgress<Calendar> calendar;

  @override
  Seamail get seamail => _seamail;
  final TestSeamail _seamail = new TestSeamail();

  @override
  void updateSeamail() { }

  @override
  Progress<SeamailThread> newSeamail(Set<User> users, String subject, String message) => null;

  @override
  Future<Uint8List> putIfAbsent(String username, PhotoFetcher callback) {
    return callback();
  }

  @override
  void heardAboutUserPhoto(String username, DateTime lastUpdate) {
  }

  @override
  Widget avatarFor(User user, { double size: 40.0 }) => null;

  @override
  Progress<void> updateProfile({
    String currentLocation,
    String displayName,
    String email,
    bool emailPublic,
    String homeLocation,
    String realName,
    String roomNumber,
    bool vcardPublic,
  }) => null;

  @override
  Progress<void> updatePassword({
    @required String oldPassword,
    @required String newPassword,
  }) => null;

  @override
  Progress<List<User>> getUserList(String searchTerm) => null;

  @override
  void dispose() {
    user.dispose();
    calendar.dispose();
    super.dispose();
  }
}

class TestSeamail implements Seamail {
  TestSeamail();

  @override
  bool get active => hasListeners;

  @override
  Future<void> get untilActive => new Completer<void>().future;

  @override
  bool get hasListeners => null;

  @override
  void addListener(VoidCallback listener) { }

  @override
  void removeListener(VoidCallback listener) { }

  @override
  void notifyListeners() { }

  @override
  void dispose() { }

  @override
  SeamailThread operator[](int index) => null;

  @override
  int get length => 0;

  @override
  SeamailThread threadById(String id) => null;

  @override
  DateTime get lastUpdate => null;

  @override
  void update(DateTime timestamp, SeamailUpdateCallback updateCallback) { }
}
