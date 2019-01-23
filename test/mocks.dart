import 'dart:async';
import 'dart:typed_data';

import 'package:cruisemonkey/src/basic_types.dart';
import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/logic/photo_manager.dart';
import 'package:cruisemonkey/src/logic/seamail.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/calendar.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/progress.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class HangingDataStore implements DataStore {
  const HangingDataStore();

  @override
  Progress<void> saveCredentials(Credentials value) {
    return const Progress<void>.idle();
  }

  @override
  Progress<Credentials> restoreCredentials() {
    return const Progress<Credentials>.idle();
  }

  @override
  Progress<void> saveSetting(Setting id, dynamic value) {
    return const Progress<void>.idle();
  }

  @override
  Progress<Map<Setting, dynamic>> restoreSettings() {
    return const Progress<Map<Setting, dynamic>>.idle();
  }

  @override
  Progress<dynamic> restoreSetting(Setting id) {
    return const Progress<dynamic>.idle();
  }

  @override
  Future<void> addNotification(String threadId, String messageId) {
    return Completer<void>().future;
  }

  @override
  Future<void> removeNotification(String threadId, String messageId) {
    return Completer<void>().future;
  }

  @override
  Future<List<String>> getNotifications(String threadId) {
    return Completer<List<String>>().future;
  }

  @override
  Future<void> updateFreshnessToken(FreshnessCallback callback) {
    return Completer<List<String>>().future;
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
       calendar = calendar ?? MutableContinuousProgress<Calendar>() {
    _seamail = Seamail.empty();
  }

  @override
  final ErrorCallback onError = null;

  @override
  final CheckForMessagesCallback onCheckForMessages = null;

  @override
  final Duration rarePollInterval = const Duration(minutes: 10);

  @override
  final Duration frequentPollInterval = const Duration(minutes: 1);

  @override
  final DataStore store = const HangingDataStore();

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
  bool get restoringSettings => false;

  @override
  Seamail get seamail => _seamail;
  Seamail _seamail;

  @override
  Progress<Credentials> createAccount({
    @required String username,
    @required String password,
    @required String registrationCode,
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
  bool get loggedIn => false;

  @override
  final MutableContinuousProgress<Calendar> calendar;

  @override
  Future<Uint8List> putIfAbsent(String username, PhotoFetcher callback) {
    return callback();
  }

  @override
  void heardAboutUserPhoto(String username, DateTime lastUpdate) {
  }

  @override
  void addListenerForPhoto(String username, VoidCallback listener) {
  }

  @override
  void removeListenerForPhoto(String username, VoidCallback listener) {
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
  Progress<void> uploadAvatar({ Uint8List image }) => null;

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
