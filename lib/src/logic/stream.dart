import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/reactions.dart';
import '../models/user.dart';
import '../network/twitarr.dart';
import '../progress.dart';
import '../utils.dart';
import 'photo_manager.dart';

typedef StreamErrorCallback = void Function(dynamic error, StackTrace stack);

class TweetStream extends ChangeNotifier with BusyMixin {
  TweetStream(
    this._twitarr,
    this._credentials, {
    @required this.photoManager,
    this.onError,
    this.maxUpdatePeriod = const Duration(minutes: 5),
  }) : assert(_twitarr != null),
       assert(photoManager != null),
       assert(maxUpdatePeriod != null) {
    _timer = VariableTimer(maxUpdatePeriod, _fetchForwards);
  }

  final Twitarr _twitarr;
  final Credentials _credentials;
  final PhotoManager photoManager;
  final StreamErrorCallback onError;
  final Duration maxUpdatePeriod;

  final List<StreamPost> _posts = <StreamPost>[];
  final Map<String, int> _postIds = <String, int>{};

  bool _started = false;
  bool _pinned = false;
  int _anchorIndex = 0;
  bool _seekingBackwards = false;
  bool _seekingForwards = false;
  bool _reachedTheEnd = false;

  StreamPost operator [](int index) {
    assert(index >= 0);
    index += _anchorIndex;
    if (index < _posts.length)
      return _posts[index];
    if (_reachedTheEnd)
      return const StreamPost.sentinel();
    _fetchBackwards();
    return null;
  }

  void _debugVerifyIntegrity() {
    assert(() {
      for (String id in _postIds.keys)
        assert(_posts[_postIds[id]].id == id);
      for (int index = 0; index < _posts.length; index += 1)
        assert(_postIds[_posts[index].id] == index);
      return true;
    }());
  }

  int pageSize = 100;
  static const int kEmergencyPageSizeDelta = 10;

  Future<void> _fetchBackwards() async {
    if (_seekingBackwards)
      return null;
    startBusy();
    _seekingBackwards = true;
    final bool isInitialFetch = _posts.isEmpty;
    if (isInitialFetch) {
      assert(!_seekingForwards);
      _seekingForwards = true;
    }
    try {
      bool didSomething = false;
      bool trying;
      do {
        trying = false;
        final int localPageSize = pageSize;
        final StreamSliceSummary result = await _twitarr.getStream(
          credentials: _credentials,
          direction: StreamDirection.backwards,
          boundaryToken: isInitialFetch ? null : _posts.last.boundaryToken,
          limit: localPageSize,
        ).asFuture();
        int overlap = 0;
        while (overlap < result.posts.length && _postIds.containsKey(result.posts[overlap].id)) {
          overlap += 1;
        }
        final bool theEnd = result.posts.length < localPageSize;
        if (overlap < result.posts.length) {
          final List<StreamPost> newPosts = result.posts.skip(overlap).map<StreamPost>(
            (StreamMessageSummary summary) => StreamPost.from(summary, photoManager),
          ).toList();
          int index = 0;
          for (StreamPost post in newPosts) {
            _postIds[post.id] = _posts.length + index;
            index += 1;
          }
          _posts.addAll(newPosts);
          _debugVerifyIntegrity();
          didSomething = true;
        } else if (overlap == localPageSize) {
          pageSize = math.max(pageSize, localPageSize + kEmergencyPageSizeDelta);
          trying = true;
        }
        if (theEnd && !_reachedTheEnd) {
          _reachedTheEnd = true;
          didSomething = true;
        }
      } while (trying);
      if (didSomething)
        notifyListeners();
    } catch (error, stack) { // ignore: avoid_catches_without_on_clauses
      if (onError != null) {
        onError(error, stack);
      } else {
        rethrow;
      }
    } finally {
      _seekingBackwards = false;
      if (isInitialFetch)
        _seekingForwards = false;
      endBusy();
      _started = true;
    }
  }

  Future<void> _fetchForwards() async {
    if (!_started)
      await _fetchBackwards();
    assert(_started);
    if (_seekingForwards || _posts.isEmpty)
      return;
    assert(_posts.isNotEmpty);
    startBusy();
    _seekingForwards = true;
    try {
      bool didSomething = false;
      bool trying;
      do {
        trying = false;
        final int localPageSize = pageSize;
        final StreamSliceSummary result = await _twitarr.getStream(
          credentials: _credentials,
          direction: StreamDirection.forwards,
          boundaryToken: _posts.first.boundaryToken,
          limit: localPageSize,
        ).asFuture();
        int overlap = 0;
        final int count = result.posts.length;
        while (overlap < count && _postIds.containsKey(result.posts[count - overlap - 1].id)) {
          overlap += 1;
        }
        if (overlap < count) {
          final List<StreamPost> newPosts = result.posts.take(count - overlap).map<StreamPost>(
            (StreamMessageSummary summary) => StreamPost.from(summary, photoManager),
          ).toList();
          _posts.insertAll(0, newPosts);
          int index = 0;
          for (StreamPost post in _posts) {
            _postIds[post.id] = index;
            index += 1;
          }
          _debugVerifyIntegrity();
          if (_pinned) {
            _anchorIndex += count - overlap;
          } else {
            assert(_anchorIndex == 0);
            didSomething = true;
          }
        } else if (overlap == localPageSize) {
          pageSize = math.max(pageSize, localPageSize + kEmergencyPageSizeDelta);
          trying = true;
        }
      } while (trying);
      if (didSomething)
        notifyListeners();
    } catch (error, stack) { // ignore: avoid_catches_without_on_clauses
      if (onError != null) {
        onError(error, stack);
      } else {
        rethrow;
      }
    } finally {
      _seekingForwards = false;
      endBusy();
    }
  }

