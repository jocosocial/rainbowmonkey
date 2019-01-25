import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../network/twitarr.dart';
import '../utils.dart';
import 'photo_manager.dart';

typedef StreamErrorCallback = void Function(dynamic error, StackTrace stack);

class TweetStream extends ChangeNotifier with BusyIndicator {
  TweetStream(
    this._twitarr, {
    @required this.photoManager,
    this.onError,
    this.maxUpdatePeriod = const Duration(minutes: 5),
  }) : assert(_twitarr != null),
       assert(photoManager != null),
       assert(maxUpdatePeriod != null) {
    _fetchBackwards();
    assert(_seekingForwards);
  }

  final Twitarr _twitarr;
  final PhotoManager photoManager;
  final StreamErrorCallback onError;
  final Duration maxUpdatePeriod;

  final List<StreamPost> _posts = <StreamPost>[];
  final Map<String, int> _postIds = <String, int>{};

  VariableTimer _timer;
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

  int pageSize = 100;
  static const int kEmergencyPageSizeDelta = 10;

  void _fetchBackwards() async {
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
            (StreamPostSummary summary) => StreamPost.from(summary, photoManager),
          ).toList();
          int index = 0;
          for (StreamPost post in newPosts) {
            _postIds[post.id] = _posts.length + index;
            index += 1;
          }
          _posts.addAll(newPosts);
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
    }
  }

  void _fetchForwards() async {
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
            (StreamPostSummary summary) => StreamPost.from(summary, photoManager),
          ).toList();
          _posts.insertAll(0, newPosts);
          int index = 0;
          for (StreamPost post in newPosts) {
            _postIds[post.id] = index;
            index += 1;
          }
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

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners)
      _timer = VariableTimer(maxUpdatePeriod, _fetchForwards);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer.cancel();
      _timer = null;
    }
  }
}

class StreamPost {
  const StreamPost({
    this.id,
    this.user,
    this.text,
    this.timestamp,
    this.boundaryToken,
  });

  StreamPost.from(StreamPostSummary summary, PhotoManager photoManager)
     : id = summary.id,
       user = summary.user.toUser(photoManager),
       text = summary.text,
       timestamp = summary.timestamp,
       boundaryToken = summary.boundaryToken;

  const StreamPost.sentinel() : id = null, user = null, text = null, timestamp = null, boundaryToken = null;

  final String id;

  final User user;

  final String text;

  final DateTime timestamp;

  final int boundaryToken;

  // TODO(ianh): photo
  // TODO(ianh): reactions
  // TODO(ianh): parents

  @override
  String toString() => '$runtimeType($id, $timestamp, $user, "$text")';
}
