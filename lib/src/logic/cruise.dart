import 'dart:async';

import 'package:meta/meta.dart';
import 'package:flutter/foundation.dart';

import '../models/calendar.dart';
import '../models/user.dart';
import '../network/rest.dart'; // TODO(ianh): not depend directly on this
import '../network/twitarr.dart';
import '../progress.dart';
import 'store.dart';

class CruiseModel {
  CruiseModel({
    this.frequentPollInterval = const Duration(seconds: 30), // e.g. twitarr
    this.rarePollInterval = const Duration(seconds: 600), // e.g. calendar
    @required this.store,
  }) : assert(frequentPollInterval != null),
       assert(rarePollInterval != null),
       assert(store != null) {
    _user = new PeriodicProgress<User>(rarePollInterval, _updateUser);
    _calendar = new PeriodicProgress<Calendar>(rarePollInterval, _updateCalendar);
    _restoreCredentials();
  }

  final Duration rarePollInterval;
  final Duration frequentPollInterval;
  final DataStore store;

  // TODO(ianh): replace with configurable option
  final Twitarr _twitarr = new RestTwitarr(
    baseUrl: 'http://drang.prosedev.com:3000/',
  );

  bool _alive = true;

  Progress<Credentials> createAccount({
    @required String username,
    @required String password,
    @required String email,
    @required String securityQuestion,
    @required String securityAnswer,
  }) {
    return _updateCredentials(_twitarr.createAccount(
      username: username,
      password: password,
      email: email,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    ));
  }

  Progress<Credentials> login({
    @required String username,
    @required String password,
  }) {
    return _updateCredentials(_twitarr.login(
      username: username,
      password: password,
    ));
  }

  Progress<Credentials> logout() {
    return _updateCredentials(_twitarr.logout());
  }

  Progress<Credentials> _pendingCredentials;
  Credentials _currentCredentials = const Credentials();

  Progress<Credentials> _updateCredentials(Progress<User> userProgress) {
    _currentCredentials = null;
    _user.reset();
    _user.addProgress(userProgress);
    final Progress<Credentials> result = Progress.convert<User, Credentials>(
      userProgress,
      (User user) => user?.credentials ?? const Credentials(),
    );
    _pendingCredentials?.removeListener(_saveCredentials);
    _pendingCredentials = result;
    _pendingCredentials?.addListener(_saveCredentials);
    return result;
  }

  void _saveCredentials() {
    final ProgressValue<Credentials> progress = _pendingCredentials.value;
    if (progress is SuccessfulProgress<Credentials>) {
      _currentCredentials = progress.value;
      store.saveCredentials(_currentCredentials);
      _pendingCredentials.removeListener(_saveCredentials);
      _pendingCredentials = null;
    }
  }

  void _restoreCredentials() {
    _updateCredentials(new Progress<User>.deferred((ProgressController<User> completer) async {
      final Credentials credentials = await completer.chain<Credentials>(store.restoreCredentials());
      if (credentials != null && _alive) {
        return await completer.chain<User>(
          _twitarr.login(
            username: credentials.username,
            password: credentials.password,
          ), steps: 2,
        );
      }
      return null;
    }));
  }

  ContinuousProgress<User> get user => _user;
  PeriodicProgress<User> _user;

  Future<User> _updateUser(ProgressController<User> completer) async {
    if (_currentCredentials.key != null)
      return await completer.chain<User>(_twitarr.getAuthenticatedUser(_currentCredentials));
    return null;
  }

  ContinuousProgress<Calendar> get calendar => _calendar;
  PeriodicProgress<Calendar> _calendar;

  Future<Calendar> _updateCalendar(ProgressController<Calendar> completer) {
    return completer.chain<Calendar>(_twitarr.getCalendar());
  }

  void dispose() {
    _alive = false;
    _pendingCredentials?.removeListener(_saveCredentials);
    _user.dispose();
    _calendar.dispose();
    _twitarr.dispose();
  }
}
