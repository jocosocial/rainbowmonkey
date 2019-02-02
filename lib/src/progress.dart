import 'dart:async';

import 'package:flutter/foundation.dart';

import 'utils.dart';

enum _ProgressIndex { idle, starting, active, failed, successful }

abstract class ProgressValue<T> {
  const ProgressValue();
  _ProgressIndex get _index;
  bool operator <(ProgressValue<dynamic> other) => compareTo(other) < 0;
  bool operator >(ProgressValue<dynamic> other) => compareTo(other) > 0;
  bool operator <=(ProgressValue<dynamic> other) => compareTo(other) <= 0;
  bool operator >=(ProgressValue<dynamic> other) => compareTo(other) >= 0;
  @protected
  int compareTo(ProgressValue<dynamic> other) => _index.index - other._index.index;
}

class IdleProgress extends ProgressValue<Null> {
  const IdleProgress();
  @override
  _ProgressIndex get _index => _ProgressIndex.idle;
}

class StartingProgress extends ProgressValue<Null> {
  const StartingProgress();
  @override
  _ProgressIndex get _index => _ProgressIndex.starting;
}

class ActiveProgress extends ProgressValue<Null> {
  const ActiveProgress(
    this.progress,
    this.target,
  ) : assert(progress != null),
      assert(target != null),
      assert(progress >= 0.0),
      assert(target > 0.0),
      assert(progress <= target);
  final double progress;
  final double target;
  @override
  _ProgressIndex get _index => _ProgressIndex.active;
  @override
  int compareTo(ProgressValue<dynamic> other) {
    int result = super.compareTo(other);
    if (result == 0) {
      final ActiveProgress typedOther = other as ActiveProgress;
      result = ((progress / target) - (typedOther.progress / typedOther.target)).sign.toInt();
    }
    return result;
  }
}

class FailedProgress extends ProgressValue<Null> {
  const FailedProgress(this.error, [ this.stackTrace ]);
  final Exception error;
  final StackTrace stackTrace;
  @override
  _ProgressIndex get _index => _ProgressIndex.failed;
}

class SuccessfulProgress<T> extends ProgressValue<T> {
  const SuccessfulProgress(this.value);
  final T value;
  @override
  _ProgressIndex get _index => _ProgressIndex.successful;
}

typedef Future<T> ProgressCallback<T>(ProgressController<T> controller);
typedef B Converter<A, B>(A value);

abstract class Progress<T> implements ValueListenable<ProgressValue<T>> {
  factory Progress(ProgressCallback<T> completer) {
    final ProgressController<T> controller = ProgressController<T>();
    controller.start();
    completer(controller).then<void>(controller.complete, onError: controller.completeError);
    return controller.progress;
  }

  factory Progress.deferred(ProgressCallback<T> completer) {
    final ProgressController<T> controller = ProgressController<T>();
    completer(controller).then<void>(controller.complete, onError: controller.completeError);
    return controller.progress;
  }

  factory Progress.fromFuture(Future<T> future) {
    final ProgressController<T> controller = ProgressController<T>();
    controller.start();
    future.then<void>(controller.complete, onError: controller.completeError);
    return controller.progress;
  }

  factory Progress.completed(T value) {
    final ProgressController<T> controller = ProgressController<T>();
    controller.complete(value);
    return controller.progress;
  }

  const factory Progress.idle() = _IdleProgress;

  static Progress<T> convert<F, T>(Progress<F> progress, Converter<F, T> converter) {
    return Progress<T>.deferred((ProgressController<T> completer) async {
      final Completer<T> innerCompleter = Completer<T>();
      void _listener() {
        final ProgressValue<F> newValue = progress.value;
        if (newValue is SuccessfulProgress<F>) {
          innerCompleter.complete(converter(newValue.value));
        } else {
          completer._update(newValue as ProgressValue<T>); // TODO(ianh): Find a more type-safe solution
        }
      }
      _listener();
      progress.addListener(_listener);
      try {
        return await innerCompleter.future;
      } finally {
        progress.removeListener(_listener);
      }
    });
  }

