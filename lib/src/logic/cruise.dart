import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show Codec, FrameInfo;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';
import 'package:pedantic/pedantic.dart' show unawaited;

import '../models/calendar.dart';
import '../models/errors.dart';
import '../models/search.dart';
import '../models/server_status.dart';
import '../models/server_text.dart';
import '../models/user.dart';
import '../network/rest.dart' show AutoTwitarrConfiguration;
import '../network/twitarr.dart';
import '../progress.dart';
import '../widgets.dart';
import 'forums.dart';
import 'mentions.dart';
import 'notifications.dart';
import 'photo_manager.dart';
import 'seamail.dart';
import 'store.dart';
import 'stream.dart';

// TODO(ianh): Move polling logic into RestTwitarr class

typedef CheckForMessagesCallback = void Function(Credentials credentials, Twitarr twitarr, DataStore store, { bool forced });

class CruiseModel extends ChangeNotifier with WidgetsBindingObserver implements PhotoManager {
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
    WidgetsBinding.instance.addObserver(this);
    didChangeAppLifecycleState(SchedulerBinding.instance.lifecycleState);
    _user = PeriodicProgress<AuthenticatedUser>(steadyPollInterval, _updateUser);
    _calendar = PeriodicProgress<Calendar>(steadyPollInterval, _updateCalendar);
    _serverStatus = PeriodicProgress<ServerStatus>(steadyPollInterval, _updateServerStatus);
    _busy(() async {
      selectTwitarrConfiguration(initialTwitarrConfiguration); // sync
      _seamail = Seamail.empty();
      _mentions = Mentions.empty(this);
      _forums = _createForums();
      _tweetStream = _createTweetStream();
      _restoreSettings(); // async
      unawaited(_restorePhotos()); // async
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
      _serverStatus.pause();
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
        _serverStatus.resume();
        if (_preBusyCredentials != null && _preBusyCredentials != _currentCredentials)
          await Notifications.instance.then<void>((Notifications notifications) => notifications.cancelAll());
      }
    }
  }

  void _handleError(UserFriendlyError error) {
    if (onError != null)
      onError(error);
    if (error is FeatureDisabledError)
      _serverStatus.triggerUnscheduledUpdate();
  }

  bool _onscreen = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    bool newState;
    switch (state) {
      case AppLifecycleState.inactive:
        newState = true;
        break;
      case AppLifecycleState.detached:
        newState = false;
        break;
      case AppLifecycleState.resumed:
        newState = true;
        break;
      case AppLifecycleState.paused:
        newState = false;
        break;
      default:
        newState = true; // app probably just started
    }
    if (newState != _onscreen) {
      _onscreen = newState;
      if (_onscreen) {
        _twitarr?.enable(serverStatus?.currentValue ?? const ServerStatus());
      } else {
        _twitarr?.disable();
      }
    }
  }

  Twitarr _twitarr;
  TwitarrConfiguration get twitarrConfiguration => _twitarr.configuration;
  void selectTwitarrConfiguration(TwitarrConfiguration newConfiguration) {
    _busy(() async {
      if (_twitarr != null) {
        if (newConfiguration == _twitarr.configuration)
          return;
        _twitarr.dispose();
      }
      _twitarr = newConfiguration.createTwitarr();
      assert(() {
        _twitarr.debugLatency = _debugLatency;
        _twitarr.debugReliability = _debugReliability;
        return true;
      }());
      if (!_onscreen)
        _twitarr.disable();
      _calendar.reset();
      _serverStatus.reset();
      logout(); // may also reset the calendar
      _calendar.triggerUnscheduledUpdate();
      _serverStatus.triggerUnscheduledUpdate();
      notifyListeners();
    });
  }

  Progress<void> saveTwitarrConfiguration() {
    return store.saveSetting(Setting.server, '$twitarrConfiguration');
  }

  double get debugLatency => _debugLatency;
  double _debugLatency = 0.0;
  set debugLatency(double value) {
    _debugLatency = value;
    _twitarr?.debugLatency = value;
    store.saveSetting(Setting.debugNetworkLatency, value);
    notifyListeners();
  }

  double get debugReliability => _debugReliability;
  double _debugReliability = 1.0;
  set debugReliability(double value) {
    _debugReliability = value;
    _twitarr?.debugReliability = value;
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
          assert(() {
            if (settings.containsKey(Setting.debugNetworkLatency))
              debugLatency = settings[Setting.debugNetworkLatency] as double;
            if (settings.containsKey(Setting.debugNetworkReliability))
              debugReliability = settings[Setting.debugNetworkReliability] as double;
            return true;
          }());
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
      _updateCredentials(await controller.chain<AuthenticatedUser>(userProgress));
      return _currentCredentials.username;
    });
  }

  bool _asMod = false;

  Credentials _lastAttemptedCredentials;

  Progress<void> login({
    @required String username,
    @required String password,
  }) {
    _lastAttemptedCredentials = Credentials(
      username: username,
      password: password,
    );
    return Progress<void>((ProgressController<void> controller) async {
      logout();
      try {
        final Progress<AuthenticatedUser> userProgress = _twitarr.login(
          username: username,
          password: password,
          photoManager: this,
        );
        _user.addProgress(userProgress);
        _updateCredentials(await controller.chain<AuthenticatedUser>(userProgress));
      } on InvalidUsernameOrPasswordError {
        rethrow;
      } on UserFriendlyError catch (error) {
        _handleError(error);
      }
    });
  }

  void retryUserLogin() {
    assert(_lastAttemptedCredentials != null);
    login(
      username: _lastAttemptedCredentials.username,
      password: _lastAttemptedCredentials.password,
    );
  }

  Progress<void> resetPassword({
    @required String username,
    @required String registrationCode,
    @required String password,
  }) {
    _lastAttemptedCredentials = Credentials(
      username: username,
      password: password,
    );
    return Progress<void>((ProgressController<void> controller) async {
      logout();
      try {
        final Progress<AuthenticatedUser> userProgress = _twitarr.resetPassword(
          username: username,
          registrationCode: registrationCode,
          password: password,
          photoManager: this,
        );
        _user.addProgress(userProgress);
        _updateCredentials(await controller.chain<AuthenticatedUser>(userProgress));
      } on InvalidUsernameOrPasswordError {
        rethrow;
      } on UserFriendlyError catch (error) {
        _handleError(error);
      }
    });
  }

  Progress<void> changePassword(String newPassword) {
    return Progress<void>((ProgressController<void> controller) async {
      try {
        final Progress<AuthenticatedUser> userProgress = _twitarr.changePassword(
          credentials: _currentCredentials,
          newPassword: newPassword,
          photoManager: this,
        );
        _user.addProgress(userProgress);
        _updateCredentials(await controller.chain<AuthenticatedUser>(userProgress));
        _lastAttemptedCredentials = Credentials(
          username: _currentCredentials.username,
          password: newPassword,
        );
      } on InvalidUsernameOrPasswordError {
        rethrow;
      } on UserFriendlyError catch (error) {
        _handleError(error);
      }
    });
  }

  void logout() {
    _asMod = false;
    // no need to do anything to _user, the following call resets it:
    _updateCredentials(null);
  }

  void setAsMod({ @required bool enabled }) {
    assert(enabled != null);
    AuthenticatedUser user = _user.currentValue;
    assert(user != null);
    _asMod = enabled;
    user = user.copyWith(credentials: user.credentials.copyWith(asMod: _asMod));
    _user.addProgress(Progress<AuthenticatedUser>.completed(user));
    _updateCredentials(user);
  }

  void _updateCredentials(AuthenticatedUser user) {
    final Credentials oldCredentials = _currentCredentials;
    if (user == null) {
      _currentCredentials = null;
      _user.reset();
      if (_currentCredentials != oldCredentials)
        _calendar.reset();
      _seamail = Seamail.empty();
      _mentions = Mentions.empty(this);
      _forums = _createForums();
      _tweetStream = _createTweetStream();
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
          onError: _handleError,
          onCheckForMessages: () {
            if (onCheckForMessages != null)
              onCheckForMessages(_currentCredentials, _twitarr, store, forced: true);
          },
          onThreadRead: _handleThreadRead,
        );
        _mentions = Mentions(
          this,
          _twitarr,
          _currentCredentials,
          this,
          onError: _handleError,
        );
        _forums = _createForums();
        _tweetStream = _createTweetStream();
        if (!_loggedIn.isCompleted)
          _loggedIn.complete();
      }
    }
    final Role newRole = user != null ? user.role : Role.none;
    final ServerStatus status = serverStatus.currentValue;
    if (status != null && newRole != status.userRole) {
      final ServerStatus newStatus = status.copyWith(userRole: newRole);
      _serverStatus.addProgress(Progress<ServerStatus>.completed(newStatus));
      if (_onscreen)
        _twitarr.enable(newStatus);
    }
    if (_currentCredentials != oldCredentials)
      _calendar.triggerUnscheduledUpdate();
    if (_currentCredentials != oldCredentials) {
      store.saveCredentials(_currentCredentials);
      notifyListeners();
    }
  }

  ContinuousProgress<AuthenticatedUser> get user => _user;
  PeriodicProgress<AuthenticatedUser> _user;

  bool get isLoggedIn => _currentCredentials != null;
  Future<void> get loggedIn => _loggedIn.future;
  Completer<void> _loggedIn = Completer<void>();

  Future<AuthenticatedUser> _updateUser(ProgressController<AuthenticatedUser> completer) async {
    await _restoredSettings;
    AuthenticatedUser result;
    if (_currentCredentials?.key != null) {
      result = await completer.chain<AuthenticatedUser>(_twitarr.getAuthenticatedUser(_currentCredentials, this));
      if (_asMod)
        result = result.copyWith(credentials: result.credentials.copyWith(asMod: true));
    }
    return result;
  }

  Progress<User> fetchProfile(String username) {
    return _twitarr.getUser(_currentCredentials, username, this);
  }

  ContinuousProgress<ServerStatus> get serverStatus => _serverStatus;
  PeriodicProgress<ServerStatus> _serverStatus;

  Future<ServerStatus> _updateServerStatus(ProgressController<ServerStatus> completer) async {
    final List<Announcement> announcements = (await completer.chain<List<AnnouncementSummary>>(_twitarr.getAnnouncements()))
      .map<Announcement>((AnnouncementSummary summary) => summary.toAnnouncement(this))
      .toList()
      ..sort();
    final Map<String, bool> sections = await completer.chain<Map<String, bool>>(_twitarr.getSectionStatus());
    final ServerStatus result = ServerStatus(
      announcements: announcements,
      userRole: user.currentValue?.role ?? Role.none,
      forumsEnabled: sections['forums'] ?? true,
      streamEnabled: sections['stream'] ?? true,
      seamailEnabled: sections['seamail'] ?? true,
      calendarEnabled: sections['calendar'] ?? true,
      deckPlansEnabled: sections['deck_plans'] ?? true,
      gamesEnabled: sections['games'] ?? true,
      karaokeEnabled: sections['karaoke'] ?? true,
      registrationEnabled: sections['registration'] ?? true,
      userProfileEnabled: sections['user_profile'] ?? true,
    );
    if (_onscreen)
      _twitarr.enable(result);
    return result;
  }

  Progress<ServerText> fetchServerText(String filename) {
    return _twitarr.fetchServerText(filename);
  }

  Seamail get seamail => _seamail;
  Seamail _seamail;

  Mentions get mentions => _mentions;
  Mentions _mentions;

  Forums get forums => _forums;
  Forums _forums;

  TweetStream get tweetStream => _tweetStream;
  TweetStream _tweetStream;

  Forums _createForums() {
    return Forums(
      _twitarr,
      _currentCredentials,
      photoManager: this,
      onError: _handleError,
    );
  }

  TweetStream _createTweetStream() {
    return TweetStream(
      _twitarr,
      _currentCredentials,
      photoManager: this,
      onError: _handleError,
    );
  }

  void _handleThreadRead(String threadId) async {
    final Notifications notifications = await Notifications.instance;
    for (String messageId in await store.getNotifications(threadId)) {
      await notifications.messageRead(threadId, messageId);
      await store.removeNotification(threadId, messageId);
    }
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
        _handleError(error);
      }
    });
  }

  Map<String, DateTime> _photoUpdates = <String, DateTime>{};
  final Map<String, Set<VoidCallback>> _photoListeners = <String, Set<VoidCallback>>{};

  Future<void> _restorePhotos() async {
    _photoUpdates = await store.restoreUserPhotoList();
  }

  @override
  Future<Uint8List> putImageIfAbsent(String photoId, ImageFetcher callback, { @required bool thumbnail }) {
    assert(thumbnail != null);
    return store.putImageIfAbsent(_twitarr.photoCacheKey, thumbnail ? 'thumbnail' : 'image', photoId, callback);
  }

  @override
  Future<Uint8List> putUserPhotoIfAbsent(String username, ImageFetcher callback) {
    return store.putImageIfAbsent(_twitarr.photoCacheKey, 'avatar', username, callback);
  }

  @override
  void heardAboutUserPhoto(String username, DateTime lastUpdate) async {
    if (!_photoUpdates.containsKey(username) || _photoUpdates[username].isBefore(lastUpdate)) {
      await _resetUserPhoto(username); // this calls _notifyUserPhotoListeners for us
      _photoUpdates[username] = lastUpdate;
      await store.heardAboutUserPhoto(username, lastUpdate);
    }
  }

  Future<void> _resetUserPhoto(String username) async {
    await store.removeImage(_twitarr.photoCacheKey, 'avatar', username);
    _photoUpdates.remove(username);
    _notifyUserPhotoListeners(username);
  }

  @override
  void addListenerForUserPhoto(String username, VoidCallback listener) {
    final Set<VoidCallback> callbacks = _photoListeners.putIfAbsent(username, () => <VoidCallback>{});
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

  Widget avatarFor(Iterable<User> users, { double size, int seed = 0, bool enabled = true }) {
    assert(users.isNotEmpty);
    assert(seed != null);
    final math.Random random = math.Random(seed);
    final List<User> sortedUsers = users.toList()..shuffle(random);
    final List<Color> colors = sortedUsers.map<Color>((User user) => Color((user.username.hashCode | 0xFF111111) & 0xFF7F7F7F)).toList();
    final List<ImageProvider> images = sortedUsers.map<ImageProvider>((User user) => AvatarImage(user.username, this, _twitarr, onError: _handleError)).toList();
    return createAvatarWidgetsFor(sortedUsers, colors, images, size: size, enabled: enabled);
  }

  ImageProvider imageFor(Photo photo, { bool thumbnail = false }) {
    return TwitarrImage(photo, this, _twitarr, onError: _handleError, thumbnail: thumbnail);
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
      await _resetUserPhoto(_currentCredentials.username);
    });
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

  Progress<Set<SearchResult>> search(String query) {
    return Progress.convert<Set<SearchResultSummary>, Set<SearchResult>>(
      _twitarr.search(searchTerm: query, credentials: _currentCredentials),
      (Set<SearchResultSummary> results) {
        return results.map<SearchResult>((SearchResultSummary item) {
          if (item is UserSummary)
            return item.toUser(this);
          if (item is EventSummary)
            return item;
          if (item is ForumSummary)
            return forums.obtainForum(item);
          if (item is SeamailThreadSummary)
            return seamail.threadBySummary(item);
          if (item is StreamMessageSummary)
            return StreamPost.from(item, this);
          assert(false);
          return null;
       }).where((SearchResult result) => result != null).toSet();
      },
    );
  }

  final SearchQueryNotifier searchQueryNotifier = SearchQueryNotifier();
  void pushSearchQuery(String value) => searchQueryNotifier._pushQuery(value);

  void forceUpdate() {
    _calendar.triggerUnscheduledUpdate();
    _serverStatus.triggerUnscheduledUpdate();
  }

  @override
  void dispose() {
    _alive = false;
    _user.dispose();
    _calendar.dispose();
    _serverStatus.dispose();
    _twitarr.dispose();
    WidgetsBinding.instance.removeObserver(this);
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
  ImageStreamCompleter load(AvatarImage key, DecoderCallback decode) {
    assert(key == this);
    return AvatarImageStreamCompleter(username, photoManager, twitarr, decode, onError: onError);
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
  AvatarImageStreamCompleter(this.username, this.photoManager, this.twitarr, this.decode, { this.onError }) {
    _update();
  }

  final String username;

  final PhotoManager photoManager;

  final Twitarr twitarr;

  final DecoderCallback decode;

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
        final ui.Codec codec = await decode(bytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        setImage(ImageInfo(image: frameInfo.image));
      } catch (error, stack) { // ignore: avoid_catches_without_on_clauses
        // it's ok to catch all errors here, as we're just rerouting them, not swallowing them
        if (error is UserFriendlyError && onError != null) {
          onError(error);
        } else {
          reportError(exception: error, stack: stack);
        }
      }
    }
    _busy = false;
  }

  @override
  void addListener(ImageStreamListener listener) {
    if (!hasListeners)
      photoManager.addListenerForUserPhoto(username, _update);
    super.addListener(listener);
  }

  @override
  void removeListener(ImageStreamListener listener) {
    super.removeListener(listener);
    if (!hasListeners)
      photoManager.removeListenerForUserPhoto(username, _update);
  }
}

