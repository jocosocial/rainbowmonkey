import 'dart:async';

import 'package:flutter/foundation.dart';

import '../progress.dart';
import 'user.dart';

typedef void SeamailUpdateCallback(SeamailUpdater updater);
typedef Progress<List<SeamailMessage>> SeamailMessagesCallback();
typedef Progress<void> SeamailSendCallback(String value);

// TODO(ianh): We need to be much more aggressive about updating the thread
// list, so that e.g. user-created new chats appear immediately, "unread"
// notifiers go away as soon as you view the messages, etc.

class Seamail extends ChangeNotifier {
  Seamail();

  bool get active => hasListeners;
  Future<void> get untilActive => _nextActive.future;
  Completer<void> _nextActive = new Completer<void>();

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners)
      _nextActive.complete();
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners)
      _nextActive = new Completer<void>();
  }

  final List<SeamailThread> _threads = <SeamailThread>[];
  final Map<String, SeamailThread> _threadsById = <String, SeamailThread>{};

  SeamailThread operator[](int index) {
    return _threads[index];
  }

  int get length => _threads.length;

  SeamailThread threadById(String id) {
    if (_threadsById.containsKey(id))
      return _threadsById[id];
    final SeamailThread thread = new SeamailThread.placeholder(this, id);
    _threadsById[id] = thread;
    _threads.add(thread);
    notifyListeners();
    return thread;
  }

  DateTime get lastUpdate => _lastUpdate;
  DateTime _lastUpdate;

  bool _openForUpdate = false;

  void update(DateTime timestamp, SeamailUpdateCallback updateCallback) {
    assert(!_openForUpdate);
    List<SeamailThread> allThreads;
    _openForUpdate = true;
    final SeamailUpdater updater = new SeamailUpdater(this);
    updateCallback(updater);
    final Set<SeamailThread> deadThreads = updater._finalize();
    allThreads = _threads.toList();
    if (deadThreads.isNotEmpty) {
      for (int index = _threads.length - 1; index >= 0; index -= 1) {
        final SeamailThread thread = _threads[index];
        if (deadThreads.contains(thread)) {
          thread.flagDeleted();
          _threads.removeAt(index);
          assert(_threadsById.containsKey(thread.id));
          _threadsById.remove(thread.id);
          deadThreads.remove(thread);
        }
      }
      assert(deadThreads.isEmpty);
    }
    _lastUpdate = timestamp;
    _openForUpdate = false;
    notifyListeners();
    for (SeamailThread thread in allThreads)
      thread._notifyIfDirty();
  }

  @override
  void notifyListeners() {
    if (!_openForUpdate)
      super.notifyListeners();
  }
}

class SeamailUpdater {
  SeamailUpdater(this._seamail) {
    _pendingThreads.addAll(_seamail._threads);
  }

  Seamail _seamail;

  final Set<SeamailThread> _pendingThreads = new Set<SeamailThread>();

  void updateThread(String id, {
    @required List<User> users,
    @required String subject,
    @required int messageCount,
    @required DateTime timestamp,
    @required bool unread,
    @required SeamailMessagesCallback messagesCallback,
    @required SeamailSendCallback sendCallback,
  }) {
    assert(_seamail._openForUpdate);
    final SeamailThread thread = _seamail.threadById(id);
    thread.users = users;
    thread.subject = subject;
    thread.messageCount = messageCount;
    thread.timestamp = timestamp;
    thread.unread = unread;
    thread.setCallbacks(messages: messagesCallback, send: sendCallback);
    _pendingThreads.remove(thread);
  }

  Set<SeamailThread> _finalize() {
    _seamail = null;
    return _pendingThreads;
  }
}

class SeamailThread extends ChangeNotifier {
  SeamailThread({
    Seamail seamail,
    this.id,
    List<User> users,
    String subject,
    int messageCount,
    DateTime timestamp,
    bool unread,
    SeamailMessagesCallback messagesCallback,
    SeamailSendCallback sendCallback,
  }) : _seamail = seamail,
       _users = users,
       _subject = subject,
       _messageCount = messageCount,
       _timestamp = timestamp,
       _unread = unread,
       _messagesCallback = messagesCallback,
       _sendCallback = sendCallback {
    _initMessages();
  }

  SeamailThread.placeholder(this._seamail, this.id) {
    _initMessages();
  }

  void _initMessages() {
    _messages = new PeriodicProgress<List<SeamailMessage>>(const Duration(seconds: 10), _updateMessages);
  }

  final Seamail _seamail;

  final String id;

  List<User> get users => new List<User>.unmodifiable(_users);
  List<User> _users;
  set users(List<User> value) {
    assert(_seamail._openForUpdate);
    if (listEquals(_users, value))
      return;
    _users = value;
    _dirty = true;
  }

  String get subject => _subject;
  String _subject;
  set subject(String value) {
    assert(_seamail._openForUpdate);
    if (_subject == value)
      return;
    _subject = value;
    _dirty = true;
  }

  int get messageCount => _messageCount;
  int _messageCount;
  set messageCount(int value) {
    assert(_seamail._openForUpdate);
    if (_messageCount == value)
      return;
    _messageCount = value;
    _dirty = true;
  }

  DateTime get timestamp => _timestamp;
  DateTime _timestamp;
  set timestamp(DateTime value) {
    assert(_seamail._openForUpdate);
    if (_timestamp == value)
      return;
    _timestamp = value;
    _dirty = true;
  }

  bool get unread => _unread;
  bool _unread;
  set unread(bool value) {
    assert(_seamail._openForUpdate);
    if (_unread == value)
      return;
    _unread = value;
    _dirty = true;
  }

  bool get deleted => _deleted;
  bool _deleted = false;
  void flagDeleted() {
    assert(_seamail._openForUpdate);
    assert(!_deleted);
    _deleted = true;
    _dirty = true;
  }

  ContinuousProgress<List<SeamailMessage>> get messages => _messages;
  PeriodicProgress<List<SeamailMessage>> _messages;
  SeamailMessagesCallback _messagesCallback;

  SeamailSendCallback get send => _sendCallback;
  SeamailSendCallback _sendCallback;

  void setCallbacks({ SeamailMessagesCallback messages, SeamailSendCallback send }) {
    assert(_seamail._openForUpdate);
    _messagesCallback = messages;
    _sendCallback = send;
  }

  Future<List<SeamailMessage>> _updateMessages(ProgressController<List<SeamailMessage>> completer) async {
    if (_messagesCallback == null)
      return const <SeamailMessage>[];
    return await completer.chain<List<SeamailMessage>>(_messagesCallback());
  }

  Progress<List<SeamailMessage>> forceUpdate() {
    return _messages.triggerUnscheduledUpdate();
  }

  bool _dirty = true;

  void _notifyIfDirty() {
    assert(!_seamail._openForUpdate);
    if (_dirty) {
      notifyListeners();
      _dirty = false;
    }
  }

  @override
  void dispose() {
    _messages.dispose();
    super.dispose();
  }
}

@immutable
class SeamailMessage {
  const SeamailMessage({ this.user, this.text, this.timestamp });
  final User user;
  final String text;
  final DateTime timestamp;
}
