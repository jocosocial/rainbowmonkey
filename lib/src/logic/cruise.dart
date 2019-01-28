import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show Codec, FrameInfo;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

import '../basic_types.dart';
import '../models/calendar.dart';
import '../models/user.dart';
import '../network/rest.dart' show RestTwitarrConfiguration;
import '../network/twitarr.dart';
import '../progress.dart';
import 'notifications.dart';
import 'photo_manager.dart';
import 'seamail.dart';
import 'store.dart';
import 'stream.dart';

// TODO(ianh): Move polling logic into RestTwitarr class

typedef CheckForMessagesCallback = void Function(Credentials credentials, Twitarr twitarr, DataStore store);

class CruiseModel extends ChangeNotifier implements PhotoManager {
  CruiseModel({
    @required TwitarrConfiguration initialTwitarrConfiguration,
    @required this.store,
    this.frequentPollInterval = const Duration(seconds: 30), // e.g. twitarr
    this.rarePollInterval = const Duration(seconds: 3600), // e.g. calendar
    @required this.onError,
    this.onCheckForMessages,
  }) : assert(initialTwitarrConfiguration != null),
       assert(store != null),
       assert(frequentPollInterval != null),
       assert(rarePollInterval != null),
       assert(onError != null) {
    _setupTwitarr(initialTwitarrConfiguration);
    _restoreSettings(); // async
    _user = PeriodicProgress<AuthenticatedUser>(rarePollInterval, _updateUser);
    _calendar = PeriodicProgress<Calendar>(rarePollInterval, _updateCalendar); // TODO(ianh): autoretry faster on network failure
    _seamail = Seamail.empty();
    _restorePhotos(); // async
  }

  final Duration rarePollInterval;
  final Duration frequentPollInterval;
  final DataStore store;
  final ErrorCallback onError;

  final CheckForMessagesCallback onCheckForMessages;

  bool _alive = true;
  Progress<Credentials> _pendingCredentials;
  Credentials _currentCredentials;

  void _setupTwitarr(TwitarrConfiguration configuration) {
    _twitarr = configuration.createTwitarr();
    _twitarr.debugLatency = _debugLatency;
    _twitarr.debugReliability = _debugReliability;
  }

  // Caller must call notifyListeners
  void _reset() {
    Notifications.instance.then<void>((Notifications notifications) => notifications.cancelAll());
    _currentCredentials = null;
    _pendingCredentials?.removeListener(_handleCredentialsChange);
    _pendingCredentials = null;
    _seamail = Seamail.empty();
    _user.reset();
    if (_loggedIn.isCompleted)
      _loggedIn = Completer<void>();
  }

  Twitarr _twitarr;
  TwitarrConfiguration get twitarrConfiguration => _twitarr.configuration;
  void selectTwitarrConfiguration(TwitarrConfiguration newConfiguration) {
    assert(_twitarr != null);
    if (newConfiguration == _twitarr.configuration)
      return;
    final Twitarr oldTwitarr = _twitarr;
    final Progress<AuthenticatedUser> logoutProgress = oldTwitarr.logout();
    logoutProgress
      .asFuture()
      .catchError(
        (Object error, StackTrace stack) {
          if (onError != null && error is UserFriendlyError) {
            onError('$error');
            return null;
          }
          return Future<AuthenticatedUser>.error(error, stack);
        },
        test: (Object error) => error is UserFriendlyError,
      )
      .whenComplete(oldTwitarr.dispose);
    _reset();
    _setupTwitarr(newConfiguration);
    _calendar.triggerUnscheduledUpdate();
    if (newConfiguration is RestTwitarrConfiguration) // TODO(ianh): use a configuration class registry
      store.saveSetting(Setting.server, newConfiguration.baseUrl);
    notifyListeners();
  }

  // TODO(ianh): save this in the store
  double get debugLatency => _debugLatency;
  double _debugLatency = 0.0;
  set debugLatency(double value) {
    _debugLatency = value;
    _twitarr.debugLatency = value;
    store.saveSetting(Setting.debugNetworkLatency, value);
    notifyListeners();
  }

  // TODO(ianh): save this in the store
  double get debugReliability => _debugReliability;
  double _debugReliability = 1.0;
  set debugReliability(double value) {
    _debugReliability = value;
    _twitarr.debugReliability = value;
    store.saveSetting(Setting.debugNetworkReliability, value);
    notifyListeners();
  }

