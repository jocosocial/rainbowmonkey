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

class NullDataStore implements DataStore {
  const NullDataStore();

  @override
  Progress<void> saveCredentials(Credentials value) => null;

  @override
  Progress<Credentials> restoreCredentials() => null;

  @override
  Progress<void> saveSetting(Setting id, dynamic value) => null;

  @override
  Progress<Map<Setting, dynamic>> restoreSettings() => null;

  @override
  Progress<dynamic> restoreSetting(Setting id) => null;

  @override
  Future<void> addNotification(String threadId, String messageId) => null;

  @override
  Future<void> removeNotification(String threadId, String messageId) => null;

  @override
  Future<List<String>> getNotifications(String threadId) => null;

  @override
  Future<void> updateFreshnessToken(FreshnessCallback callback) => null;
}

class NullTwitarrConfiguration extends TwitarrConfiguration {
  const NullTwitarrConfiguration();

  @override
  Twitarr createTwitarr() => null;
}

class NullCruiseModel implements CruiseModel {
  NullCruiseModel();

  // LISTENABLE

  @override
  bool get hasListeners => null;

  @override
  void addListener(VoidCallback listener) { }

  @override
  void removeListener(VoidCallback listener) { }

  @override
  void notifyListeners() { }


  // CRUISE MODEL

  @override
  final ErrorCallback onError = null;

  @override
  final CheckForMessagesCallback onCheckForMessages = null;

  @override
  final Duration rarePollInterval = null;

  @override
  final Duration frequentPollInterval = null;

  @override
  final DataStore store = null;

  @override
  TwitarrConfiguration get twitarrConfiguration => null;

  @override
  void selectTwitarrConfiguration(TwitarrConfiguration newConfiguration) { }

  @override
  double debugLatency = 0.0;

  @override
  double debugReliability = 1.0;

  @override
  bool get restoringSettings => false;

  @override
  Progress<Credentials> createAccount({
    @required String username,
    @required String password,
    @required String registrationCode,
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
  final MutableContinuousProgress<AuthenticatedUser> user = null;

  @override
  bool get isLoggedIn => null;

  @override
  Future<void> get loggedIn => null;

  @override
  final MutableContinuousProgress<Calendar> calendar = null;

  @override
  Seamail get seamail => null;

  @override
  Future<Uint8List> putIfAbsent(String username, PhotoFetcher callback) => null;

  @override
  void heardAboutUserPhoto(String username, DateTime lastUpdate) { }

  @override
  void addListenerForPhoto(String username, VoidCallback listener) { }

  @override
  void removeListenerForPhoto(String username, VoidCallback listener) { }

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
  void dispose() { }
}