class TwitarrImage extends ImageProvider<TwitarrImage> {
  const TwitarrImage(this.photo, this.photoManager, this.twitarr, { this.onError, this.thumbnail });

  final Photo photo;

  final PhotoManager photoManager;

  final Twitarr twitarr;

  final ErrorCallback onError;

  final bool thumbnail;

  @override
  Future<TwitarrImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<TwitarrImage>(this);
  }

  @override
  ImageStreamCompleter load(TwitarrImage key, DecoderCallback decode) {
    assert(key == this);
    return TwitarrImageStreamCompleter(photo.id, photoManager, twitarr, decode, onError: onError, thumbnail: thumbnail);
  }

  @override
  String toString() => '$runtimeType($photo)';

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    final TwitarrImage typedOther = other as TwitarrImage;
    return photo.id == typedOther.photo.id
        && thumbnail == typedOther.thumbnail
        && twitarr == typedOther.twitarr;
  }

  @override
  int get hashCode => hashValues(
    photo.id,
    thumbnail,
    twitarr,
  );
}

class TwitarrImageStreamCompleter extends ImageStreamCompleter {
  TwitarrImageStreamCompleter(this.photoId, this.photoManager, this.twitarr, this.decode, {
    this.onError,
    @required this.thumbnail,
  }) : assert(thumbnail != null) {
    _update();
  }

  final String photoId;

  final PhotoManager photoManager;

  final Twitarr twitarr;

  final DecoderCallback decode;

  final ErrorCallback onError;

  final bool thumbnail;

  Future<void> _update() async {
    try {
      final Uint8List bytes = await photoManager.putImageIfAbsent(
        photoId,
        () => twitarr.fetchImage(photoId, thumbnail: thumbnail).asFuture(),
        thumbnail: thumbnail,
      );
      final ui.Codec codec = await decode(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      setImage(ImageInfo(image: frameInfo.image));
    } catch (error, stack) { // ignore: avoid_catches_without_on_clauses
      // it's ok to catch all errors here, as we're just rerouting them, not swallowing them
      if (error is UserFriendlyError && onError != null) {
        onError(error);
      } else {
        reportError(exception: error, stack: stack);
      }
    }
  }
}

class SearchQueryNotifier extends ChangeNotifier {
  SearchQueryNotifier();

  String _query;

  String pullQuery({ bool tentative = false }) {
    assert(_query != null || tentative);
    final String result = _query;
    _query = null;
    return result;
  }

  void _pushQuery(String value) {
    assert(_query == null);
    _query = value;
    notifyListeners();
  }
}