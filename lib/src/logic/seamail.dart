import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../basic_types.dart';
import '../models/user.dart';
import '../network/twitarr.dart';
import '../progress.dart';
import '../utils.dart';
import 'photo_manager.dart';

typedef ThreadReadCallback = void Function(String threadId);

class Seamail extends ChangeNotifier with IterableMixin<SeamailThread>, BusyMixin {
  Seamail(
    this._twitarr,
    this._credentials,
    this._photoManager, {
    this.maxUpdatePeriod = const Duration(minutes: 1),
    @required this.onError,
    this.onCheckForMessages,
    @required this.onThreadRead,
  }) : assert(onError != null),
       assert(_twitarr != null),
       assert(_credentials != null),
       assert(_photoManager != null) {
    _timer = VariableTimer(maxUpdatePeriod, update);
  }

  Seamail.empty(
  ) : _twitarr = null,
      _credentials = null,
      _photoManager = null,
      maxUpdatePeriod = null,
      onError = null,
      onCheckForMessages = null,
      onThreadRead = null;

  final Twitarr _twitarr;
  final Credentials _credentials;
  final PhotoManager _photoManager;

  final Duration maxUpdatePeriod;
  final ErrorCallback onError;

  /// Called when there might be new messages to report as notifications.
  final VoidCallback onCheckForMessages;

  /// Called when a SeamailThread is subscribed to and tells the server to
  /// mark everything as read.
  final ThreadReadCallback onThreadRead;

  static String kSeamailLoop = 'seamail-loop';

  @override
  Iterator<SeamailThread> get iterator => _threads.values.iterator;

  final Map<String, SeamailThread> _threads = <String, SeamailThread>{};

  SeamailThread threadById(String threadId) {
    return _threads.putIfAbsent(threadId, () => SeamailThread(
      threadId,
      this,
      _twitarr,
      _credentials,
      _photoManager,
      onThreadRead: onThreadRead,
    ));
  }

  int get unreadCount {
    int result = 0;
    for (SeamailThread thread in _threads.values)
      result += thread.unreadCount;
    return result;
  }

  void addThread(SeamailThread thread) {
    assert(_credentials != null);
    _threads[thread.id] = thread;
  }

  int _freshnessToken;

  bool _updating = false;
  @protected
  Future<void> update() async {
    if (_updating || _credentials == null)
      return;
    startBusy();
    _updating = true;
    try {
      final SeamailSummary summary = await _twitarr.getSeamailThreads(
        credentials: _credentials,
        freshnessToken: _freshnessToken,
      ).asFuture();
      bool hasNewUnread = false;
      for (SeamailThreadSummary thread in summary.threads) {
        if (thread.messages.isNotEmpty)
          hasNewUnread = true;
        if (_threads.containsKey(thread.id)) {
          if (_threads[thread.id].updateFrom(thread))
            _timer.interested();
        } else {
          _threads[thread.id] = SeamailThread.from(thread, this, _twitarr, _credentials, _photoManager, onThreadRead: onThreadRead);
          _timer.interested();
        }
      }
      if (onCheckForMessages != null && hasNewUnread)
        onCheckForMessages();
      _freshnessToken = summary.freshnessToken;
    } on UserFriendlyError catch (error) {
      _timer.interested();
      _reportError(error);
    } finally {
      _updating = false;
      endBusy();
    }
    notifyListeners();
  }

  Progress<SeamailThread> postThread({
    @required Set<User> users,
    @required String subject,
    @required String text,
  }) {
    if (_credentials == null)
      throw const LocalError('Cannot create a thread when not logged in.');
    return Progress<SeamailThread>((ProgressController<SeamailThread> completer) async {
      final SeamailThreadSummary thread = await completer.chain<SeamailThreadSummary>(
        _twitarr.createSeamailThread(
          credentials: _credentials,
          users: users,
          subject: subject,
          text: text,
        ),
      );
      _timer.interested();
      if (!_threads.containsKey(thread.id)) {
        _threads[thread.id] = SeamailThread.from(thread, this, _twitarr, _credentials, _photoManager, onThreadRead: onThreadRead);
        notifyListeners();
      }
      return _threads[thread.id];
    });
  }

  void _childUpdated(SeamailThread thread) {
    notifyListeners();
  }

  void _reportError(UserFriendlyError error) {
    onError(error.toString());
  }

  VariableTimer _timer;

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

class SeamailThread extends ChangeNotifier with BusyMixin {
  SeamailThread(
    this.id,
    this._parent,
    this._twitarr,
    this._credentials,
    this._photoManager, {
    this.maxUpdatePeriod = const Duration(minutes: 1),
    @required this.onThreadRead,
  }) {
    _init();
  }

  SeamailThread.from(
    SeamailThreadSummary thread,
    this._parent,
    this._twitarr,
    this._credentials,
    this._photoManager, {
    this.maxUpdatePeriod = const Duration(minutes: 1),
    @required this.onThreadRead,
  }) : id = thread.id {
    _init();
    updateFrom(thread);
  }

