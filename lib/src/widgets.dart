import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'logic/cruise.dart';
import 'models/user.dart';
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

Widget iconAndLabel({ Key key, @required IconData icon, @required String message }) {
  return Center(
    key: key,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 72.0),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
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
    return iconAndLabel(key: ProgressBuilder.failedKey, icon: Icons.warning, message: wrapError(error));
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

class Now extends InheritedNotifier<TimerNotifier> {
  Now({
    Key key,
    Widget child,
    Duration period,
  }) : super(
    key: key,
    notifier: TimerNotifier(period),
    child: child,
  );

  static DateTime of(BuildContext context) {
    final Now now = context.inheritFromWidgetOfExactType(Now) as Now;
    if (now == null)
      return null;
    return now.notifier.value;
  }
}

class TimerNotifier extends ValueNotifier<DateTime> {
  TimerNotifier(this.period) : super(DateTime.now());

  final Duration period;

  Timer _timer;

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners) {
      assert(_timer == null);
      _timer = Timer.periodic(period, _tick);
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners && _timer != null) {
      _timer.cancel();
      _timer = null;
    }
  }

  void _tick(Timer timer) {
    value = DateTime.now();
    notifyListeners();
  }
}

class ChatLine extends StatelessWidget {
  const ChatLine({
    Key key,
    @required this.user,
    @required this.isCurrentUser,
    @required this.messages,
    @required this.timestamp,
  }) : assert(user != null),
       assert(isCurrentUser != null),
       assert(messages != null),
       assert(timestamp != null),
       super(key: key);

  final User user;
  final bool isCurrentUser;
  final List<String> messages;
  final DateTime timestamp;

  static String prettyDuration(Duration duration) {
    final int microseconds = duration.inMicroseconds;
    double minutes = microseconds / (1000 * 1000 * 60);
    if (minutes < 0.9)
      return 'just now';
    if (minutes < 1.5)
      return '1 minute ago';
    if (minutes < 59.5)
      return '${minutes.round()} minutes ago';
    double hours = microseconds / (1000 * 1000 * 60 * 60);
    minutes -= hours.truncate() * 60;
    if (hours < 2 && minutes < 5)
      return '${hours.truncate()} hour ago';
    if (hours < 2)
      return '${hours.truncate()} hour ${minutes.truncate()} minutes ago';
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> lines = <Widget>[];
    final ThemeData theme = Theme.of(context);
    for (String message in messages) {
      lines.add(Text(message));
    }
    final TextDirection direction = isCurrentUser ? TextDirection.rtl : TextDirection.ltr;
    final DateTime now = Now.of(context);
    final String duration = '${prettyDuration(now.difference(timestamp))}';
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
      child: Directionality(
        textDirection: direction,
        child: Tooltip(
          message: '$user • $timestamp',
          child: ListBody(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Cruise.of(context).avatarFor(user),
                    ),
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        IntrinsicWidth(
                          child: Container(
                            margin: const EdgeInsetsDirectional.only(end: 20.0),
                            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
                            decoration: ShapeDecoration(
                              gradient: LinearGradient(
                                begin: const Alignment(0.0, -1.0),
                                end: const Alignment(0.0, 0.6),
                                colors: <Color>[
                                  Color.lerp(theme.primaryColor, Colors.white, 0.15),
                                  theme.primaryColor,
                                ],
                              ),
                              shadows: kElevationToShadow[1],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            child: DefaultTextStyle(
                              style: theme.primaryTextTheme.body1,
                              textAlign: isCurrentUser ? TextAlign.right : TextAlign.left,
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: lines,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        DefaultTextStyle(
                          style: theme.textTheme.caption.copyWith(color: Colors.grey.shade400),
                          textAlign: TextAlign.end,
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: isCurrentUser ? Text(duration) : Text('$user • $duration'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40.0),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// TODO(ianh): Make this look more like ChatLine
class ProgressChatLine extends StatelessWidget {
  const ProgressChatLine({
    Key key,
    @required this.progress,
    @required this.text,
    @required this.onRetry,
    @required this.onRemove,
  }) : assert(progress != null),
       assert(text != null),
       super(key: key);

  final Progress<void> progress;
  final String text;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProgressValue<void>>(
      valueListenable: progress,
      builder: (BuildContext context, ProgressValue<void> value, Widget child) {
        assert(child == null);
        Widget leading, trailing, subtitle;
        VoidCallback onTap;
        if (value is IdleProgress) {
          leading = const Icon(Icons.error, size: 40.0, color: Colors.orange);
        } else if (value is StartingProgress) {
          leading = const CircularProgressIndicator();
        } else if (value is ActiveProgress) {
          leading = CircularProgressIndicator(value: value.progress / value.target);
        } else if (value is FailedProgress) {
          leading = const Icon(Icons.error, size: 40.0, color: Colors.red);
          trailing = onRemove != null ? IconButton(icon: const Icon(Icons.clear), tooltip: 'Abandon message', onPressed: onRemove) : null;
          subtitle = onRetry != null ? Text('Failed: ${value.error}. Tap to retry.') : Text('Failed: ${value.error}');
          onTap = onRetry;
        } else if (value is SuccessfulProgress<void>) {
          leading = const Icon(Icons.error, size: 40.0, color: Colors.yellow);
        } else {
          leading = const Icon(Icons.error, size: 40.0, color: Colors.purple);
        }
        return ListTile(
          leading: leading,
          title: Text(text),
          trailing: trailing,
          subtitle: subtitle,
          onTap: onTap,
        );
      },
    );
  }
}

class BusyIndicator extends StatelessWidget {
  const BusyIndicator({
    Key key,
    this.busy,
    this.child,
    this.busyIndicator: _defaultIndicator,
    this.alignment: AlignmentDirectional.bottomEnd,
  }) : super(key: key);

  final ValueListenable<bool> busy;

  final Widget child;

  final Widget busyIndicator;

  final AlignmentGeometry alignment;

  static const Widget _defaultIndicator = Padding(
    padding: EdgeInsets.all(4.0),
    child: CircularProgressIndicator(),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        Positioned.fill(
          child: Align(
            alignment: alignment,
            child: IgnorePointer(
              child: ValueListenableBuilder<bool>(
                valueListenable: busy,
                builder: (BuildContext context, bool busy, Widget child) {
                  return AnimatedOpacity(
                    opacity: busy ? 1.0 : 0.0,
                    duration: kThemeChangeDuration,
                    curve: Curves.easeInOut,
                    child: busyIndicator,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