  Future<void> _restoredSettings;
  bool get restoringSettings => _restoringSettings;
  bool _restoringSettings = false;
  void _restoreSettings() async {
    assert(!_restoringSettings);
    assert(_restoredSettings == null);
    _restoringSettings = true;
    final Completer<void> done = Completer<void>();
    _restoredSettings = done.future;
    try {
      final Map<Setting, dynamic> settings = await store.restoreSettings().asFuture();
      if (settings != null) {
        if (settings.containsKey(Setting.debugNetworkLatency))
          debugLatency = settings[Setting.debugNetworkLatency] as double;
        if (settings.containsKey(Setting.debugNetworkReliability))
          debugReliability = settings[Setting.debugNetworkReliability] as double;
        if (settings.containsKey(Setting.server))
          selectTwitarrConfiguration(RestTwitarrConfiguration(baseUrl: settings[Setting.server] as String));
        if (settings.containsKey(Setting.debugTimeDilation)) {
          timeDilation = settings[Setting.debugTimeDilation] as double;
          await SchedulerBinding.instance.reassembleApplication();
        }
      }
      final Credentials credentials = await store.restoreCredentials().asFuture();
      if (credentials != null && _alive) {
        // TODO(ianh): autoretry on network failure
        _twitarr.login(
          username: credentials.username,
          password: credentials.password,
          photoManager: this,
        );
      }
    } finally {
      _restoringSettings = false;
      done.complete();
      notifyListeners();
    }
  }

  Seamail get seamail => _seamail;
  Seamail _seamail;

  TweetStream createTweetStream() {
    return TweetStream(
      _twitarr,
      _currentCredentials,
      photoManager: this,
      onError: (dynamic error, StackTrace stack) => onError('$error'),
    );
  }

  Progress<Credentials> createAccount({
    @required String username,
    @required String password,
    @required String registrationCode,
    @required String email,
    @required String securityQuestion,
    @required String securityAnswer,
  }) {
    return _updateCredentials(_twitarr.createAccount(
      username: username,
      password: password,
      registrationCode: registrationCode,
      email: email,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    ));
  }

  Progress<Credentials> login({
    @required String username,
    @required String password,
  }) {
    // TODO(ianh): autoretry on network failure
    return _updateCredentials(_twitarr.login(
      username: username,
      password: password,
      photoManager: this,
    ));
  }

  Progress<Credentials> logout() {
    return _updateCredentials(_twitarr.logout());
  }

  Progress<Credentials> _updateCredentials(Progress<AuthenticatedUser> userProgress) {
    _reset();
    _user.addProgress(userProgress);
    final Progress<Credentials> result = Progress.convert<AuthenticatedUser, Credentials>(
      userProgress,
      (AuthenticatedUser user) => user?.credentials,
    );
    _pendingCredentials = result;
    _pendingCredentials?.addListener(_handleCredentialsChange);
    notifyListeners();
    return result;
  }

  void _handleCredentialsChange() {
    final ProgressValue<Credentials> progress = _pendingCredentials?.value;
    if (progress is SuccessfulProgress<Credentials>) {
      _pendingCredentials.removeListener(_handleCredentialsChange);
      _pendingCredentials = null;
      _currentCredentials = progress.value;
      assert(_currentCredentials == null || _currentCredentials.key != null);
      store.saveCredentials(_currentCredentials);
      if (_currentCredentials != null) {
        _seamail = Seamail(
          _twitarr,
          _currentCredentials,
          this,
          onError: onError,
          onCheckForMessages: () {
            if (onCheckForMessages != null)
              onCheckForMessages(_currentCredentials, _twitarr, store);
          },
          onThreadRead: _handleThreadRead,
        );
        _loggedIn.complete();
      }
      notifyListeners();
    }
  }

  void _handleThreadRead(String threadId) async {
    final Notifications notifications = await Notifications.instance;
    for (String messageId in await store.getNotifications(threadId)) {
      await notifications.messageRead(threadId, messageId);
      await store.removeNotification(threadId, messageId);
    }
  }

  ContinuousProgress<AuthenticatedUser> get user => _user;
  PeriodicProgress<AuthenticatedUser> _user;