  final Seamail _parent;
  final Twitarr _twitarr;
  final Credentials _credentials;
  final PhotoManager _photoManager;

  final Duration maxUpdatePeriod;
  final ThreadReadCallback onThreadRead;

  final String id;

  String get subject => _subject ?? '';
  String _subject;

  Iterable<User> get users => _users ?? const <User>[];
  List<User> _users;

  DateTime get lastMessageTimestamp => _lastMessageTimestamp;
  DateTime _lastMessageTimestamp;

  bool get hasUnread => _hasUnread;
  bool _hasUnread;

  int get unreadCount => _unreadCount ?? 0;
  int _unreadCount;

  int get totalCount => _totalCount ?? 0;
  int _totalCount;

  List<SeamailMessage> getMessages() {
    return _messages.values.toList()..sort(
      (SeamailMessage a, SeamailMessage b) {
        if (a.timestamp == b.timestamp)
          return a.timestamp.compareTo(b.timestamp);
        return a.id.compareTo(b.id);
      },
    );
  }
  final Map<String, SeamailMessage> _messages = <String, SeamailMessage>{};

  bool _updating = false;
  @protected
  Future<void> update() async {
    if (_updating)
      return;
    startBusy();
    _updating = true;
    try {
      final SeamailThreadSummary thread = await _twitarr.getSeamailMessages(
        credentials: _credentials,
        threadId: id,
      ).asFuture();
      if (thread.id != id)
        throw LocalError('Unexpected data from server: asked for update to thread "$id", got data for thread "${thread.id}".');
      updateFrom(thread);
      if (onThreadRead != null)
        onThreadRead(id);
    } on UserFriendlyError catch (error) {
      _timer.interested();
      _parent._reportError(error);
    } finally {
      _updating = false;
      endBusy();
    }
    notifyListeners();
    _parent._childUpdated(this);
  }

  // Returns if something interesting was in the update.
  // implying we should check again soon
  @protected
  bool updateFrom(SeamailThreadSummary thread) {
    bool interesting = false;
    if (thread.subject != null)
      _subject = thread.subject;
    if (thread.users != null)
      _users = thread.users.map<User>((UserSummary user) => user.toUser(_photoManager)).toList();
    if (thread.lastMessageTimestamp != null)
      _lastMessageTimestamp = thread.lastMessageTimestamp;
    if (thread.unread != null) {
      _unreadCount = null;
      if (_hasUnread != null && !_hasUnread && thread.unread)
        interesting = true;
      _hasUnread = thread.unread;
    }
    if (thread.messages != null) {
      for (SeamailMessageSummary message in thread.messages) {
        if (!_messages.containsKey(message.id))
          interesting = true;
        _messages[message.id] = SeamailMessage.from(message, _photoManager);
      }
    }
    if (thread.totalMessages != null) {
      _totalCount = thread.totalMessages;
      if (_totalCount < _messages.length)
        _totalCount = _messages.length;
      if (thread.messages != null) {
        _unreadCount = 0;
        for (SeamailMessage message in _messages.values) {
          if (!message.readReceipts.containsKey(_credentials.username))
            _unreadCount += 1;
        }
        _hasUnread = _unreadCount > 0;
      }
    }
    if (thread.unreadMessages != null) {
      if (_unreadCount != thread.unreadMessages)
        interesting = true;
      _unreadCount = thread.unreadMessages;
      _hasUnread = _unreadCount > 0;
    }
    notifyListeners();
    _parent._childUpdated(this);
    if (interesting)
      _timer.interested();
    return interesting;
  }

  Progress<void> send(String text) {
    return Progress<void>((ProgressController<void> completer) async {
      final SeamailMessageSummary message = await completer.chain<SeamailMessageSummary>(
        _twitarr.postSeamailMessage(
          credentials: _credentials,
          threadId: id,
          text: text,
        ),
      );
      _timer.interested();
      if (_messages != null && _messages.containsKey(message.id))
        return;
      _messages[message.id] = SeamailMessage.from(message, _photoManager);
      notifyListeners();
      _parent._childUpdated(this);
    });
  }

  VariableTimer _timer;

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

class SeamailMessage {
  const SeamailMessage({
    this.id,
    this.user,
    this.text,
    this.timestamp,
    this.readReceipts,
  });

  SeamailMessage.from(
    SeamailMessageSummary message,
    PhotoManager photoManager,
  ) : id = message.id,
      user = message.user.toUser(photoManager),
      text = message.text,
      timestamp = message.timestamp,
      readReceipts = Map<String, User>.fromIterable(
        message.readReceipts.map<User>((UserSummary user) => user.toUser(photoManager)),
        key: (dynamic user) => (user as User).username,
      );

  final String id;

  final User user;

  final String text;

  final DateTime timestamp;

  final Map<String, User> readReceipts;
}