  Future<T> asFuture();
}

class _LazyValueNotifier<T> extends ValueNotifier<T> {
  _LazyValueNotifier({
    this.onAdd,
    this.onRemove,
    T value,
  }) : super(value);

  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners && onAdd != null)
      onAdd();
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners && onRemove != null)
      onRemove();
  }
}

class _Progress<T> extends _LazyValueNotifier<ProgressValue<T>> implements Progress<T> {
  _Progress({
    VoidCallback onAdd,
    VoidCallback onRemove,
    ProgressValue<T> value,
  }) : super(onAdd: onAdd, onRemove: onRemove, value: value);

  @override
  Future<T> asFuture() {
    if (value is SuccessfulProgress<T>) {
      final SuccessfulProgress<T> typedValue = value as SuccessfulProgress<T>;
      return Future<T>.value(typedValue.value);
    }
    return valueListenableToFutureAdapter<ProgressValue<T>>(this, (ProgressValue<T> value) {
      if (value is SuccessfulProgress<T>)
        return true;
      if (value is FailedProgress)
        return true;
      return false;
    }).then<T>((ProgressValue<T> value) {
      if (value is SuccessfulProgress<T>)
        return value.value;
      assert(value is FailedProgress);
      final FailedProgress typedValue = value as FailedProgress;
      return Future<T>.error(typedValue.error, typedValue.stackTrace);
    });
  }
}

class ProgressController<T> {
  ProgressController();

  Progress<T> get progress => _progress;
  final _Progress<T> _progress = _Progress<T>(value: const IdleProgress());

  void _update(ProgressValue<T> next) {
    assert(_progress.value._index.index <= next._index.index);
    assert(_progress.value._index.index <= _ProgressIndex.active.index);
    _progress.value = next;
  }

  void start() {
    _update(const StartingProgress());
  }

  void advance(double progress, double target) {
    _update(ActiveProgress(progress, target));
  }

  /// Make this progress follow a subprogress.
  ///
  /// If steps is null, then subprogress values are ignored.
  /// Otherwise, subprogress values add to the current progress, and a
  /// complete cycle (0.0-1.0) of the subprogress corresponds to 1/steps
  /// in the main progress.
  Future<R> chain<R>(Progress<R> subprogress, { int steps = 1 }) async {
    assert(subprogress != null);
    double startingStep = 0.0;
    final ProgressValue<T> currentProgress = _progress.value;
    if (currentProgress is ActiveProgress)
      startingStep = currentProgress.progress;
    assert(steps == null || (1.0 / steps) <= 1.0 - startingStep);
    final Completer<R> completer = Completer<R>();
    void _listener() {
      switch (subprogress.value._index) {
        case _ProgressIndex.idle:
          break;
        case _ProgressIndex.starting:
          final StartingProgress newValue = subprogress.value as StartingProgress;
          if (_progress.value._index.index < newValue._index.index)
            _update(newValue);
          break;
        case _ProgressIndex.active:
          if (steps == null) {
            if (_progress.value._index.index < _ProgressIndex.starting.index)
              start();
          } else {
            final ActiveProgress newValue = subprogress.value as ActiveProgress;
            advance(startingStep + newValue.progress / newValue.target, steps.toDouble());
          }
          break;
        case _ProgressIndex.failed:
          final FailedProgress newValue = subprogress.value as FailedProgress;
          completer.completeError(newValue.error, newValue.stackTrace);
          break;
        case _ProgressIndex.successful:
          final SuccessfulProgress<R> newValue = subprogress.value as SuccessfulProgress<R>;
          completer.complete(newValue.value);
          break;
      }
    }
    _listener();
    subprogress.addListener(_listener);
    try {
      return await completer.future;
    } finally {
      subprogress.removeListener(_listener);
    }
  }

  void completeError(dynamic error, StackTrace stackTrace) {
    _update(FailedProgress(error is Exception ? error : Exception(error.toString()), stackTrace));
  }

  void complete(T value) {
    _update(SuccessfulProgress<T>(value));
  }
}