  bool get isLoggedIn => _currentCredentials != null;
  Future<void> get loggedIn => _loggedIn.future;
  Completer<void> _loggedIn = Completer<void>();

  Future<AuthenticatedUser> _updateUser(ProgressController<AuthenticatedUser> completer) async {
    await _restoredSettings;
    if (_currentCredentials?.key != null)
      return await completer.chain<AuthenticatedUser>(_twitarr.getAuthenticatedUser(_currentCredentials, this));
    return null;
  }

  ContinuousProgress<Calendar> get calendar => _calendar;
  PeriodicProgress<Calendar> _calendar;

  Future<Calendar> _updateCalendar(ProgressController<Calendar> completer) async {
    await _restoredSettings;
    return await completer.chain<Calendar>(_twitarr.getCalendar());
  }

  final Map<String, DateTime> _photoUpdates = <String, DateTime>{};
  final Map<String, Set<VoidCallback>> _photoListeners = <String, Set<VoidCallback>>{};

  Future<void> _photosBusy = Future<void>.value();
  Future<T> _queuePhotosWork<T>(AsyncValueGetter<T> callback) async {
    final Future<void> lastLock = _photosBusy;
    final Completer<void> currentLock = Completer<void>();
    _photosBusy = currentLock.future;
    T result;
    try {
      await lastLock;
      result = await callback();
    } finally {
      currentLock.complete();
    }
    return result;
  }

  bool _storeQueued = false;
  Future<void> _storePhotos() async {
    if (_storeQueued)
      return;
    _storeQueued = true;
    await _queuePhotosWork<void>(() {
      // TODO(ianh): store the _photoUpdates map to disk
      _storeQueued = false;
    });
  }

  Future<void> _restorePhotos() async {
    await _queuePhotosWork<void>(() {
      // TODO(ianh): restore the _photoUpdates map from disk
    });
  }

  @override
  Future<Uint8List> putIfAbsent(String username, PhotoFetcher callback) {
    return _queuePhotosWork<Uint8List>(() {
      // TODO(ianh): cache the image obtained by callback to disk
      // TODO(ianh): return the cached version if we have one
      _storePhotos();
      return callback();
    });
  }

  @override
  void heardAboutUserPhoto(String username, DateTime lastUpdate) {
    _queuePhotosWork<void>(() {
      if (!_photoUpdates.containsKey(username) || _photoUpdates[username].isBefore(lastUpdate)) {
        _photoUpdates[username] = lastUpdate;
        _notifyUserPhotoListeners(username);
        _storePhotos();
      }
    });
  }

  void _resetUserPhoto(String username) {
    _queuePhotosWork<void>(() {
      // TODO(ianh): clear the cache
      _photoUpdates.remove(username);
      _notifyUserPhotoListeners(username);
      _storePhotos();
    });
  }

  @override
  void addListenerForPhoto(String username, VoidCallback listener) {
    final Set<VoidCallback> callbacks = _photoListeners.putIfAbsent(username, () => Set<VoidCallback>());
    callbacks.add(listener);
  }

  @override
  void removeListenerForPhoto(String username, VoidCallback listener) {
    if (_photoListeners.containsKey(username)) {
      final Set<VoidCallback> callbacks = _photoListeners[username];
      callbacks.remove(listener);
    }
  }

  void _notifyUserPhotoListeners(String username) {
    final Set<VoidCallback> callbacks = _photoListeners[username];
    if (callbacks != null) {
      for (VoidCallback callback in callbacks)
        callback();
    }
  }

