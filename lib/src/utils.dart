// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

typedef ValuePredicateCallback<T> = bool Function(T value);

/// Converts a [ValueListenable<T>] to a [Future<T>].
///
/// The `predicate` callback is invoked each time the given [ValueListenable]
/// sends notifications, until the callback returns true, at which point the
/// future completes with the current value of the [ValueListenable].
///
/// If the predicate throws an exception, the future is completed as an error
/// using that exception.
///
/// The `predicate` callback must not cause the listener to send notifications
/// reentrantly; if it does, the future will complete with an error.
Future<T> valueListenableToFutureAdapter<T>(ValueListenable<T> listenable, ValuePredicateCallback<T> predicate) {
  assert(predicate != null);
  final Completer<T> completer = Completer<T>();
  bool handling = false;
  void listener() {
    if (handling && !completer.isCompleted) {
      listenable.removeListener(listener);
      completer.completeError(
        StateError(
          'valueListenableToFutureAdapter does not support reentrant notifications triggered by the predicate\n'
          'The predicate passed to valueListenableToFutureAdapter caused the listenable ($listenable) to send '
          'a notification while valueListenableToFutureAdapter was already processing a notification.'
        )
      );
    }
    try {
      handling = true;
      final T value = listenable.value;
      if (predicate(value) && !completer.isCompleted) {
        completer.complete(value);
        listenable.removeListener(listener);
      }
    } catch (error, stack) { // ignore: avoid_catches_without_on_clauses
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
        listenable.removeListener(listener);
      } else {
        rethrow;
      }
    } finally {
      handling = false;
    }
  }
  listenable.addListener(listener);
  return completer.future;
}

mixin BusyIndicator {
  ValueListenable<bool> get busy => _busy;
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);
  int _busyCount = 0;

  @protected
  void startBusy() {
    if (_busyCount == 0)
      _busy.value = true;
    _busyCount += 1;
  }

  @protected
  void endBusy() {
    _busyCount -= 1;
    if (_busyCount == 0)
      _busy.value = false;
  }
}

class VariableTimer {
  VariableTimer(this.maxDuration, this.callback) {
    interested();
    Timer.run(tick);
  }

  final Duration maxDuration;

  final VoidCallback callback;

  Timer _timer;
  Duration _currentPeriod;

  void tick() {
    _currentPeriod *= 1.5;
    callback();
    if (_currentPeriod > maxDuration)
      _currentPeriod = maxDuration;
    _timer = Timer(_currentPeriod, tick);
  }

  void interested() {
    _currentPeriod = const Duration(seconds: 3);
  }

  void cancel() {
    _timer.cancel();
    _timer = null;
  }
}