  bool postIsNew(StreamPost post) {
    return _postIds[post.id] <= _anchorIndex;
  }

  void pin(bool value) { // ignore: avoid_positional_boolean_parameters
    if (_pinned != value) {
      _pinned = value;
      if (!_pinned && _anchorIndex != 0) {
        _anchorIndex = 0;
        notifyListeners();
      }
    }
  }

  VariableTimer _timer;

  ValueListenable<bool> get active => _timer.active;

  void reload() {
    _timer.reload();
  }

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners)
      _timer.start();
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners)
      _timer.stop();
  }

  Progress<void> send({
    @required String text,
    String parentId,
    @required Uint8List photo,
  }) {
    return Progress<void>((ProgressController<void> completer) async {
      await completer.chain<void>(
        _twitarr.postTweet(
          credentials: _credentials,
          text: text,
          photo: photo,
          parentId: parentId,
        ),
      );
      await _fetchForwards();
    });
  }

  Progress<void> delete(String postId) {
    assert(_credentials != null);
    return Progress<void>((ProgressController<void> completer) async {
      await completer.chain<void>(
        _twitarr.deleteTweet(
          credentials: _credentials,
          postId: postId,
        ),
      );
      if (_postIds.containsKey(postId)) {
        final int postPosition = _postIds[postId];
        assert(_posts[postPosition].id == postId);
        _posts[postPosition] = _posts[postPosition].copyWith(isDeleted: true);
        notifyListeners();
      }
    });
  }

  Progress<void> lock(String postId, { @required bool locked }) {
    assert(_credentials != null);
    assert(locked != null);
    return Progress<void>((ProgressController<void> completer) async {
      await completer.chain<void>(
        _twitarr.lockTweet(
          credentials: _credentials,
          postId: postId,
          locked: locked,
        ),
      );
    });
  }

  Progress<void> react(String postId, String reaction, { @required bool selected }) {
    assert(_credentials != null);
    return Progress<void>((ProgressController<void> completer) async {
      final Map<String, ReactionSummary> reactions = await completer.chain<Map<String, ReactionSummary>>(
        _twitarr.reactTweet(
          credentials: _credentials,
          postId: postId,
          reaction: reaction,
          selected: selected,
        ),
      );
      if (_postIds.containsKey(postId)) {
        final int postPosition = _postIds[postId];
        assert(_posts[postPosition].id == postId);
        _posts[postPosition] = _posts[postPosition].copyWith(reactions: Reactions(reactions));
        notifyListeners();
      }
    });
  }

  Progress<Set<User>> getReactions(String postId, String reaction) {
    assert(_credentials != null);
    return Progress<Set<User>>((ProgressController<Set<User>> completer) async {
      final Map<String, Set<UserSummary>> reactions = await completer.chain<Map<String, Set<UserSummary>>>(
        _twitarr.getTweetReactions(
          credentials: _credentials,
          postId: postId,
        ),
      );
      if (!reactions.containsKey(reaction))
        return const <User>{};
      return reactions[reaction].map<User>((UserSummary user) => user.toUser(photoManager)).toSet();
    });
  }

  Progress<StreamPost> fetchFullThread(String rootId) {
    return Progress<StreamPost>((ProgressController<StreamPost> completer) async {
      return StreamPost.from(
        await completer.chain<StreamMessageSummary>(
          _twitarr.getTweet(
            credentials: _credentials,
            threadId: rootId,
          ),
        ),
        photoManager,
      );
    });
  }
}

class StreamPost {
  const StreamPost({
    this.id,
    this.user,
    this.text,
    this.photo,
    this.timestamp,
    this.boundaryToken,
    this.isLocked,
    this.reactions,
    this.parents,
    this.children,
    this.isDeleted,
  });

  StreamPost.from(StreamMessageSummary summary, PhotoManager photoManager)
     : id = summary.id,
       user = summary.user.toUser(photoManager),
       text = summary.text,
       photo = summary.photo,
       timestamp = summary.timestamp,
       boundaryToken = summary.boundaryToken,
       isLocked = summary.locked,
       reactions = Reactions(summary.reactions),
       parents = summary.parents,
       children = summary.children?.map<StreamPost>((StreamMessageSummary summary) => StreamPost.from(summary, photoManager))?.toList(),
       isDeleted = false;

  const StreamPost.sentinel(
  ) : id = null,
      user = null,
      text = null,
      photo = null,
      timestamp = null,
      boundaryToken = null,
      isLocked = null,
      reactions = null,
      parents = null,
      children = null,
      isDeleted = false;

  final String id;

  final User user;

  final String text;

  final Photo photo;

  final DateTime timestamp;

  final int boundaryToken;

  final bool isLocked;

  final Reactions reactions;

  final List<String> parents;

  final List<StreamPost> children;

  final bool isDeleted;

  StreamPost copyWith({
    String id,
    User user,
    String text,
    Photo photo,
    DateTime timestamp,
    int boundaryToken,
    bool isLocked,
    Reactions reactions,
    List<String> parents,
    List<StreamPost> children,
    bool isDeleted,
  }) {
    return StreamPost(
      id: id ?? this.id,
      user: user ?? this.user,
      text: text ?? this.text,
      photo: photo ?? this.photo,
      timestamp: timestamp ?? this.timestamp,
      boundaryToken: boundaryToken ?? this.boundaryToken,
      isLocked: isLocked ?? this.isLocked,
      reactions: reactions ?? this.reactions,
      parents: parents ?? this.parents,
      children: children ?? this.children,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  String toString() => '$runtimeType($id, $timestamp, $user, "$text")';
}