class _IdleProgress implements Progress<Null> {
  const _IdleProgress();

  @override
  ProgressValue<Null> get value => const IdleProgress();

  @override
  void addListener(VoidCallback listener) { }

  @override
  void removeListener(VoidCallback listener) { }

  @override
  Future<Null> asFuture() => Completer<Null>().future;
}

abstract class ContinuousProgress<T> implements Listenable {
  ContinuousProgress() {
    _best = _Progress<T>(
      onAdd: _handleAdd,
      onRemove: _handleRemove,
      value: const IdleProgress(),
    );
  }

  Progress<T> get current => _current;
  Progress<T> _current = const Progress<Null>.idle(); // ignore: prefer_final_fields, https://github.com/dart-lang/sdk/issues/34417

  Progress<T> get best => _best;
  _Progress<T> _best;

  T get currentValue {
    final ProgressValue<T> currentProgress = best.value;
    if (currentProgress is SuccessfulProgress<T>)
      return currentProgress.value;
    return null;
  }

  void _handleAdd() {}
  void _handleRemove() {}
}

class MutableContinuousProgress<T> extends ContinuousProgress<T> with ChangeNotifier {
  MutableContinuousProgress();

  /// Resets the best progress (and current progress) to idle.
  ///
  /// Useful in the case of the best value becoming obsolete (e.g. if it
  /// represents current user state but the user logs out).
  void reset() {
    addProgress(const Progress<Null>.idle());
    _best.value = _current.value;
    notifyListeners();
  }

  void addProgress(Progress<T> newProgress) {
    _current.removeListener(_update);
    _current = newProgress;
    _update();
    _current.addListener(_update);
    notifyListeners();
  }

  void _update() {
    final ProgressValue<T> newValue = _current.value;
    if (newValue >= _best.value) {
      _best.value = newValue;
      if (newValue._index.index > _ProgressIndex.active.index) {
        assert(newValue is! IdleProgress);
        _handleDone(); // also removes the listener
      }
    }
  }

  @protected
  @mustCallSuper
  void _handleDone() {
    addProgress(const Progress<Null>.idle());
  }
}

class PeriodicProgress<T> extends MutableContinuousProgress<T> {
  PeriodicProgress(
    this.duration,
    this.onTick, {
    this.onCancel,
  }) : assert(duration > Duration.zero),
       assert(onTick != null);

  final Duration duration;
  final ProgressCallback<T> onTick;
  final VoidCallback onCancel;

  Timer _timer;
  int _listenerCount = 0;
  bool _active = false;

  Progress<T> triggerUnscheduledUpdate() => _start();

  void triggerUnscheduledUpdateIfListened() {
    if (_listenerCount > 0)
      triggerUnscheduledUpdate();
  }

  @override
  void addProgress(Progress<T> newProgress) {
    _cancel();
    _active = true;
    super.addProgress(newProgress);
  }

  @override
  void _handleAdd() {
    assert(_listenerCount >= 0);
    if (_listenerCount == 0 && _timer == null) {
      Timer.run(_tick);
      _timer = Timer.periodic(duration, _tick);
    }
    _listenerCount += 1;
  }

  bool _scheduledMicrotask = false;

  @override
  void _handleRemove() {
    _listenerCount -= 1;
    if (_listenerCount == 0 && !_scheduledMicrotask) {
      _scheduledMicrotask = true;
      scheduleMicrotask(() {
        _scheduledMicrotask = false;
        if (_listenerCount == 0) {
          _cancel();
          _timer.cancel();
          _timer = null;
        }
      });
    }
    assert(_listenerCount >= 0);
  }

  void _tick([ Timer timer ]) {
    if (!_active)
      _start();
  }

  Progress<T> _start() {
    final Progress<T> newProgress = Progress<T>(onTick);
    addProgress(newProgress); // sets _active to true
    assert(_active);
    return newProgress;
  }

  @override
  void _handleDone() {
    super._handleDone();
    _active = false;
  }

  void _cancel() {
    if (_active && onCancel != null) {
      onCancel();
      _active = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
