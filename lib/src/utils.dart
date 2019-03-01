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

mixin BusyMixin {
  ValueListenable<bool> get busy => _busy;
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);
  int _busyCount = 0;

  @protected
  void startBusy() {
    if (_busyCount == 0)
      scheduleMicrotask(_updateBusy);
    _busyCount += 1;
  }

  @protected
  void endBusy() {
    _busyCount -= 1;
    if (_busyCount == 0)
      scheduleMicrotask(_updateBusy);
  }

  void _updateBusy() {
    _busy.value = _busyCount > 0;
  }
}

enum _VariableTimerState { disabled, enabled, ticking, disabling, tickingDisabling }

class VariableTimer {
  VariableTimer(this.maxDuration, this.callback);

  final Duration maxDuration;
  static const Duration minDuration = Duration(seconds: 3);

  final AsyncCallback callback;

  static const double multiplier = 1.5;

  double _backoffMultiplier = 1;
  Timer _timer;
  Duration _currentPeriod;
  final Stopwatch _stopwatch = Stopwatch();

  // State machine:
  //                    ,-------------------.
  //                    |                   |
  //                   \|/                  |
  //          ,--> disabled -----.          |
  // microtask|                  |          |
  //          |                  |start()   |
  //        disabling* -.        |          |
  //             /|\    |start() |          |
  //        stop()|     |        |          |
  //              |    \|/       |          |
  //             enabled*        |          |
  //             /|\  |          |          |
  //      complete|   |tick      |          |
  //              |  \|/         |          |
  //         .-> ticking* <------'          |
  //         |      |                       |
  //  start()|      |stop()                 |
  //         |     \|/                      |microtask
  //         tickingDisabling* -------------'
  //
  //  * handle interested()

  ValueListenable<bool> get active => _active;
  final ValueNotifier<bool> _active = ValueNotifier<bool>(false);

  _VariableTimerState _state = _VariableTimerState.disabled;
  void _updateState(_VariableTimerState value) {
    _state = value;
    _active.value = value == _VariableTimerState.ticking ||
                    value == _VariableTimerState.tickingDisabling;
  }

  void start() {
    assert(_state != null);
    switch (_state) {
      case _VariableTimerState.disabled:
        _updateState(_VariableTimerState.enabled);
        _currentPeriod = minDuration;
        _tick();
        return;
      case _VariableTimerState.disabling:
        _updateState(_VariableTimerState.enabled);
        return;
      case _VariableTimerState.enabled:
        return;
      case _VariableTimerState.ticking:
        return;
      case _VariableTimerState.tickingDisabling:
        _updateState(_VariableTimerState.ticking);
        return;
    }
  }

  void _tick() async {
    if (_state != _VariableTimerState.enabled)
      return;
    assert(_timer == null || !_timer.isActive);
    _timer = null;
    _updateState(_VariableTimerState.ticking);
    await callback();
    if (_state == _VariableTimerState.ticking) {
      _timer = Timer(_currentPeriod * _backoffMultiplier, _tick);
      _stopwatch..reset()..start();
      _currentPeriod *= multiplier;
      _updateState(_VariableTimerState.enabled);
    }
  }

  void stop() {
    assert(_state != null);
    switch (_state) {
      case _VariableTimerState.disabled:
        return;
      case _VariableTimerState.disabling:
        return;
      case _VariableTimerState.enabled:
        _updateState(_VariableTimerState.disabling);
        scheduleMicrotask(_disable);
        return;
      case _VariableTimerState.ticking:
        _updateState(_VariableTimerState.tickingDisabling);
        scheduleMicrotask(_disable);
        return;
      case _VariableTimerState.tickingDisabling:
        return;
    }
  }

  void _disable() {
    assert(_state != null);
    switch (_state) {
      case _VariableTimerState.disabled:
        return;
      case _VariableTimerState.disabling:
        assert(_timer != null);
        _timer.cancel();
        _timer = null;
        _updateState(_VariableTimerState.disabled);
        break;
      case _VariableTimerState.enabled:
        return;
      case _VariableTimerState.ticking:
        return;
      case _VariableTimerState.tickingDisabling:
        _updateState(_VariableTimerState.disabled);
        return;
    }
  }

  void interested({ bool wasError = false }) {
    if (wasError) {
      _backoffMultiplier += 1;
    } else {
      _backoffMultiplier = 1;
    }
    assert(_state != null);
    switch (_state) {
      case _VariableTimerState.disabled:
        _currentPeriod = minDuration;
        return;
      case _VariableTimerState.disabling:
        _currentPeriod = minDuration;
        return;
      case _VariableTimerState.enabled:
        final Duration elapsed = _stopwatch.elapsed;
        if (elapsed >= minDuration) {
          _timer.cancel();
          _timer = null;
          _currentPeriod = minDuration * multiplier;
          _tick();
        } else {
          _timer.cancel();
          _currentPeriod = minDuration;
          _timer = Timer((minDuration * _backoffMultiplier) - elapsed, _tick);
        }
        return;
      case _VariableTimerState.ticking:
        _currentPeriod = minDuration;
        return;
      case _VariableTimerState.tickingDisabling:
        _currentPeriod = minDuration;
        return;
    }
  }

  void reload() {
    _backoffMultiplier = 1;
    _currentPeriod = minDuration;
    assert(_state != null);
    switch (_state) {
      case _VariableTimerState.disabled:
        return;
      case _VariableTimerState.disabling:
        return;
      case _VariableTimerState.enabled:
        _timer.cancel();
        _timer = null;
        _tick();
        return;
      case _VariableTimerState.ticking:
        return;
      case _VariableTimerState.tickingDisabling:
        return;
    }
  }
}

String prettyDuration(Duration duration, { bool short = false }) {
  assert(short != null);
  final int microseconds = duration.inMicroseconds;
  double minutes = microseconds / (1000 * 1000 * 60);
  if (minutes < 0.9)
    return short ? 'now' : 'just now';
  if (minutes < 1.5)
    return short ? '1 min ago' : '1 minute ago';
  if (minutes < 59.5)
    return '${minutes.round()} ${short ? 'min' : 'minutes'} ago';
  double hours = microseconds / (1000 * 1000 * 60 * 60);
  minutes -= hours.truncate() * 60;
  if (hours < 2 && (minutes < 5 || (minutes < 30 && short)))
    return '1 hour ago';
  if (hours < 2 && !short)
    return '1 hour ${minutes.truncate()} minutes ago';
  if (hours < 5 && (minutes <= 20 || minutes >= 40))
    return '${hours.round()} hours ago';
  if (hours < 5)
    return '${hours.round()}½ hours ago';
  if (hours < 23)
    return '${hours.round()} hours ago';
  double days = microseconds / (1000 * 1000 * 60 * 60 * 24);
  hours -= days.truncate() * 24;
  if (days < 1.5)
    return '1 day ago';
  if (days < 10.5)
    return '${days.round()} days ago';
  final double weeks = microseconds / (1000 * 1000 * 60 * 60 * 24 * 7);
  days -= weeks.truncate() * 7;
  if (weeks < 1.5)
    return '1 week ago';
  return '${weeks.round()} weeks ago';
}
