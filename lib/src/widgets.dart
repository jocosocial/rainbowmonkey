import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'logic/cruise.dart';
import 'progress.dart';

const Duration animationDuration = Duration(milliseconds: 100);
const Curve animationCurve = Curves.fastOutSlowIn;

class Cruise extends InheritedNotifier<CruiseModel> {
  const Cruise({
    Key key,
    CruiseModel cruiseModel,
    @required Widget child,
  }) : super(key: key, child: child, notifier: cruiseModel);

  static CruiseModel of(BuildContext context) {
    final Cruise widget = context.inheritFromWidgetOfExactType(Cruise) as Cruise;
    return widget?.notifier;
  }
}

typedef Widget ActiveProgressBuilder(BuildContext context, double progress, double target);
typedef Widget FailedProgressBuilder(BuildContext context, Exception error, StackTrace stackTrace);
typedef Widget SuccessfulProgressBuilder<T>(BuildContext context, T value);
typedef Widget WrapBuilder(BuildContext context, Widget main, Widget secondary);
typedef Widget FadeWrapperBuilder(BuildContext context, Widget child);

String wrapError(Exception error) {
  if (error is SocketException) {
    final SocketException e = error;
    if (e.osError.errorCode == 113)
      return 'Cannot reach server (${e.address.host}:${e.port}).';
    if (e.osError.errorCode == 101)
      return 'Network is offline (are you in airplane mode?).';
  }
  return error.toString();
}

Widget _defaultSecondaryActiveBuilder(BuildContext context, double progress, double target) {
  assert(target != 0.0);
  return CircularProgressIndicator(key: ProgressBuilder.activeKey, value: progress / target);

}
Widget _defaultSecondaryFailedBuilder(BuildContext context, Exception error, StackTrace stackTrace) {
  assert(error != null);
  return Tooltip(
    key: ProgressBuilder.failedKey,
    message: '$error',
    child: const Icon(Icons.error_outline),
  );
}

Widget _defaultWrap(BuildContext context, Widget main, Widget secondary) {
  assert(main != null);
  return Stack(
    children: <Widget>[
      main,
      PositionedDirectional(
        end: 0.0,
        bottom: 0.0,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: secondary,
        ),
      ),
    ],
  );
}

Widget _defaultFadeWrapper(BuildContext context, Widget child) {
  return AnimatedSwitcher(
    duration: animationDuration,
    switchInCurve: animationCurve,
    switchOutCurve: animationCurve,
    child: child,
  );
}

class _ActiveKey extends LocalKey { const _ActiveKey(); }
class _FailedKey extends LocalKey { const _FailedKey(); }

class ProgressBuilder<T> extends StatelessWidget {
  const ProgressBuilder({
    Key key,
    @required this.progress,
    this.nullChild: const SizedBox.expand(),
    this.idleChild: const SizedBox.expand(),
    this.startingChild: const Center(key: activeKey, child: CircularProgressIndicator()),
    this.activeBuilder: defaultActiveBuilder,
    this.failedBuilder: defaultFailedBuilder,
    @required this.builder,
    this.fadeWrapper: _defaultFadeWrapper,
  }) : assert(idleChild != null),
       assert(startingChild != null),
       assert(activeBuilder != null),
       assert(failedBuilder != null),
       assert(builder != null),
       assert(fadeWrapper != null),
       super(key: key);

  final Progress<T> progress;

  final Widget nullChild;
  final Widget idleChild;
  final Widget startingChild;
  final ActiveProgressBuilder activeBuilder;
  final FailedProgressBuilder failedBuilder;
  final SuccessfulProgressBuilder<T> builder;
  final FadeWrapperBuilder fadeWrapper;

  static const Key activeKey = _ActiveKey();
  static const Key failedKey = _FailedKey();

  static Widget defaultActiveBuilder(BuildContext context, double progress, double target) {
    assert(target != 0.0);
    return Center(key: ProgressBuilder.activeKey, child: CircularProgressIndicator(value: progress / target));
  }

