import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'package:photo_view/photo_view.dart';

import 'logic/cruise.dart';
import 'logic/photo_manager.dart';
import 'models/server_status.dart';
import 'models/server_text.dart';
import 'models/user.dart';
import 'progress.dart';
import 'utils.dart';

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
Widget _defaultSecondaryFailedBuilder(BuildContext context, Exception error, StackTrace stackTrace, { VoidCallback onRetry }) {
  assert(error != null);
  return Tooltip(
    key: ProgressBuilder.failedKey,
    message: '$error',
    child: onRetry == null ? const Icon(Icons.error_outline)
           : IconButton(icon: const Icon(Icons.error_outline), onPressed: onRetry),
  );
}

Widget _defaultWrap(BuildContext context, Widget main, Widget secondary) {
  assert(main != null);
  return ConstrainedBox(
    constraints: const BoxConstraints(minWidth: double.infinity, maxWidth: double.infinity),
    child: Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        main,
        PositionedDirectional(
          end: 0.0,
          top: 0.0,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: secondary,
          ),
        ),
      ],
    ),
  );
}

const Duration animationDuration = Duration(milliseconds: 150);
const Curve animationCurve = Curves.fastOutSlowIn;

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
    this.failedBuilder,
    @required this.builder,
    this.fadeWrapper: _defaultFadeWrapper,
    this.onRetry,
  }) : assert(idleChild != null),
       assert(startingChild != null),
       assert(activeBuilder != null),
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

  final VoidCallback onRetry;

  static const Key activeKey = _ActiveKey();
  static const Key failedKey = _FailedKey();

  static Widget defaultActiveBuilder(BuildContext context, double progress, double target) {
    assert(target != 0.0);
    return Center(key: ProgressBuilder.activeKey, child: CircularProgressIndicator(value: progress / target));
  }

  static Widget defaultFailedBuilder(BuildContext context, Exception error, StackTrace stackTrace, { VoidCallback onRetry }) {
    assert(error != null);
    final Widget message = iconAndLabel(key: ProgressBuilder.failedKey, icon: Icons.warning, message: wrapError(error));
    if (onRetry == null)
      return message;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          message,
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FlatButton(
              child: const Text('RETRY'),
              onPressed: onRetry,
            ),
          ),
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
          result = failedBuilder != null ? failedBuilder(context, value.error, value.stackTrace)
                   : defaultFailedBuilder(context, value.error, value.stackTrace, onRetry: onRetry);
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
    this.failedBuilder,
    @required this.builder,
    this.secondaryStartingChild: const CircularProgressIndicator(key: ProgressBuilder.activeKey),
    this.secondaryActiveBuilder: _defaultSecondaryActiveBuilder,
    this.secondaryFailedBuilder,
    this.wrap: _defaultWrap,
    this.fadeWrapper: _defaultFadeWrapper,
    this.onRetry,
  }) : assert(idleChild != null),
       assert(startingChild != null),
       assert(activeBuilder != null),
       assert(builder != null),
       assert(secondaryStartingChild != null),
       assert(secondaryActiveBuilder != null),
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
  final VoidCallback onRetry;

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
        onRetry: onRetry,
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
                  result = secondaryFailedBuilder != null ? secondaryFailedBuilder(context, value.error, value.stackTrace)
                           : _defaultSecondaryFailedBuilder(context, value.error, value.stackTrace, onRetry: onRetry);
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

  static Future<T> show<T>(BuildContext context, Progress<T> progress) {
    return showDialog<T>(
      context: context,
      builder: (BuildContext context) => ProgressDialog<T>(
        progress: progress,
      ),
    );
  }

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
    this.alignment = const AlignmentDirectional(0.9, -0.9),
  }) : assert(child != null),
       assert(enabled != null),
       assert(alignment != null),
       super(key: key);

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.child}
  final Widget child;

  final bool enabled;

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        child,
        Positioned.fill(
          child: Visibility(
            visible: enabled,
            child: IgnorePointer(
              child: FractionallySizedBox(
                alignment: alignment,
                widthFactor: 0.25,
                heightFactor: 0.25,
                child: const DecoratedBox(
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
  bool isEnabled(ServerStatus status);
  Widget buildTabIcon(BuildContext context);
  Widget buildTabLabel(BuildContext context);
  Widget buildFab(BuildContext context);
}

class Now extends InheritedNotifier<ValueNotifier<DateTime>> {
  Now({
    Key key,
    Widget child,
    Duration period,
  }) : super(
    key: key,
    notifier: TimerNotifier(period),
    child: child,
  );

  Now.fixed({
    Key key,
    DateTime dateTime,
    Widget child,
  }) : super(
    key: key,
    notifier: ValueNotifier<DateTime>(dateTime),
    child: child,
  );

  static DateTime of(BuildContext context) {
    final Now now = context.inheritFromWidgetOfExactType(Now) as Now;
    assert(now != null);
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

typedef ProgressCallback<T> = Progress<T> Function();

class ChatLine extends StatefulWidget {
  const ChatLine({
    Key key,
    @required this.user,
    this.isCurrentUser = false,
    @required this.messages,
    this.photos,
    this.id,
    @required this.timestamp,
    this.likes = 0,
    this.onPressed,
    this.onDelete,
    this.onDeleteModerator,
    this.onEdit,
    this.onLike,
    this.onUnlike,
    this.getLikesCallback,
  }) : assert(user != null),
       assert(isCurrentUser != null),
       assert(messages != null),
       assert(timestamp != null),
       assert(likes != null),
       assert(likes >= 0),
       assert(photos == null || id != null),
       super(key: key);

  final User user;
  final bool isCurrentUser;
  final List<String> messages;
  final List<Photo> photos;
  final String id;
  final DateTime timestamp;
  final int likes;
  final VoidCallback onPressed;
  final VoidCallback onDelete;
  final VoidCallback onDeleteModerator;
  final VoidCallback onEdit;
  final VoidCallback onLike;
  final VoidCallback onUnlike;
  final ProgressCallback<Set<User>> getLikesCallback;

  @override
  State<ChatLine> createState() => _ChatLineState();
}

class _ChatLineState extends State<ChatLine> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _pressed = true;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _pressed = false;
    });
    if (widget.onPressed != null)
      widget.onPressed();
  }

  void _handleTapCancel() {
    setState(() {
      _pressed = false;
    });
  }

  void _viewLikes() {
    final Progress<Set<User>> progress = widget.getLikesCallback();
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Likes'),
            ),
            body: ProgressBuilder<Set<User>>(
              progress: progress,
              builder: (BuildContext context, Set<User> users) {
                final List<User> sortedUsers = users.toList()..sort();
                return ListView.builder(
                  itemCount: sortedUsers.length,
                  itemBuilder: (BuildContext context, int index) {
                    final User user = sortedUsers[index];
                    return ListTile(
                      key: ValueKey<String>(user.username),
                      leading: Cruise.of(context).avatarFor(<User>[user]),
                      title: Text(user.toString()),
                      onTap: () {
                        Navigator.pushNamed(context, '/profile', arguments: user);
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _handleLongPress() async {
    final List<Widget> actions = <Widget>[];
    void action(String label, IconData icon, VoidCallback callback) {
      if (callback != null) {
        actions.add(LabeledIconButton(label: Text(label), icon: Icon(icon), center: false, onPressed: () {
          Navigator.pop(context);
          callback();
        }));
      }
    }
    action('LIKE', Icons.thumb_up, widget.onLike);
    action('UNLIKE', Icons.thumb_down, widget.onUnlike);
    action('VIEW LIKES', Icons.group, widget.getLikesCallback != null && widget.likes > 0 ? _viewLikes : null);
    action('EDIT', Icons.delete_forever, widget.onEdit);
    action('DELETE', Icons.delete_forever, widget.onDelete);
    action('DELETE\n(MODERATOR ACTION)', Icons.delete_forever, widget.onDeleteModerator);
    final List<Widget> children = <Widget>[
      Text('Posted by: ${widget.user}'),
      Text('Timestamp: ${widget.timestamp}'),
    ];
    if (actions.isNotEmpty) {
      children.addAll(<Widget>[
        const Divider(),
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 8.0,
          crossAxisAlignment: WrapCrossAlignment.start,
          runSpacing: 8.0,
          children: actions,
        ),
      ]);
    } else {
      children.add(const SizedBox(height: 12.0));
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(ChatLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null)
      _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> lines = <Widget>[];
    final ThemeData theme = Theme.of(context);
    for (String message in widget.messages)
      lines.add(Text(message));
    if (widget.photos != null) {
      for (Photo photo in widget.photos) {
        lines.add(PhotoImage(tag: '${widget.id}:${photo.id}', photo: photo));
      }
    }
    final TextDirection direction = widget.isCurrentUser ? TextDirection.rtl : TextDirection.ltr;
    final DateTime now = Now.of(context);
    final List<String> metadata = <String>[];
    if (!widget.isCurrentUser)
      metadata.add('${widget.user}');
    metadata.add('${prettyDuration(now.difference(widget.timestamp))}');
    if (widget.likes == 1) {
      metadata.add('1 like');
    } else if (widget.likes > 0) {
      metadata.add('${widget.likes} likes');
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
      child: Directionality(
        textDirection: direction,
        child: GestureDetector(
          onLongPress: _handleLongPress,
          child: ListBody(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Cruise.of(context).avatarFor(<User>[widget.user]),
                    ),
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        IntrinsicWidth(
                          child: GestureDetector(
                            onTapDown: widget.onPressed != null ? _handleTapDown : null,
                            onTapUp: widget.onPressed != null ? _handleTapUp : null,
                            onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.fastOutSlowIn,
                              margin: const EdgeInsetsDirectional.only(end: 20.0),
                              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
                              decoration: ShapeDecoration(
                                gradient: LinearGradient(
                                  begin: _pressed ? const Alignment(0.0, 0.6) : const Alignment(0.0, -1.0),
                                  end: _pressed ? const Alignment(0.0, -1.0) : const Alignment(0.0, 0.6),
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
                                textAlign: widget.isCurrentUser ? TextAlign.right : TextAlign.left,
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
                        ),
                        const SizedBox(height: 4.0),
                        DefaultTextStyle(
                          style: theme.textTheme.caption.copyWith(color: Colors.grey.shade400),
                          textAlign: TextAlign.start,
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(metadata.join(' • ')),
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
    @required this.photos,
    @required this.onRetry,
    @required this.onRemove,
  }) : assert(progress != null),
       assert(text != null),
       super(key: key);

  final Progress<void> progress;
  final String text;
  final List<Uint8List> photos;
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
        String title = text;
        if (photos != null && photos.isNotEmpty)
          title += ' (+${photos.length} image${ photos.length == 1 ? "" : "s"})';
        return ListTile(
          leading: leading,
          title: Text(title),
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
    this.alignment: AlignmentDirectional.topEnd,
  }) : super(key: key);

  final ValueListenable<bool> busy;

  final Widget child;

  final Widget busyIndicator;

  final AlignmentGeometry alignment;

  static const Widget _defaultIndicator = Padding(
    padding: EdgeInsets.all(8.0),
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
                    duration: const Duration(milliseconds: 500),
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

typedef VSyncBuilderCallback = Widget Function(BuildContext context, TickerProvider vsync);

class VSyncBuilder extends StatefulWidget {
  const VSyncBuilder({
    Key key,
    @required this.builder,
  }) : assert(builder != null),
       super(key: key);

  final VSyncBuilderCallback builder;

  @override
  _VSyncBuilderState createState() => _VSyncBuilderState();
}

class _VSyncBuilderState extends State<VSyncBuilder> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return widget.builder(context, this);
  }
}

class LabeledIconButton extends StatelessWidget {
  const LabeledIconButton({ Key key, this.onPressed, this.icon, this.label, this.center = true }) : super(key: key);

  final VoidCallback onPressed;
  final Widget icon;
  final Widget label;
  final bool center;

  @override
  Widget build(BuildContext context) {
    Widget result = FlatButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: <Widget>[
            icon,
            const SizedBox(height: 8.0),
            DefaultTextStyle.merge(
              textAlign: TextAlign.center,
              child: label,
            ),
          ],
        ),
      ),
    );
    if (center)
      result = Center(child: result);
    return result;
  }
}

class ServerTextView extends StatefulWidget {
  const ServerTextView(this.filename, { Key key }) : super(key: key);

  final String filename;

  @override
  State<ServerTextView> createState() => _ServerTextViewState();
}

class _ServerTextViewState extends State<ServerTextView> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateText();
  }

  @override
  void didUpdateWidget(ServerTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filename != oldWidget.filename)
      _updateText();
  }

  Progress<ServerText> _serverText;

  void _updateText() {
    _serverText = Cruise.of(context).fetchServerText(widget.filename);
  }

  @override
  Widget build(BuildContext context) {
    assert(_serverText != null);
    final TextTheme textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 20.0),
        child: IntrinsicHeight(
          child: ProgressBuilder<ServerText>(
            progress: _serverText,
            onRetry: () { setState(_updateText); },
            builder: (BuildContext context, ServerText text) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: text.sections.expand<Widget>((ServerTextSection section) sync* {
                  if (section.header != null) {
                    yield Padding(
                      padding: EdgeInsets.only(
                        top: textTheme.title.fontSize,
                        bottom: textTheme.body1.fontSize / 2.0,
                      ),
                      child: Text(section.header, style: textTheme.title),
                    );
                  }
                  if (section.paragraphs != null) {
                    yield* section.paragraphs.map<Widget>((ServerTextParagraph paragraph) {
                      final Widget body = Text(paragraph.text, style: textTheme.body1);
                      if (paragraph.hasBullet) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Text(' • ', style: textTheme.body1),
                            Expanded(child: body),
                          ],
                        );
                      }
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: textTheme.body1.fontSize / 2.0,
                        ),
                        child: body,
                      );
                    });
                  }
                }).toList(),
              );
            },
          ),
        ),
      ),
    );
  }
}

