import 'dart:async';

import 'package:flutter/foundation.dart';

enum ProgressStatus {
  /// No attempt has been made to obtain any data.
  ///
  /// [Progress.progressValue] and [Progress.progressTarget] are 0.0.
  /// [Progress.lastError] is the empty string.
  idle,

  /// An attempt to obtain data is under way, though no data is yet available.
  ///
  /// [Progress.progressValue] and [Progress.progressTarget] represent the
  /// current state. If they are both 0.0, then the progress is indeterminate.
  /// If they are greater than zero, then their precise meaning is undefined but
  /// is probably bytes to be transferred. The fraction of progress is
  /// [Progress.progressValue] divided by [Progress.progressTarget].
  ///
  /// [Progress.lastError] may have an error message from a previous attempt.
  active,

  /// An attempt to obtain data was under way, but it failed.
  ///
  /// [Progress.progressValue] and [Progress.progressTarget] represent the last
  /// effort's incomplete results (e.g. what fraction of the data was obtained).
  ///
  /// [Progress.lastError] should have an error message from the failed attempt.
  failed,

  /// Data is available.
  ///
  /// [Progress.progressValue] and [Progress.progressTarget] should be equal,
  /// though the precise meaning of the numbers is not defined.
  ///
  /// [Progress.lastError] may have an error message from a previous attempt.
  complete,

  /// Old data is available, and another attempt to obtain data is under way.
  ///
  /// [Progress.progressValue] and [Progress.progressTarget] represent the
  /// current state. If they are both 0.0, then the progress is indeterminate.
  /// If they are greater than zero, then their precise meaning is undefined but
  /// is probably bytes to be transferred. The fraction of progress is
  /// [Progress.progressValue] divided by [Progress.progressTarget].
  ///
  /// [Progress.lastError] may have an error message from a previous attempt.
  updating,
}

abstract class Progress implements Listenable {
  factory Progress._() => null; // this is a mixin and an interface

  ProgressStatus get progressStatus => _progressStatus;
  ProgressStatus _progressStatus = ProgressStatus.idle;

  double get progressValue => _progressValue;
  double _progressValue = 0.0;

  double get progressTarget => _progressTarget;
  double _progressTarget = 0.0;

  String get lastError => _lastError;
  String _lastError = '';

  List<Progress> _forwardingTargets;

  @mustCallSuper
  @protected
  void updatedProgress() {
    if (_forwardingTargets != null)
      _forwardingTargets.forEach(_forwardProgressTo);
  }

  /// Propagate all progress changes to the given target.
  ///
  /// To propagate only progress values (e.g. because the load has several
  /// stages), use [ProgressCompleter.absorbProgress].
  void forwardProgress(Progress target) {
    assert(() {
      final Set<Progress> seen = new Set<Progress>()
        ..add(this);
      void process(Progress candidate) {
        if (seen.contains(candidate))
          throw new StateError('Progress.forwardProgress called in a manner that would create a cycle');
        seen.add(candidate);
        if (candidate._forwardingTargets != null)
          candidate._forwardingTargets.forEach(process);
      }
      process(target);
      return true;
    }());
    _forwardingTargets ??= <Progress>[];
    _forwardingTargets.add(target);
    _forwardProgressTo(target);
  }

  void _forwardProgressTo(Progress target) {
    target
      .._progressStatus = progressStatus
      .._progressValue = progressValue
      .._progressTarget = progressTarget
      .._lastError = lastError
      ..updatedProgress();
  }
}

/// A mixin for classes that control classes that mix in [Progress].
abstract class ProgressCompleter {
  factory ProgressCompleter._() => null; // this is a mixin

  /// The [Progress] instance to be controlled.
  ///
  /// Must never return null.
  Progress get progress;

  void startProgress() {
    switch (progress.progressStatus) {
      case ProgressStatus.idle:
      case ProgressStatus.active:
      case ProgressStatus.failed:
        progress._progressStatus = ProgressStatus.active;
        break;
      case ProgressStatus.complete:
      case ProgressStatus.updating:
        progress._progressStatus = ProgressStatus.updating;
        break;
    }
    progress
      .._progressValue = 0.0
      .._progressTarget = 0.0
      ..updatedProgress();
  }

  void setProgress(double value, double target) {
    assert(value != null);
    assert(target != null);
    assert(value <= target);
    switch (progress.progressStatus) {
      case ProgressStatus.idle:
      case ProgressStatus.active:
      case ProgressStatus.failed:
        progress._progressStatus = ProgressStatus.active;
        break;
      case ProgressStatus.complete:
      case ProgressStatus.updating:
        progress._progressStatus = ProgressStatus.updating;
        break;
    }
    progress
      .._progressValue = value
      .._progressTarget = target
      ..updatedProgress();
  }

  void failProgress(String error) {
    assert(error != null);
    switch (progress.progressStatus) {
      case ProgressStatus.idle:
      case ProgressStatus.active:
      case ProgressStatus.failed:
        progress._progressStatus = ProgressStatus.failed;
        break;
      case ProgressStatus.complete:
      case ProgressStatus.updating:
        progress._progressStatus = ProgressStatus.complete;
        break;
    }
    progress
      .._lastError = error
      ..updatedProgress();
  }

  void completeProgress() {
    progress
      .._progressStatus = ProgressStatus.complete
      .._progressValue = progress.progressTarget
      ..updatedProgress();
  }

