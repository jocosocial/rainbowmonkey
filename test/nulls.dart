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

class NullDataStore implements DataStore {
  const NullDataStore();

  @override
  Progress<void> saveCredentials(Credentials value) => null;

  @override
  Progress<Credentials> restoreCredentials() => null;
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
  final Duration rarePollInterval = null;

  @override
  final Duration frequentPollInterval = null;

  @override
  final Duration maxSeamailUpdateDelay = null;

  @override
  final DataStore store = null;

  @override
  TwitarrConfiguration get twitarrConfiguration => null;

  @override
  void selectTwitarrConfiguration(TwitarrConfiguration newConfiguration) { }

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
  final MutableContinuousProgress<AuthenticatedUser> user = null;

  @override
  AuthenticatedUser get currentUser => null;

  @override
  final MutableContinuousProgress<Calendar> calendar = null;

  @override
  Seamail get seamail => null;

  @override
  void updateSeamail() { }

  @override
  Progress<SeamailThread> newSeamail(Set<User> users, String subject, String message) => null;

  @override
  Future<Uint8List> putIfAbsent(String username, PhotoFetcher callback) => null;

  @override
  void heardAboutUserPhoto(String username, DateTime lastUpdate) => null;

  @override
  Widget avatarFor(User user, { double size: 40.0 }) => null;

  @override
  Progress<List<User>> getUserList(String searchTerm) => null;

  @override
  void dispose() { }
}
