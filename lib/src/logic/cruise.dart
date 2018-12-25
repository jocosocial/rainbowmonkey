import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:meta/meta.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/calendar.dart';
import '../models/seamail.dart';
import '../models/user.dart';
import '../network/twitarr.dart';
import '../progress.dart';
import 'photo_manager.dart';
import 'store.dart';

// TODO(ianh): Move polling logic into RestTwitarr class

class CruiseModel extends ChangeNotifier implements PhotoManager {
  CruiseModel({
    @required TwitarrConfiguration twitarrConfiguration,
    @required this.store,
    this.frequentPollInterval = const Duration(seconds: 30), // e.g. twitarr
    this.rarePollInterval = const Duration(seconds: 600), // e.g. calendar
    this.maxSeamailUpdateDelay = const Duration(minutes: 5),
  }) : assert(twitarrConfiguration != null),
       assert(store != null),
       assert(frequentPollInterval != null),
       assert(rarePollInterval != null) {
    _setupTwitarr(twitarrConfiguration);
    _user = new PeriodicProgress<AuthenticatedUser>(rarePollInterval, _updateUser);
    _calendar = new PeriodicProgress<Calendar>(rarePollInterval, _updateCalendar);
    _seamail = new Seamail();
    _restoreCredentials();
  }

  final Duration rarePollInterval;
  final Duration frequentPollInterval;
  final Duration maxSeamailUpdateDelay;
  final DataStore store;

  bool _alive = true;
  Progress<Credentials> _pendingCredentials;
  Credentials _currentCredentials;

  Twitarr _twitarr;
  TwitarrConfiguration get twitarrConfiguration => _twitarr.configuration;
  void selectTwitarrConfiguration(TwitarrConfiguration newConfiguration) {
    final Twitarr oldTwitarr = _twitarr;
    final Progress<AuthenticatedUser> logoutProgress = oldTwitarr.logout();
    logoutProgress.asFuture().whenComplete(oldTwitarr.dispose);
    _setupTwitarr(newConfiguration);
    _reset();
  }

  void _setupTwitarr(TwitarrConfiguration configuration) {
    _twitarr = configuration.createTwitarr();
    _twitarr.debugLatency = _debugLatency;
    _twitarr.debugReliability = _debugReliability;
  }

  double get debugLatency => _debugLatency;
  double _debugLatency = 0.0;
  set debugLatency(double value) {
    _debugLatency = value;
    _twitarr.debugLatency = value;
    notifyListeners();
  }

  double get debugReliability => _debugReliability;
  double _debugReliability = 1.0;
  set debugReliability(double value) {
    _debugReliability = value;
    _twitarr.debugReliability = value;
    notifyListeners();
  }

