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
    this._credentials,
    this._photoManager, {
    this.maxUpdatePeriod = const Duration(minutes: 10),
    @required this.onError,
  }) : assert(onError != null),
       assert(_twitarr != null),
       assert(_credentials != null),
       assert(_photoManager != null);

  Forums.empty(
  ) : _twitarr = null,
      _credentials = null,
      _photoManager = null,
      maxUpdatePeriod = null,
      onError = null;

  final Twitarr _twitarr;
  final Credentials _credentials;
  final PhotoManager _photoManager;

  final Duration maxUpdatePeriod;
  final ErrorCallback onError;

  @override
  Iterator<ForumThread> get iterator => _threads.values.iterator;

  final Map<String, ForumThread> _threads = <String, ForumThread>{};

  bool _updating = false;
  @protected
  Future<void> update() async {
    if (_updating || _credentials == null)
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
          if (thread.updateFrom(threadSummary))
            _timer?.interested();
          removedThreads.remove(thread);
        } else {
          _threads[threadSummary.id] = ForumThread.from(threadSummary, this, _twitarr, _credentials, _photoManager);
        }
      }
      removedThreads.forEach(_threads.remove);
    } on UserFriendlyError catch (error) {
      _timer?.interested();
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
      _timer?.interested();
      if (!_threads.containsKey(thread.id)) {
        _threads[thread.id] = ForumThread.from(thread, this, _twitarr, _credentials, _photoManager);
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

  VariableTimer _timer;

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners && maxUpdatePeriod != null)
      _timer = VariableTimer(maxUpdatePeriod, update);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners && maxUpdatePeriod != null) {
      _timer.cancel();
      _timer = null;
    }
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
  });

  ForumThread.from(
    ForumSummary thread,
    this._parent,
    this._twitarr,
    this._credentials,
    this._photoManager, {
    this.maxUpdatePeriod = const Duration(minutes: 1),
  }) : id = thread.id {
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
      final List<ForumMessageSummary> messages = await _twitarr.getForumMessages(
        credentials: _credentials,
        threadId: id,
      ).asFuture();
      _messages = messages.map<ForumMessage>((ForumMessageSummary summary) => ForumMessage.from(summary, _photoManager)).toList();
    } on UserFriendlyError catch (error) {
      _timer?.interested();
      _parent._reportError(error);
    } finally {
      _updating = false;
      endBusy();
    }
    _parent._childUpdated(this);
    notifyListeners();
  }

  // Returns if something interesting was in the update.
  // implying we should check again soon
  @protected
  bool updateFrom(ForumSummary thread) {
    final bool interesting = _totalCount != thread.totalCount || _unreadCount != thread.unreadCount;
    _subject = thread.subject;
    _totalCount = thread.totalCount;
    _unreadCount = thread.unreadCount;
    _lastMessageUser = thread.lastMessageUser.toUser(_photoManager);
    _lastMessageTimestamp = thread.lastMessageTimestamp;
    _parent._childUpdated(this);
    notifyListeners();
    if (interesting)
      _timer?.interested();
    return interesting;
  }

  Progress<void> send(String text, { @required List<Uint8List> photos }) {
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
      _timer?.interested();
      _parent._childUpdated(this);
    });
  }

  VariableTimer _timer;

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners && maxUpdatePeriod != null)
      _timer = VariableTimer(maxUpdatePeriod, update);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners && maxUpdatePeriod != null) {
      _timer.cancel();
      _timer = null;
    }
  }
}

class ForumMessage {
  const ForumMessage({
    this.id,
    this.user,
    this.text,
    this.photoIds,
    this.timestamp,
    this.read,
  });

  ForumMessage.from(
    ForumMessageSummary message,
    PhotoManager photoManager,
  ) : id = message.id,
      user = message.user.toUser(photoManager),
      text = message.text,
      photoIds = message.photoIds,
      timestamp = message.timestamp,
      read = message.read;

  final String id;

  final User user;

  final String text;

  final List<String> photoIds;

  final DateTime timestamp;

  final bool read;
}
