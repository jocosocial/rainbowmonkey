import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../basic_types.dart';
import '../models/user.dart';
import '../network/twitarr.dart';
import '../progress.dart';
import '../utils.dart';
import 'photo_manager.dart';

typedef ThreadReadCallback = void Function(String threadId);

class Forums extends ChangeNotifier with IterableMixin<ForumThread>, BusyMixin {
  Forums(
    this._twitarr,
    this._credentials, {
    @required this.photoManager,
    this.maxUpdatePeriod = const Duration(minutes: 10),
    @required this.onError,
  }) : assert(onError != null),
       assert(_twitarr != null),
       assert(photoManager != null) {
    _timer = VariableTimer(maxUpdatePeriod, update);
  }

  Forums.empty(
  ) : _twitarr = null,
      _credentials = null,
      photoManager = null,
      maxUpdatePeriod = null,
      onError = null;

  final Twitarr _twitarr;
  final Credentials _credentials;

  final PhotoManager photoManager;
  final Duration maxUpdatePeriod;
  final ErrorCallback onError;

  @override
  Iterator<ForumThread> get iterator => _threads.values.iterator;

  final Map<String, ForumThread> _threads = <String, ForumThread>{};

  VariableTimer _timer;

  ValueListenable<bool> get active => _timer.active;

  void reload() {
    _timer.reload();
  }

  ForumThread getThreadById(String id) {
    return _threads[id];
  }

  bool _updating = false;
  @protected
  Future<void> update() async {
    if (_updating)
      return;
    startBusy();
    _updating = true;
    try {
      final Set<ForumSummary> newThreads = await _twitarr.getForumThreads(
        credentials: _credentials,
      ).asFuture();
      final Set<ForumThread> removedThreads = Set<ForumThread>.from(_threads.values);
      for (ForumSummary threadSummary in newThreads) {
        if (_threads.containsKey(threadSummary.id)) {
          final ForumThread thread = _threads[threadSummary.id];
          thread.updateFrom(threadSummary);
          removedThreads.remove(thread);
        } else {
          _threads[threadSummary.id] = ForumThread.from(threadSummary, this, _twitarr, _credentials, photoManager);
        }
      }
      removedThreads.forEach(_threads.remove);
    } on UserFriendlyError catch (error) {
      _timer.interested(wasError: true);
      _reportError(error);
    } finally {
      _updating = false;
      endBusy();
    }
    notifyListeners();
  }

  Progress<ForumThread> postThread({
    @required String subject,
    @required String text,
    @required List<Uint8List> photos,
  }) {
    if (_credentials == null)
      throw const LocalError('Cannot create a thread when not logged in.');
    return Progress<ForumThread>((ProgressController<ForumThread> completer) async {
      final ForumSummary thread = await completer.chain<ForumSummary>(
        _twitarr.createForumThread(
          credentials: _credentials,
          subject: subject,
          text: text,
          photos: photos,
        ),
      );
      _timer.interested();
      if (!_threads.containsKey(thread.id)) {
        _threads[thread.id] = ForumThread.from(thread, this, _twitarr, _credentials, photoManager);
        notifyListeners();
      }
      return _threads[thread.id];
    });
  }

  void _childUpdated(ForumThread thread) {
    notifyListeners();
  }

  void _reportError(UserFriendlyError error) {
    onError(error.toString());
  }

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners && maxUpdatePeriod != null)
      _timer.start();
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners && maxUpdatePeriod != null)
      _timer.stop();
  }
}

class ForumThread extends ChangeNotifier with BusyMixin, IterableMixin<ForumMessage> {
  ForumThread(
    this.id,
    this._parent,
    this._twitarr,
    this._credentials,
    this._photoManager, {
    this.maxUpdatePeriod = const Duration(minutes: 1),
  }) {
    _init();
  }

  ForumThread.from(
    ForumSummary thread,
    this._parent,
    this._twitarr,
    this._credentials,
    this._photoManager, {
    this.maxUpdatePeriod = const Duration(minutes: 1),
  }) : id = thread.id {
    _init();
    updateFrom(thread);
  }

  final Forums _parent;
  final Twitarr _twitarr;
  final Credentials _credentials;
  final PhotoManager _photoManager;

  final Duration maxUpdatePeriod;

  final String id;

  String get subject => _subject ?? '';
  String _subject;

  bool get sticky => _sticky ?? false;
  bool _sticky;

  bool get locked => _locked ?? false;
  bool _locked;

  bool get hasUnread => unreadCount > 0;

  int get unreadCount => _unreadCount ?? 0;
  int _unreadCount;

  int get totalCount => math.max(_totalCount ?? 0, _messages.length);
  int _totalCount;

  User get lastMessageUser => _lastMessageUser;
  User _lastMessageUser;

  DateTime get lastMessageTimestamp => _lastMessageTimestamp;
  DateTime _lastMessageTimestamp;

  @override
  Iterator<ForumMessage> get iterator => _messages.iterator;

  List<ForumMessage> _messages = <ForumMessage>[];

  bool _updating = false;
  @protected
  Future<void> update() async {
    if (_updating)
      return;
    startBusy();
    _updating = true;
    try {
      updateFrom(await _twitarr.getForumThread(
        credentials: _credentials,
        threadId: id,
      ).asFuture());
    } on UserFriendlyError catch (error) {
      _timer.interested(wasError: true);
      _parent._reportError(error);
    } finally {
      _updating = false;
      endBusy();
    }
    _parent._childUpdated(this);
    notifyListeners();
  }

  @protected
  void updateFrom(ForumSummary thread) {
    _subject = thread.subject;
    _sticky = thread.sticky;
    _locked = thread.locked;
    _totalCount = thread.totalCount;
    _unreadCount = thread.unreadCount;
    _lastMessageUser = thread.lastMessageUser.toUser(_photoManager);
    _lastMessageTimestamp = thread.lastMessageTimestamp;
    if (thread.messages != null)
      _messages = thread.messages.map<ForumMessage>((ForumMessageSummary summary) => ForumMessage.from(summary, _photoManager)).toList();
    _parent._childUpdated(this);
    notifyListeners();
  }

  Progress<void> send(String text, { @required List<Uint8List> photos }) {
    if (_credentials == null)
      throw const LocalError('Cannot create a thread when not logged in.');
    return Progress<void>((ProgressController<void> completer) async {
      await completer.chain<void>(
        _twitarr.postForumMessage(
          credentials: _credentials,
          threadId: id,
          text: text,
          photos: photos,
        ),
      );
      await update();
      _timer.interested();
      _parent._childUpdated(this);
    });
  }

  VariableTimer _timer;

  ValueListenable<bool> get active => _timer.active;

  void reload() {
    _timer.reload();
  }

  void _init() {
    _timer = VariableTimer(maxUpdatePeriod, update);
  }

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners && maxUpdatePeriod != null)
      _timer.start();
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners && maxUpdatePeriod != null)
      _timer.stop();
  }
}

class ForumMessage {
  const ForumMessage({
    this.id,
    this.user,
    this.text,
    this.photos,
    this.timestamp,
    this.read,
  });

  ForumMessage.from(
    ForumMessageSummary message,
    PhotoManager photoManager,
  ) : id = message.id,
      user = message.user.toUser(photoManager),
      text = message.text,
      photos = message.photos,
      timestamp = message.timestamp,
      read = message.read;

  final String id;

  final User user;

  final String text;

  final List<Photo> photos;

  final DateTime timestamp;

  final bool read; // this can be null
}