  void _reset() {
    _cancelUpdateSeamail();
    _currentCredentials = null;
    _pendingCredentials?.removeListener(_saveCredentials);
    _pendingCredentials = null;
    _seamail = new Seamail();
    _user.reset();
    notifyListeners();
  }

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
      photoManager: this,
    ));
  }

  Progress<Credentials> logout() {
    return _updateCredentials(_twitarr.logout());
  }

  void _restoreCredentials() {
    _updateCredentials(new Progress<AuthenticatedUser>.deferred((ProgressController<AuthenticatedUser> completer) async {
      final Credentials credentials = await completer.chain<Credentials>(store.restoreCredentials());
      if (credentials != null && _alive) {
        return await completer.chain<AuthenticatedUser>(
          _twitarr.login(
            username: credentials.username,
            password: credentials.password,
            photoManager: this,
          ),
          steps: 2,
        );
      }
      return null;
    }));
  }

  Progress<Credentials> _updateCredentials(Progress<AuthenticatedUser> userProgress) {
    _reset();
    _user.addProgress(userProgress);
    final Progress<Credentials> result = Progress.convert<AuthenticatedUser, Credentials>(
      userProgress,
      (AuthenticatedUser user) => user?.credentials,
    );
    _pendingCredentials = result;
    _pendingCredentials?.addListener(_saveCredentials);
    return result;
  }

  void _saveCredentials() {
    final ProgressValue<Credentials> progress = _pendingCredentials?.value;
    if (progress is SuccessfulProgress<Credentials>) {
      _pendingCredentials.removeListener(_saveCredentials);
      _pendingCredentials = null;
      _currentCredentials = progress.value;
      assert(_currentCredentials == null || _currentCredentials.key != null);
      store.saveCredentials(_currentCredentials);
      if (_currentCredentials != null)
        updateSeamail();
    }
  }

  ContinuousProgress<AuthenticatedUser> get user => _user;
  PeriodicProgress<AuthenticatedUser> _user;

  Future<AuthenticatedUser> _updateUser(ProgressController<AuthenticatedUser> completer) async {
    if (_currentCredentials?.key != null)
      return await completer.chain<AuthenticatedUser>(_twitarr.getAuthenticatedUser(_currentCredentials, this));
    return null;
  }

  ContinuousProgress<Calendar> get calendar => _calendar;
  PeriodicProgress<Calendar> _calendar;

  Future<Calendar> _updateCalendar(ProgressController<Calendar> completer) {
    return completer.chain<Calendar>(_twitarr.getCalendar());
  }

  Seamail get seamail => _seamail;
  Seamail _seamail;
  CancelationSignal _ongoingSeamailUpdate;
  Duration _seamailUpdateDelay = Duration.zero;
  bool _seamailUpdateScheduled = false;

  void updateSeamail() async {
    if (_seamailUpdateScheduled) {
      assert(_ongoingSeamailUpdate != null);
      _cancelUpdateSeamail();
    } else if (_ongoingSeamailUpdate != null) {
      _seamailUpdateDelay = Duration.zero;
      return;
    }
    assert(_currentCredentials != null && _currentCredentials.key != null);
    assert(_ongoingSeamailUpdate == null);
    final CancelationSignal signal = new CancelationSignal();
    _ongoingSeamailUpdate = signal;
    if (_seamail.active) {
      await _twitarr.updateSeamailThreads(_currentCredentials, _seamail, this, signal); // I/O
      // ASYNCHRONOUS CONTINUATION
      if (signal.canceled)
        return;
      assert(_ongoingSeamailUpdate == signal);
      if (_seamailUpdateDelay < maxSeamailUpdateDelay)
        _seamailUpdateDelay = _seamailUpdateDelay + const Duration(seconds: 1);
      assert(!_seamailUpdateScheduled);
      _seamailUpdateScheduled = true;
      await Future<void>.delayed(_seamailUpdateDelay); // Timed-based delay
      // ASYNCHRONOUS CONTINUATION
      if (signal.canceled)
        return;
    }
    await _seamail.untilActive; // Demand-based delay
    // ASYNCHRONOUS CONTINUATION
    if (signal.canceled)
      return;
    assert(_ongoingSeamailUpdate == signal);
    _ongoingSeamailUpdate = null;
    _seamailUpdateScheduled = false;
    updateSeamail(); // TAIL RECURSION
  }

  void _cancelUpdateSeamail() {
    _ongoingSeamailUpdate?.cancel();
    _ongoingSeamailUpdate = null;
    _seamailUpdateScheduled = false;
  }

  Progress<SeamailThread> newSeamail(Set<User> users, String subject, String message) {
    assert(_currentCredentials != null && _currentCredentials.key != null);
    return _twitarr.newSeamail(_currentCredentials, seamail, this, users, subject, message);
  }

  @override
  Future<Uint8List> putIfAbsent(String username, PhotoFetcher callback) {
    // TODO(ianh): cache the image obtained by callback to disk
    // TODO(ianh): return the cached version if we have one
    return callback();
  }

  @override
  void heardAboutUserPhoto(String username, DateTime lastUpdate) {
    // TODO(ianh): clear the cache if we got the image before lastUpdate
  }

  Widget avatarFor(User user, { double size: 40.0 }) {
    final String name = user.displayName ?? user.username;
    List<String> names = name.split(new RegExp(r'[^A-Z]+'));
    if (names.length == 1)
      names = name.split(' ');
    if (names.length <= 2)
      names = name.split('');
    return new Builder(
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        final Color color = new Color(user.username.hashCode | 0xFF000000);
        TextStyle textStyle = theme.primaryTextTheme.subhead;
        switch (ThemeData.estimateBrightnessForColor(color)) {
          case Brightness.dark:
            textStyle = textStyle.copyWith(color: theme.primaryColorLight);
            break;
          case Brightness.light:
            textStyle = textStyle.copyWith(color: theme.primaryColorDark);
            break;
        }
        return new AnimatedContainer(
          decoration: new ShapeDecoration(
            shape: const CircleBorder(),
            color: color,
          ),
          child: new ClipOval(
            child: new Center(
              child: new Text(
                names.take(2).map<String>((String value) => new String.fromCharCode(value.runes.first)).join(''),
                style: textStyle,
                textScaleFactor: 1.0,
              ),
            ),
          ),
          foregroundDecoration: new ShapeDecoration(
            shape: const CircleBorder(),
            image: new DecorationImage(image: new AvatarImage(user.username, this, _twitarr)),
          ),
          duration: const Duration(milliseconds: 250),
          height: size,
          width: size,
        );
      },
    );
  }

  Progress<void> updateProfile({
    String currentLocation,
    String displayName,
    String email,
    bool emailPublic,
    String homeLocation,
    String realName,
    String roomNumber,
    bool vcardPublic,
  }) {
    return new Progress<void>((ProgressController<void> completer) async {
      await completer.chain(_twitarr.updateProfile(
        credentials: _currentCredentials,
        currentLocation: currentLocation,
        displayName: displayName,
        email: email,
        emailPublic: emailPublic,
        homeLocation: homeLocation,
        realName: realName,
        roomNumber: roomNumber,
        vcardPublic: vcardPublic,
      ));
      _user.triggerUnscheduledUpdate(); // this is non-blocking for the caller
    });
  }

  Progress<void> updatePassword({
    @required String oldPassword,
    @required String newPassword,
  }) {
    return null; // TODO(ianh): update password and update credentials
  }

  Progress<List<User>> getUserList(String searchTerm) {
    // consider caching, or filtering from existing data (e.g. if we have data
    // for "b" we could figure out the results for "be", if the server sent us
    // all the data it used to find the results, such as the user text data)
    return _twitarr.getUserList(searchTerm);
  }

  @override
  void dispose() {
    _alive = false;
    _ongoingSeamailUpdate?.cancel();
    _seamail.dispose();
    _seamail = null;
    _pendingCredentials?.removeListener(_saveCredentials);
    _user.dispose();
    _calendar.dispose();
    _twitarr.dispose();
    super.dispose();
  }
}

class AvatarImage extends ImageProvider<String> {
  const AvatarImage(this.username, this.photoManager, this.twitarr);

  final String username;

  final PhotoManager photoManager;

  final Twitarr twitarr;

  @override
  Future<String> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<String>(username);
  }

  @override
  ImageStreamCompleter load(String key) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _loadAsync(String key) async {
    final Uint8List bytes = await photoManager.putIfAbsent(
      key,
      () => twitarr.fetchProfilePicture(key).asFuture(),
    );
    return await PaintingBinding.instance.instantiateImageCodec(bytes);
  }

  @override
  String toString() => '$runtimeType($username)';
}