Widget createAvatarWidgetsFor(List<User> sortedUsers, List<Color> colors, List<ImageProvider> images, { double size, bool enabled = true }) {
  switch (sortedUsers.length) {
    case 1:
      final User user = sortedUsers.single;
      final String name = user.displayName ?? user.username;
      List<String> names = name.split(RegExp(r'[^A-Z]+')).where((String value) => value.isNotEmpty).toList();
      if (names.isEmpty)
        names = name.split(' ');
      bool pressed = false;
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final ThemeData theme = Theme.of(context);
          TextStyle textStyle = theme.primaryTextTheme.subhead;
          switch (ThemeData.estimateBrightnessForColor(colors.single)) {
            case Brightness.dark:
              textStyle = textStyle.copyWith(color: theme.primaryColorLight);
              break;
            case Brightness.light:
              textStyle = textStyle.copyWith(color: theme.primaryColorDark);
              break;
          }
          final Widget avatar = Center(
            heightFactor: 1.0,
            widthFactor: 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.fastOutSlowIn,
              decoration: ShapeDecoration(
                shape: const CircleBorder(),
                color: colors.single,
                shadows: kElevationToShadow[pressed ? 4 : 1],
              ),
              child: ClipOval(
                child: Center(
                  child: Text(
                    names.take(math.min(2, names.length)).map<String>((String value) => String.fromCharCode(value.runes.first)).join(''),
                    style: textStyle,
                    textScaleFactor: 1.0,
                  ),
                ),
              ),
              foregroundDecoration: ShapeDecoration(
                shape: const CircleBorder(),
                image: DecorationImage(
                  image: images.single,
                  fit: BoxFit.cover,
                ),
              ),
              height: size ?? 40.0,
              width: size ?? 40.0,
            ),
          );
          if (!enabled)
            return avatar;
          return GestureDetector(
            onTapDown: (TapDownDetails details) {
              setState(() { pressed = true; });
            },
            onTapUp: (TapUpDetails details) {
              setState(() { pressed = false; });
            },
            onTapCancel: () {
              setState(() { pressed = false; });
            },
            onTap: () {
              Navigator.pushNamed(context, '/profile', arguments: sortedUsers.single);
            },
            child: avatar,
          );
        },
      );
    case 2:
      return Stack(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            decoration: ShapeDecoration(
              shape: const CircleBorder(),
              color: Colors.white,
              shadows: kElevationToShadow[1],
            ),
            height: size,
            width: size,
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.topCenter,
              heightFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 0.5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: PathBorder(_topSemicircle),
                    color: colors[0],
                    image: DecorationImage(
                      image: images[0],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.bottomCenter,
              heightFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(top: 0.5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: PathBorder(_bottomSemicircle),
                    color: colors[1],
                    image: DecorationImage(
                      image: images[1],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    case 3:
      return Stack(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            decoration: ShapeDecoration(
              shape: const CircleBorder(),
              color: Colors.white,
              shadows: kElevationToShadow[1],
            ),
            height: size,
            width: size,
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.topLeft,
              heightFactor: 0.5,
              widthFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 0.5, right: 0.5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: PathBorder(_topLeftQuarter),
                    color: colors[0],
                    image: DecorationImage(
                      image: images[0],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.topRight,
              heightFactor: 0.5,
              widthFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 0.5, left: 0.5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: PathBorder(_topRightQuarter),
                    color: colors[1],
                    image: DecorationImage(
                      image: images[1],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.bottomCenter,
              heightFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(top: 0.5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: PathBorder(_bottomSemicircle),
                    color: colors[2],
                    image: DecorationImage(
                      image: images[2],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    case 4:
      return Stack(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            decoration: ShapeDecoration(
              shape: const CircleBorder(),
              color: Colors.white,
              shadows: kElevationToShadow[1],
            ),
            height: size,
            width: size,
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.topLeft,
              heightFactor: 0.5,
              widthFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 0.5, right: 0.5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: PathBorder(_topLeftQuarter),
                    color: colors[0],
                    image: DecorationImage(
                      image: images[0],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.topRight,
              heightFactor: 0.5,
              widthFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 0.5, left: 0.5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: PathBorder(_topRightQuarter),
                    color: colors[1],
                    image: DecorationImage(
                      image: images[1],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.bottomLeft,
              heightFactor: 0.5,
              widthFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(top: 0.5, right: 0.5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: PathBorder(_bottomLeftQuarter),
                    color: colors[2],
                    image: DecorationImage(
                      image: images[2],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.bottomRight,
              heightFactor: 0.5,
              widthFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(top: 0.5, left: 0.5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: PathBorder(_bottomRightQuarter),
                    color: colors[3],
                    image: DecorationImage(
                      image: images[3],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    default:
      return Stack(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            decoration: ShapeDecoration(
              shape: const CircleBorder(),
              color: Colors.white,
              shadows: kElevationToShadow[1],
            ),
            height: size,
            width: size,
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.topLeft,
              heightFactor: 0.5,
              widthFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 0.5, right: 0.5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: PathBorder(_topLeftQuarter),
                    color: colors[0],
                    image: DecorationImage(
                      image: images[0],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.topRight,
              heightFactor: 0.5,
              widthFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 0.5, left: 0.5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: PathBorder(_topRightQuarter),
                    color: colors[1],
                    image: DecorationImage(
                      image: images[1],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.bottomLeft,
              heightFactor: 0.5,
              widthFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(top: 0.5, right: 0.5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: PathBorder(_bottomLeftQuarter),
                    color: colors[2],
                    image: DecorationImage(
                      image: images[2],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.bottomRight,
              heightFactor: 0.5,
              widthFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(top: 0.5, left: 0.5),
                child: Builder(
                  builder: (BuildContext context) {
                    return DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: PathBorder(_bottomRightQuarter),
                        color: Theme.of(context).primaryColor,
                      ),
                      child: ClipPath.shape(
                        shape: PathBorder(_bottomRightQuarter),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(2.0, 1.0, 7.0, 5.0),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Text(
                              '+${sortedUsers.length - 3}',
                              style: Theme.of(context).primaryTextTheme.body2,
                            ),
                          ),
                        ),
                      ),
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

class PhotoImage extends StatelessWidget {
  const PhotoImage({
    Key key,
    @required this.photo,
    @required this.tag,
  }) : super(key: key);

  final Photo photo;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final CruiseModel cruise = Cruise.of(context);
    final MediaQueryData metrics = MediaQuery.of(context);
    final double maxHeight = math.min(
      metrics.size.height - metrics.padding.vertical - (56.0 * 3.0),
      photo.mediumSize.height / metrics.devicePixelRatio,
    );
    final ImageProvider thumbnail = cruise.imageFor(
      photo,
      thumbnail: true,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: AspectRatio(
        aspectRatio: photo.mediumSize.width == 0 ? 1.0 : photo.mediumSize.width / photo.mediumSize.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: GestureDetector(
            onTap: () {
              bool appBarVisible = false;
              Navigator.push<void>(context, MaterialPageRoute<void>(
                builder: (BuildContext context) {
                  // TODO(ianh): download button in app bar
                  // TODO(ianh): pinch zoom
                  return StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      return Container(
                        color: Colors.black,
                        child: Stack(
                          children: <Widget>[
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  appBarVisible = !appBarVisible;
                                });
                              },
                              child: SafeArea(
                                child: PhotoView(
                                  imageProvider: cruise.imageFor(photo),
                                  initialScale: PhotoViewComputedScale.contained,
                                  minScale: PhotoViewComputedScale.contained,
                                  heroTag: tag,
                                  loadingChild: Stack(
                                    children: <Widget>[
                                      Center(
                                        child: Hero(
                                          tag: tag,
                                          child: Image(image: thumbnail),
                                        ),
                                      ),
                                      const PositionedDirectional(
                                        top: 12.0,
                                        end: 12.0,
                                        child: CircularProgressIndicator(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0.0,
                              left: 0.0,
                              right: 0.0,
                              child: AnimatedOpacity(
                                opacity: appBarVisible ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.fastOutSlowIn,
                                child: AppBar(
                                  backgroundColor: Colors.transparent,
                                  brightness: Brightness.dark,
                                  iconTheme: const IconThemeData(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ));
            },
            child: Hero(
              tag: tag,
              child: Image(image: thumbnail, height: maxHeight),
            ),
          ),
        ),
      ),
    );
  }
}

final Path _topSemicircle = Path()..arcTo(Rect.fromLTWH(0.0, 0.0, 1.0, 2.0), 0, -math.pi, true);
final Path _bottomSemicircle = Path()..arcTo(Rect.fromLTWH(0.0, -1.0, 1.0, 2.0), 0, math.pi, true);
final Path _topLeftQuarter = Path()..arcTo(Rect.fromLTWH(0.0, 0.0, 2.0, 2.0), -math.pi, math.pi/2.0, true)..lineTo(1.0, 1.0);
final Path _topRightQuarter = Path()..arcTo(Rect.fromLTWH(-1.0, 0.0, 2.0, 2.0), -math.pi/2.0, math.pi/2.0, true)..lineTo(0.0, 1.0);
final Path _bottomLeftQuarter = Path()..arcTo(Rect.fromLTWH(0.0, -1.0, 2.0, 2.0), math.pi/2.0, math.pi/2.0, true)..lineTo(1.0, 0.0);
final Path _bottomRightQuarter = Path()..arcTo(Rect.fromLTWH(-1.0, -1.0, 2.0, 2.0), 0, math.pi/2.0, true)..lineTo(0.0, 0.0);

class PathBorder extends ShapeBorder {
  const PathBorder(this.path);

  final Path path;

  static Path _scaled(Path path, Rect rect) {
    return Path()..addPath(path, rect.topLeft, matrix4: Matrix4.diagonal3Values(rect.width, rect.height, 1.0).storage);
  }

  @override
  Path getInnerPath(Rect rect, { TextDirection textDirection }) => _scaled(path, rect);

  @override
  Path getOuterPath(Rect rect, { TextDirection textDirection }) => _scaled(path, rect);

  @override
  ShapeBorder scale(double t) => this;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  void paint(Canvas canvas, Rect rect, { TextDirection textDirection }) { }
}

typedef ModeratorBuilderCallback = Widget Function(BuildContext context, AuthenticatedUser user, bool canModerate, bool isModerating);

class ModeratorBuilder extends StatelessWidget {
  const ModeratorBuilder({
    Key key,
    this.builder,
    this.includeBorder = true,
  }) : super(key: key);

  final ModeratorBuilderCallback builder;
  final bool includeBorder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProgressValue<AuthenticatedUser>>(
      valueListenable: Cruise.of(context).user.best,
      builder: (BuildContext context, ProgressValue<AuthenticatedUser> userProgress, Widget child) {
        final AuthenticatedUser user = userProgress is SuccessfulProgress<AuthenticatedUser> ? userProgress.value : null;
        bool canModerate = false;
        if (user != null) {
          switch (user.role) {
            case Role.admin:
            case Role.tho:
            case Role.moderator:
              canModerate = true;
              break;
            case Role.user:
            case Role.muted:
            case Role.banned:
            case Role.none:
              break;
          }
        }
        final bool isModerating = canModerate && user.credentials.asMod;
        Widget result = builder(context, user, canModerate, isModerating);
        if (includeBorder) {
          result = ModeratorBorder(
            isModerating: isModerating,
            child: result,
          );
        }
        return result;
      },
    );
  }
}

class ModeratorBorder extends StatelessWidget {
  const ModeratorBorder({
    Key key,
    this.isModerating,
    this.child,
  }) : super(key: key);

  final bool isModerating;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      decoration: BoxDecoration(
        border: Border.all(
          width: isModerating ? 12.0 : 0,
          color: Theme.of(context).accentColor,
        ),
      ),
      child: child,
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String message, { String yes = 'YES', String no = 'NO', }) async {
  return await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(message),
      actions: <Widget>[
        FlatButton(
          onPressed: () { Navigator.of(context).pop(true); },
          child: Text(yes),
        ),
        FlatButton(
          onPressed: () { Navigator.of(context).pop(false); },
          child: Text(no),
        ),
      ],
    ),
  ) == true;
}