  Widget avatarFor(User user, { double size: 40.0 }) {
    final String name = user.displayName ?? user.username;
    List<String> names = name.split(RegExp(r'[^A-Z]+'));
    if (names.length == 1)
      names = name.split(' ');
    if (names.length <= 2)
      names = name.split('');
    return Builder(
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        final Color color = Color(user.username.hashCode | 0xFF000000);
        TextStyle textStyle = theme.primaryTextTheme.subhead;
        switch (ThemeData.estimateBrightnessForColor(color)) {
          case Brightness.dark:
            textStyle = textStyle.copyWith(color: theme.primaryColorLight);
            break;
          case Brightness.light:
            textStyle = textStyle.copyWith(color: theme.primaryColorDark);
            break;
        }
        return AnimatedContainer(
          decoration: ShapeDecoration(
            shape: const CircleBorder(),
            color: color,
          ),
          child: ClipOval(
            child: Center(
              child: Text(
                names.take(2).map<String>((String value) => String.fromCharCode(value.runes.first)).join(''),
                style: textStyle,
                textScaleFactor: 1.0,
              ),
            ),
          ),
          foregroundDecoration: ShapeDecoration(
            shape: const CircleBorder(),
            image: DecorationImage(image: AvatarImage(user.username, this, _twitarr)),
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
    return Progress<void>((ProgressController<void> completer) async {
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

  Progress<void> uploadAvatar({ Uint8List image }) {
    return Progress<void>((ProgressController<void> completer) async {
      if (image != null) {
        await completer.chain(_twitarr.uploadAvatar(
          credentials: _currentCredentials,
          bytes: image,
        ));
      } else {
        await completer.chain(_twitarr.resetAvatar(
          credentials: _currentCredentials,
        ));
      }
      _resetUserPhoto(_currentCredentials.username);
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

  Progress<void> postTweet({
    String text,
    String parentId,
    // TODO(ianh): photo
  }) {
    return _twitarr.postTweet(
      credentials: _currentCredentials,
      text: text,
      parentId: parentId,
    );
  }

  @override
  void dispose() {
    _alive = false;
    _pendingCredentials?.removeListener(_handleCredentialsChange);
    _user.dispose();
    _calendar.dispose();
    _twitarr.dispose();
    super.dispose();
  }
}

class AvatarImage extends ImageProvider<AvatarImage> {
  const AvatarImage(this.username, this.photoManager, this.twitarr);

  final String username;

  final PhotoManager photoManager;

  final Twitarr twitarr;

  @override
  Future<AvatarImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AvatarImage>(this);
  }

  @override
  ImageStreamCompleter load(AvatarImage key) {
    assert(key == this);
    return AvatarImageStreamCompleter(username, photoManager, twitarr);
  }

  @override
  String toString() => '$runtimeType($username)';

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    final AvatarImage typedOther = other as AvatarImage;
    return username == typedOther.username
        && photoManager == typedOther.photoManager
        && twitarr == typedOther.twitarr;
  }

  @override
  int get hashCode => hashValues(
    username,
    photoManager,
    twitarr,
  );

}

class AvatarImageStreamCompleter extends ImageStreamCompleter {
  AvatarImageStreamCompleter(this.username, this.photoManager, this.twitarr) {
    _update();
  }

  final String username;

  final PhotoManager photoManager;

  final Twitarr twitarr;

  bool _busy = false;
  bool _dirty = true;

  Future<void> _update() async {
    _dirty = true;
    if (_busy)
      return;
    _busy = true;
    while (_dirty) {
      _dirty = false;
      try {
        final Uint8List bytes = await photoManager.putIfAbsent(
          username,
          () => twitarr.fetchProfilePicture(username).asFuture(),
        );
        final ui.Codec codec = await PaintingBinding.instance.instantiateImageCodec(bytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        setImage(ImageInfo(image: frameInfo.image));
      } catch (error, stack) { // ignore: avoid_catches_without_on_clauses
        // it's ok to catch all errors here, as we're just rerouting them, not swallowing them
        reportError(exception: error, stack: stack);
      }
    }
    _busy = false;
  }

  // TODO(ianh): remove once https://github.com/flutter/flutter/pull/25865 lands
  @protected
  bool get hasListeners => _listenerCount > 0;
  int _listenerCount = 0;

  @override
  void addListener(ImageListener listener, { ImageErrorListener onError }) {
    if (!hasListeners)
      photoManager.addListenerForPhoto(username, _update);
    _listenerCount += 1; // TODO(ianh): remove once https://github.com/flutter/flutter/pull/25865 lands
    super.addListener(listener, onError: onError);
  }

  @override
  void removeListener(ImageListener listener) {
    super.removeListener(listener);
    _listenerCount -= 1; // TODO(ianh): remove as this is bogus, removeListener can remove multiple listeners; see https://github.com/flutter/flutter/pull/25865
    if (!hasListeners)
      photoManager.removeListenerForPhoto(username, _update);
  }
}
