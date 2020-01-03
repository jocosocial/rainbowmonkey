import 'dart:ui' show hashValues;

import 'package:flutter/foundation.dart';

import '../models/errors.dart';
import '../models/reactions.dart';
import '../models/user.dart';
import '../network/twitarr.dart';
import '../utils.dart';
import 'cruise.dart';
import 'forums.dart';
import 'photo_manager.dart';

typedef ThreadReadCallback = void Function(String threadId);

class Mentions extends ChangeNotifier with BusyMixin {
  Mentions(
    this._cruise,
    this._twitarr,
    this._credentials,
    this._photoManager, {
    this.maxUpdatePeriod = const Duration(minutes: 10),
    @required this.onError,
  }) : assert(onError != null),
       assert(_twitarr != null),
       assert(_credentials != null),
       assert(_photoManager != null) {
    _timer = VariableTimer(maxUpdatePeriod, update);
  }

  Mentions.empty(
    this._cruise,
  ) : _twitarr = null,
      _credentials = null,
      _photoManager = null,
      maxUpdatePeriod = null,
      onError = null;

  final CruiseModel _cruise;
  final Twitarr _twitarr;
  final Credentials _credentials;
  final PhotoManager _photoManager;

  final Duration maxUpdatePeriod;
  final ErrorCallback onError;

  ValueListenable<bool> get hasMentions => _hasMentions;
  final ValueNotifier<bool> _hasMentions = ValueNotifier<bool>(false);

  Iterable<MentionsItem> get items => _currentMentions;
  List<MentionsItem> _currentMentions = <MentionsItem>[];

  int _lastFreshnessToken;

  bool _updating = false;
  @protected
  Future<void> update() async {
    if (_updating || _credentials == null)
      return;
    startBusy();
    _updating = true;
    bool newMentions = false;
    try {
      final MentionsSummary summary = await _twitarr.getMentions(credentials: _credentials).asFuture();
      final List<MentionsItem> oldList = _currentMentions;
      _currentMentions = <MentionsItem>[]
        ..addAll(summary.forums.map<MentionsItem>((ForumSummary summary) => ForumMentionsItem(_cruise.forums.obtainForum(summary))))
        ..addAll(summary.streamPosts.map<MentionsItem>((StreamMessageSummary summary) => StreamMentionsItem.from(summary, _photoManager)))
        ..sort(
          (MentionsItem a, MentionsItem b) {
            if (a.timestamp != b.timestamp)
              return a.timestamp.compareTo(b.timestamp);
            return a.id.compareTo(b.id); // just to give some sort of stable sort
          },
        );
      _lastFreshnessToken = summary.freshnessToken;
      _hasMentions.value = _currentMentions.isNotEmpty;
      newMentions = listEquals<MentionsItem>(oldList, _currentMentions);
    } on UserFriendlyError catch (error) {
      _timer.interested(wasError: true);
      onError(error);
    } finally {
      _updating = false;
      endBusy();
    }
    if (newMentions)
      notifyListeners();
  }

  Future<void> clear() async {
    if (_updating || _credentials == null || _currentMentions.isEmpty)
      return;
    startBusy();
    _updating = true;
    _currentMentions.clear();
    _hasMentions.value = false;
    notifyListeners();
    try {
      await _twitarr.clearMentions(credentials: _credentials, freshnessToken: _lastFreshnessToken).asFuture();
      _updating = false;
      await update();
    } finally {
      endBusy();
    }
  }

  VariableTimer _timer;

  ValueListenable<bool> get active => _timer.active;

  void reload() {
    _timer.reload();
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

abstract class MentionsItem implements Comparable<MentionsItem> {
  const MentionsItem(this.id, this.timestamp);

  final String id;

  final DateTime timestamp;

  @override
  int compareTo(MentionsItem other) {
    if (timestamp.isBefore(other.timestamp))
      return -1;
    if (timestamp.isAfter(other.timestamp))
      return 1;
    return id.compareTo(other.id);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    final MentionsItem typedOther = other as MentionsItem;
    return id == typedOther.id
        && timestamp == typedOther.timestamp;
  }

  @override
  int get hashCode => hashValues(
    runtimeType,
    id,
    timestamp,
  );
}

class ForumMentionsItem extends MentionsItem {
  ForumMentionsItem(
    this.thread,
  ) : super(thread.id, thread.lastMessageTimestamp);

  final ForumThread thread;
}

class StreamMentionsItem extends MentionsItem {
  const StreamMentionsItem({
    String id,
    this.user,
    this.text,
    this.photo,
    this.reactions,
    DateTime timestamp,
  }) : super(id, timestamp);

  StreamMentionsItem.from(
    StreamMessageSummary message,
    PhotoManager photoManager,
  ) : user = message.user.toUser(photoManager),
      text = message.text,
      photo = message.photo,
      reactions = Reactions(message.reactions),
      super(message.id, message.timestamp);

  final User user;

  final String text;

  final Photo photo;

  final Reactions reactions;
}