  /// This forwards changes to the `source` object's [Progress.progressValue]
  /// and [Progress.progressTarget] until the [Progress.progressStatus] becomes
  /// [ProgressStatus.idle], [ProgressStatus.failed], or [ProgressStatus.complete].
  ///
  /// The given object must have a status of [ProgressStatus.active] or
  /// [ProgressStatus.updating] when the method is called.
  void absorbProgress(Progress source) {
    assert(source.progressStatus == ProgressStatus.active ||
           source.progressStatus == ProgressStatus.updating);
    void forwarded() {
      switch (source.progressStatus) {
        case ProgressStatus.idle:
        case ProgressStatus.failed:
        case ProgressStatus.complete:
          source.removeListener(forwarded);
          break;
        case ProgressStatus.updating:
        case ProgressStatus.active:
          progress
            .._progressValue = source.progressValue
            .._progressTarget = source.progressTarget
            ..updatedProgress();
          break;
      }
    }
    source.addListener(forwarded);
  }
}

class FutureWithProgress<T> extends Object with Progress, ChangeNotifier implements Future<T> {
  FutureWithProgress._();

  final Completer<T> _completer = new Completer<T>();

  @override
  Stream<T> asStream() => _completer.future.asStream();

  @override
  Future<T> catchError(Function onError, { bool test(dynamic error) }) {
    return _completer.future.catchError(onError, test: test);
  }

  @override
  Future<E> then<E>(FutureOr<E> f(T value), { Function onError }) {
    return _completer.future.then<E>(f, onError: onError);
  }

  @override
  Future<T> timeout(Duration timeLimit, { FutureOr<T> onTimeout() }) {
    return _completer.future.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<T> whenComplete(dynamic action()) {
    return _completer.future.whenComplete(action);
  }

  @override
  void updatedProgress() {
    notifyListeners();
    super.updatedProgress();
  }
}

class CompleterWithProgress<T> extends Object with ProgressCompleter implements Completer<T> {
  CompleterWithProgress() {
    startProgress();
  }

  @override
  FutureWithProgress<T> get future => _future;
  final FutureWithProgress<T> _future = new FutureWithProgress<T>._();

  @override
  bool get isCompleted => _future._completer.isCompleted;

  @override
  void complete([ FutureOr<T> value ]) {
    _future._completer.complete(value);
    if (value is Future) {
      final Future<T> future = value;
      future.then( // ignore: cascade_invocations, https://github.com/dart-lang/sdk/issues/32407
        (T value) => completeProgress(),
        onError: (Object error, StackTrace stackTrace) => failProgress(error.toString())
      );
    } else {
      completeProgress();
    }
  }

  @override
  void completeError(Object error, [ StackTrace stackTrace ]) {
    _future._completer.completeError(error, stackTrace);
    failProgress(error.toString());
  }

  @override
  Progress get progress => _future;
}

abstract class ProgressValueListenable<T> implements ValueListenable<T>, Progress { }

abstract class _LazyValueNotifier<T> extends ValueNotifier<T> with Progress {
  _LazyValueNotifier() : super(null);

  @protected
  void start();

  @protected
  void stop();

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners)
      start();
    super.addListener(listener);
    assert(hasListeners);
  }

  @override
  void removeListener(VoidCallback listener) {
    assert(hasListeners);
    super.removeListener(listener);
    if (!hasListeners)
      stop();
  }

  @override
  void dispose() {
    if (hasListeners)
      stop();
    super.dispose();
  }

  @override
  void updatedProgress() {
    notifyListeners();
    super.updatedProgress();
  }
}

abstract class _ProgressValueNotifierMixin<T> implements ValueNotifier<T>, ProgressCompleter {
  bool _silenceListeners = false;

  @override
  set value(T newValue) { // ignore: avoid_setters_without_getters
    _silenceListeners = true;
    try {
      super.value = newValue;
    } finally {
      _silenceListeners = false;
    }
    completeProgress();
  }

  @override
  void notifyListeners() {
    if (!_silenceListeners)
      super.notifyListeners();
  }
}

class PollingValueNotifier<T> extends _LazyValueNotifier<T>
  with ProgressCompleter, _ProgressValueNotifierMixin<T>
  implements ProgressValueListenable<T> {

  PollingValueNotifier({
    this.getter,
    this.interval,
  });

  final ValueGetter<FutureWithProgress<T>> getter;

  final Duration interval;

  Timer _timer;
  FutureWithProgress<T> _future;

  @override
  void start() {
    _timer = new Timer.periodic(interval, _tick);
    _tick(_timer);
  }

  @override
  void stop() {
    _timer.cancel();
    _timer = null;
    _future = null;
  }

  void _tick(Timer timer) {
    assert(timer == _timer);
    if (_future == null) {
      _future = getter();
      assert(_future != null, '$runtimeType getter returned null.\nThe getter must not return null. This getter was:\n$getter');
      _future
        ..then<void>(_update, onError: _error)
        ..whenComplete(() { _future = null; });
      startProgress();
      absorbProgress(_future);
    }
  }

  void _update(T newValue) { // ignore: use_setters_to_change_properties
    if (_future != null)
      value = newValue;
  }

  void _error(Object error, StackTrace stackTrace) {
    if (_future != null)
      failProgress(error.toString());
  }

  @override
  Progress get progress => this;
}

class ProgressValueNotifier<T> extends ValueNotifier<T>
  with Progress, ProgressCompleter, _ProgressValueNotifierMixin<T>
  implements ProgressValueListenable<T> {

  ProgressValueNotifier(T value) : super(value);

  @override
  Progress get progress => this;

  @override
  void updatedProgress() {
    notifyListeners();
    super.updatedProgress();
  }
}
