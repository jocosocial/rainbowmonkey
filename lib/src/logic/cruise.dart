import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show Codec, FrameInfo;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

import '../basic_types.dart';
import '../models/announcements.dart';
import '../models/calendar.dart';
import '../models/server_text.dart';
import '../models/user.dart';
import '../network/rest.dart' show AutoTwitarrConfiguration;
import '../network/twitarr.dart';
import '../progress.dart';
import '../widgets.dart';
import 'forums.dart';
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
    this.steadyPollInterval = const Duration(minutes: 10),
    @required this.onError,
    this.onCheckForMessages,
  }) : assert(initialTwitarrConfiguration != null),
       assert(store != null),
       assert(steadyPollInterval != null),
       assert(onError != null) {
    _user = PeriodicProgress<AuthenticatedUser>(steadyPollInterval, _updateUser);
    _calendar = PeriodicProgress<Calendar>(steadyPollInterval, _updateCalendar);
    _announcements = PeriodicProgress<List<Announcement>>(steadyPollInterval, _updateAnnouncements);
    _busy(() {
      selectTwitarrConfiguration(initialTwitarrConfiguration); // sync
      _seamail = Seamail.empty();
      _forums = _createForums();
      _restoreSettings(); // async
      _restorePhotos(); // async
    });
  }

  final Duration steadyPollInterval;
  final DataStore store;
  final ErrorCallback onError;

  final CheckForMessagesCallback onCheckForMessages;

  bool _alive = true;
  Credentials _currentCredentials;

  Credentials _preBusyCredentials;

  int _busyCounter = 0;
  void _busy(AsyncCallback callback) async {
    if (_busyCounter == 0) {
      _user.pause();
      _calendar.pause();
      _announcements.pause();
      _preBusyCredentials = _currentCredentials;
    }
    _busyCounter += 1;
    try {
      await callback();
    } finally {
      _busyCounter -= 1;
      if (_busyCounter == 0) {
        _user.resume();
        _calendar.resume();
        _announcements.resume();
        if (_preBusyCredentials != null && _preBusyCredentials != _currentCredentials)
          await Notifications.instance.then<void>((Notifications notifications) => notifications.cancelAll());
      }
    }
  }

  Twitarr _twitarr;
  TwitarrConfiguration get twitarrConfiguration => _twitarr.configuration;
  void selectTwitarrConfiguration(TwitarrConfiguration newConfiguration) {
    _busy(() {
      if (_twitarr != null) {
        if (newConfiguration == _twitarr.configuration)
          return;
        _twitarr.dispose();
      }
      _twitarr = newConfiguration.createTwitarr();
      _twitarr.debugLatency = _debugLatency;
      _twitarr.debugReliability = _debugReliability;
      logout();
      _calendar.triggerUnscheduledUpdate();
      _announcements.reset();
      _announcements.triggerUnscheduledUpdate();
      notifyListeners();
    });
  }

  Progress<void> saveTwitarrConfiguration() {
    return store.saveSetting(Setting.server, '$twitarrConfiguration');
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
  ValueListenable<bool> get restoringSettings => _restoringSettings;
  final ValueNotifier<bool> _restoringSettings = ValueNotifier<bool>(false);
  void _restoreSettings() {
    _busy(() async {
      assert(!_restoringSettings.value);
      assert(_restoredSettings == null);
      _restoringSettings.value = true;
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
            selectTwitarrConfiguration(TwitarrConfiguration.from(settings[Setting.server] as String, const AutoTwitarrConfiguration()));
          if (settings.containsKey(Setting.debugTimeDilation)) {
            timeDilation = settings[Setting.debugTimeDilation] as double;
            await SchedulerBinding.instance.reassembleApplication();
          }
        }
        final Credentials credentials = await store.restoreCredentials().asFuture();
        if (credentials != null && _alive) {
          login(
            username: credentials.username,
            password: credentials.password,
          );
        }
      } finally {
        _restoringSettings.value = false;
        done.complete();
      }
    });
  }

  Seamail get seamail => _seamail;
  Seamail _seamail;

  Forums get forums => _forums;
  Forums _forums;

  TweetStream createTweetStream() {
    return TweetStream(
      _twitarr,
      _currentCredentials,
      photoManager: this,
      onError: (dynamic error, StackTrace stack) => onError('$error'),
    );
  }

  Progress<String> createAccount({
    @required String username,
    @required String password,
    @required String registrationCode,
    String displayName,
  }) {
    return Progress<String>((ProgressController<String> controller) async {
      logout();
      final Progress<AuthenticatedUser> userProgress = _twitarr.createAccount(
        username: username,
        password: password,
        registrationCode: registrationCode,
        displayName: displayName,
      );
      _user.addProgress(userProgress);
      final AuthenticatedUser user = await controller.chain<AuthenticatedUser>(userProgress);
      _updateCredentials(user);
      return _currentCredentials.username;
    });
  }

  Progress<void> login({
    @required String username,
    @required String password,
  }) {
    return Progress<void>((ProgressController<void> controller) async {
      logout();
      AuthenticatedUser user;
      do {
        try {
          final Progress<AuthenticatedUser> userProgress = _twitarr.login(
            username: username,
            password: password,
            photoManager: this,
          );
          _user.addProgress(userProgress);
          user = await controller.chain<AuthenticatedUser>(
            userProgress,
            steps: null,
          );
        } on InvalidUsernameOrPasswordError {
          rethrow;
        } on UserFriendlyError catch (error) {
          onError('$error');
          await Future<void>.delayed(const Duration(seconds: 3));
        }
      } while (user == null);
      _updateCredentials(user);
    });
  }

  void logout() {
    _updateCredentials(null);
  }

  void _updateCredentials(AuthenticatedUser user) {
    final Credentials oldCredentials = _currentCredentials;
    if (user == null) {
      _currentCredentials = null;
      _user.reset();
      _calendar.reset();
      _seamail = Seamail.empty();
      _forums = _createForums();
      if (_loggedIn.isCompleted)
        _loggedIn = Completer<void>();
    } else {
      assert(user.credentials.key != null);
      _currentCredentials = user.credentials;
      if (_currentCredentials != oldCredentials) {
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
        _forums = _createForums();
        _loggedIn.complete();
      }
    }
    if (_currentCredentials != oldCredentials) {
      _calendar.triggerUnscheduledUpdate();
      store.saveCredentials(_currentCredentials);
      notifyListeners();
    }
  }

  Forums _createForums() {
    return Forums(
      _twitarr,
      _currentCredentials,
      this,
      onError: onError,
    );
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

  Progress<User> fetchProfile(String username) {
    return _twitarr.getUser(_currentCredentials, username, this);
  }

  ContinuousProgress<Calendar> get calendar => _calendar;
  PeriodicProgress<Calendar> _calendar;

  Future<Calendar> _updateCalendar(ProgressController<Calendar> completer) async {
    return await completer.chain<Calendar>(_twitarr.getCalendar(credentials: _currentCredentials));
  }

  Progress<void> setEventFavorite({
    @required String eventId,
    @required bool favorite,
  }) {
    return Progress<void>((ProgressController<void> completer) async {
      try {
        await completer.chain(_twitarr.setEventFavorite(credentials: _currentCredentials, eventId: eventId, favorite: favorite), steps: 2);
        await completer.chain(_calendar.triggerUnscheduledUpdate(), steps: 2);
      } on UserFriendlyError catch (error) {
        onError('$error');
      }
    });
  }

  ContinuousProgress<List<Announcement>> get announcements => _announcements;
  PeriodicProgress<List<Announcement>> _announcements;

  Future<List<Announcement>> _updateAnnouncements(ProgressController<List<Announcement>> completer) async {
    final List<AnnouncementSummary> summary = await completer.chain<List<AnnouncementSummary>>(_twitarr.getAnnouncements());
    return summary.map<Announcement>((AnnouncementSummary summary) => summary.toAnnouncement(this)).toList();
  }

  Progress<ServerText> fetchServerText(String filename) {
    return _twitarr.fetchServerText(filename);
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
  Future<Uint8List> putImageIfAbsent(String photoId, ImageFetcher callback) {
    return _queuePhotosWork<Uint8List>(() {
      // TODO(ianh): cache the image obtained by callback to disk
      // TODO(ianh): return the cached version if we have one
      _storePhotos();
      return callback();
    });
  }

  @override
  Future<Uint8List> putUserPhotoIfAbsent(String username, ImageFetcher callback) {
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
  void addListenerForUserPhoto(String username, VoidCallback listener) {
    final Set<VoidCallback> callbacks = _photoListeners.putIfAbsent(username, () => Set<VoidCallback>());
    callbacks.add(listener);
  }

  @override
  void removeListenerForUserPhoto(String username, VoidCallback listener) {
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

  Widget avatarFor(Iterable<User> users, { double size: 40.0, int seed = 0 }) {
    assert(users.isNotEmpty);
    assert(seed != null);
    final math.Random random = math.Random(seed);
    final List<User> sortedUsers = users.toList()..shuffle(random);
    final List<Color> colors = sortedUsers.map<Color>((User user) => Color((user.username.hashCode | 0xFF111111) & 0xFF7F7F7F)).toList();
    final List<ImageProvider> images = sortedUsers.map<ImageProvider>((User user) => AvatarImage(user.username, this, _twitarr, onError: onError)).toList();
    return createAvatarWidgetsFor(sortedUsers, colors, images, size: size);
  }

  Widget imageFor(String photoId) {
    // TODO(ianh): long-press to download image
    final Widget image = Hero(
      tag: photoId,
      child: Image(
        image: TwitarrImage(photoId, this, _twitarr, onError: onError),
      ),
    );
    return VSyncBuilder(
      builder: (BuildContext context, TickerProvider vsync) {
        final MediaQueryData metrics = MediaQuery.of(context);
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            vsync: vsync,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: metrics.size.height - metrics.padding.vertical - (56.0 * 3.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push<void>(context, MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return Container(
                          color: Colors.black,
                          child: SafeArea(
                            child: Center(
                              child: image,
                            ),
                          ),
                        );
                      },
                    ));
                  },
                  child: image,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Progress<void> updateProfile({
    String displayName,
    String realName,
    String pronouns,
    String email,
    String homeLocation,
    String roomNumber,
  }) {
    return Progress<void>((ProgressController<void> completer) async {
      await completer.chain(_twitarr.updateProfile(
        credentials: _currentCredentials,
        displayName: displayName,
        realName: realName,
        pronouns: pronouns,
        email: email,
        homeLocation: homeLocation,
        roomNumber: roomNumber,
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
    @required String text,
    String parentId,
    @required Uint8List photo,
  }) {
    return _twitarr.postTweet(
      credentials: _currentCredentials,
      text: text,
      photo: photo,
      parentId: parentId,
    );
  }

  @override
  void dispose() {
    _alive = false;
    _user.dispose();
    _calendar.dispose();
    _announcements.dispose();
    _twitarr.dispose();
    super.dispose();
  }
}

class AvatarImage extends ImageProvider<AvatarImage> {
  const AvatarImage(this.username, this.photoManager, this.twitarr, { this.onError });

  final String username;

  final PhotoManager photoManager;

  final Twitarr twitarr;

  final ErrorCallback onError;

  @override
  Future<AvatarImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AvatarImage>(this);
  }

  @override
  ImageStreamCompleter load(AvatarImage key) {
    assert(key == this);
    return AvatarImageStreamCompleter(username, photoManager, twitarr, onError: onError);
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
  AvatarImageStreamCompleter(this.username, this.photoManager, this.twitarr, { this.onError }) {
    _update();
  }

  final String username;

  final PhotoManager photoManager;

  final Twitarr twitarr;

  final ErrorCallback onError;

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
        final Uint8List bytes = await photoManager.putUserPhotoIfAbsent(
          username,
          () => twitarr.fetchProfilePicture(username).asFuture(),
        );
        final ui.Codec codec = await PaintingBinding.instance.instantiateImageCodec(bytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        setImage(ImageInfo(image: frameInfo.image));
      } catch (error, stack) { // ignore: avoid_catches_without_on_clauses
        // it's ok to catch all errors here, as we're just rerouting them, not swallowing them
        if (error is UserFriendlyError && onError != null) {
          onError('$error');
        } else {
          reportError(exception: error, stack: stack);
        }
      }
    }
    _busy = false;
  }

  @override
  void addListener(ImageListener listener, { ImageErrorListener onError }) {
    if (!hasListeners)
      photoManager.addListenerForUserPhoto(username, _update);
    super.addListener(listener, onError: onError);
  }

  @override
  void removeListener(ImageListener listener) {
    super.removeListener(listener);
    if (!hasListeners)
      photoManager.removeListenerForUserPhoto(username, _update);
  }
}

class TwitarrImage extends ImageProvider<TwitarrImage> {
  const TwitarrImage(this.photoId, this.photoManager, this.twitarr, { this.onError });

  final String photoId;

  final PhotoManager photoManager;

  final Twitarr twitarr;

  final ErrorCallback onError;

  @override
  Future<TwitarrImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<TwitarrImage>(this);
  }

  @override
  ImageStreamCompleter load(TwitarrImage key) {
    assert(key == this);
    return TwitarrImageStreamCompleter(photoId, photoManager, twitarr, onError: onError);
  }

  @override
  String toString() => '$runtimeType($photoId)';

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    final TwitarrImage typedOther = other as TwitarrImage;
    return photoId == typedOther.photoId
        && photoManager == typedOther.photoManager
        && twitarr == typedOther.twitarr;
  }

  @override
  int get hashCode => hashValues(
    photoId,
    photoManager,
    twitarr,
  );
}

class TwitarrImageStreamCompleter extends ImageStreamCompleter {
  TwitarrImageStreamCompleter(this.photoId, this.photoManager, this.twitarr, { this.onError }) {
    _update();
  }

  final String photoId;

  final PhotoManager photoManager;

  final Twitarr twitarr;

  final ErrorCallback onError;

  Future<void> _update() async {
    try {
      final Uint8List bytes = await photoManager.putImageIfAbsent(
        photoId,
        () => twitarr.fetchImage(photoId).asFuture(),
      );
      final ui.Codec codec = await PaintingBinding.instance.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      setImage(ImageInfo(image: frameInfo.image));
    } catch (error, stack) { // ignore: avoid_catches_without_on_clauses
      // it's ok to catch all errors here, as we're just rerouting them, not swallowing them
      if (error is UserFriendlyError && onError != null) {
        onError('$error');
      } else {
        reportError(exception: error, stack: stack);
      }
    }
  }
}
