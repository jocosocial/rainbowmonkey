import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/calendar.dart';
import 'package:cruisemonkey/src/models/user.dart';
//import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/progress.dart';
import 'package:flutter/foundation.dart';

/*
class TestTwitarr implements Twitarr {
  @override
  ValueNotifier<Credentials> credentials = new ValueNotifier<Credentials>(null);

  @override
  Progress<Credentials> createAccount({
    @required String username,
    @required String password,
    @required String email,
    @required String securityQuestion,
    @required String securityAnswer,
  }) {
    throw new Exception('not implemented');
  }

  @override
  Progress<Credentials> login(Credentials credentials) {
    throw new Exception('not implemented');
  }

  @override
  Progress<Credentials> logout() {
    throw new Exception('not implemented');
  }

  @override
  Progress<User> get user => userCompleter.progress;
  ProgressCompleter<User> userCompleter = new ProgressCompleter<User>();

  @override
  Progress<Calendar> get calendar => calendarCompleter.progress;
  ProgressCompleter<Calendar> calendarCompleter = new ProgressCompleter<Calendar>();

  @override
  void dispose() {
    credentials.dispose();
  }
}

class AutoupdatingTestTwitarr implements Twitarr {
  AutoupdatingTestTwitarr({
    this.calendarGetter,
    this.calendarInterval: const Duration(seconds: 600),
  }) {
    _calendar = new PollingProgress<Calendar>(
      getter: calendarGetter,
      interval: calendarInterval,
    );
  }

  final ValueGetter<CancelableProgress<Calendar>> calendarGetter;
  final Duration calendarInterval;

  @override
  ValueNotifier<Credentials> credentials = new ValueNotifier<Credentials>(null);

  @override
  Progress<Credentials> createAccount({
    @required String username,
    @required String password,
    @required String email,
    @required String securityQuestion,
    @required String securityAnswer,
  }) {
    throw new Exception('not implemented');
  }

  @override
  Progress<Credentials> login(Credentials credentials) {
    throw new Exception('not implemented');
  }

  @override
  Progress<Credentials> logout() {
    throw new Exception('not implemented');
  }

  @override
  Progress<User> get user => _userCompleter.progress;
  ProgressCompleter<User> _userCompleter;

  @override
  Progress<Calendar> get calendar => _calendar;
  PollingProgress<Calendar> _calendar;

  @override
  void dispose() {
    credentials.dispose();
    _calendar.dispose();
  }
}
*/

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

class TestCruiseModel implements CruiseModel {
  TestCruiseModel({
    MutableContinuousProgress<User> user,
    MutableContinuousProgress<Calendar> calendar,
  }) : user = user ?? MutableContinuousProgress<User>(),
       calendar = calendar ?? MutableContinuousProgress<Calendar>();

  @override
  final Duration rarePollInterval = const Duration(minutes: 10);

  @override
  final Duration frequentPollInterval = const Duration(minutes: 1);

  @override
  final DataStore store = const TestDataStore();

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
  final MutableContinuousProgress<User> user;

  @override
  final MutableContinuousProgress<Calendar> calendar;

  @override
  void dispose() {
    user.dispose();
    calendar.dispose();
  }
}