  static Widget defaultFailedBuilder(BuildContext context, Exception error, StackTrace stackTrace) {
    assert(error != null);
    return Center(
      key: ProgressBuilder.failedKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.warning, size: 72.0),
          Text(wrapError(error), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (progress == null)
      return nullChild;
    return ValueListenableBuilder<ProgressValue<T>>(
      valueListenable: progress,
      builder: (BuildContext context, ProgressValue<T> value, Widget child) {
        assert(child == null);
        Widget result;
        if (value is IdleProgress) {
          result = idleChild;
        } else if (value is StartingProgress) {
          result = startingChild;
        } else if (value is ActiveProgress) {
          result = activeBuilder(context, value.progress, value.target);
        } else if (value is FailedProgress) {
          result = failedBuilder(context, value.error, value.stackTrace);
        } else if (value is SuccessfulProgress<T>) {
          result = builder(context, value.value);
        } else {
          result = failedBuilder(context, Exception('$value'), null);
        }
        return fadeWrapper(context, result);
      },
    );
  }
}

class ContinuousProgressBuilder<T> extends StatelessWidget {
  const ContinuousProgressBuilder({
    Key key,
    @required this.progress,
    this.nullChild: const SizedBox.expand(),
    this.idleChild: const SizedBox.expand(),
    this.startingChild: const Center(child: CircularProgressIndicator()),
    this.activeBuilder: ProgressBuilder.defaultActiveBuilder,
    this.failedBuilder: ProgressBuilder.defaultFailedBuilder,
    @required this.builder,
    this.secondaryStartingChild: const CircularProgressIndicator(key: ProgressBuilder.activeKey),
    this.secondaryActiveBuilder: _defaultSecondaryActiveBuilder,
    this.secondaryFailedBuilder: _defaultSecondaryFailedBuilder,
    this.wrap: _defaultWrap,
    this.fadeWrapper: _defaultFadeWrapper,
  }) : assert(idleChild != null),
       assert(startingChild != null),
       assert(activeBuilder != null),
       assert(failedBuilder != null),
       assert(builder != null),
       assert(secondaryStartingChild != null),
       assert(secondaryActiveBuilder != null),
       assert(secondaryFailedBuilder != null),
       assert(wrap != null),
       assert(fadeWrapper != null),
       super(key: key);

  final ContinuousProgress<T> progress;

  final Widget nullChild;
  final Widget idleChild;
  final Widget startingChild;
  final ActiveProgressBuilder activeBuilder;
  final FailedProgressBuilder failedBuilder;
  final SuccessfulProgressBuilder<T> builder;
  final Widget secondaryStartingChild;
  final ActiveProgressBuilder secondaryActiveBuilder;
  final FailedProgressBuilder secondaryFailedBuilder;
  final WrapBuilder wrap;
  final FadeWrapperBuilder fadeWrapper;

  @override
  Widget build(BuildContext context) {
    if (progress == null)
      return nullChild;
    return AnimatedBuilder(
      animation: progress,
      child: ProgressBuilder<T>(
        progress: progress.best,
        idleChild: idleChild,
        startingChild: startingChild,
        activeBuilder: activeBuilder,
        failedBuilder: failedBuilder,
        builder: builder,
      ),
      builder: (BuildContext context, Widget child) {
        return wrap(
          context,
          child,
          ValueListenableBuilder<ProgressValue<T>>(
            valueListenable: progress.current,
            child: child,
            builder: (BuildContext context, ProgressValue<T> value, Widget child) {
              assert(child != null);
              Widget result;
              if (progress.best.value > value) {
                if (value is StartingProgress) {
                  result = secondaryStartingChild;
                } else if (value is ActiveProgress) {
                  result = secondaryActiveBuilder(context, value.progress, value.target);
                } else if (value is FailedProgress) {
                  result = secondaryFailedBuilder(context, value.error, value.stackTrace);
                }
              }
              result ??= const SizedBox.shrink();
              return fadeWrapper(context, result);
            },
          ),
        );
      },
    );
  }
}

class ProgressDialog<T> extends StatefulWidget {
  const ProgressDialog({
    Key key,
    this.progress,
  }) : super(key: key);

  final Progress<T> progress;

  @override
  _ProgressDialogState<T> createState() => _ProgressDialogState<T>();
}

class _ProgressDialogState<T> extends State<ProgressDialog<T>> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.progress.asFuture().then((T value) {
      if (mounted)
        Navigator.pop<T>(context, value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 150),
        curve: Curves.fastOutSlowIn,
        vsync: this,
        child: IntrinsicWidth(
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ProgressBuilder<T>(
                progress: widget.progress,
                builder: (BuildContext context, T value) {
                  return const Center(
                    child: Icon(Icons.check, size: 60.0),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a red dot over another widget.
///
/// Typically used to indicate that the widget has notifications to report.
class Badge extends StatelessWidget {
  /// Creates a badge widget.
  ///
  /// The child cannot be null.
  const Badge({
    Key key,
    @required this.child,
    this.enabled = true,
  }) : assert(child != null),
       super(key: key);

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.child}
  final Widget child;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        child,
        Positioned.fill(
          child: Visibility(
            visible: enabled,
            child: const IgnorePointer(
              child: FractionallySizedBox(
                alignment: AlignmentDirectional(0.9, -0.9),
                widthFactor: 0.25,
                heightFactor: 0.25,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: Colors.red,
                    shape: CircleBorder(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

abstract class View implements Widget {
  Widget buildFab(BuildContext context);
  Widget buildTab(BuildContext context);
}
