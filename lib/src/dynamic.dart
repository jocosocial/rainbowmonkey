import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'network/network.dart';
import 'progress.dart';

abstract class DynamicView<T> extends StatefulWidget {
  const DynamicView({
    Key key,
    @required this.twitarr,
  }) : assert(twitarr != null),
       super(key: key);

  final Twitarr twitarr;
}

abstract class DynamicViewState<T, W extends DynamicView<T>> extends State<W> {
  ProgressValueListenable<T> _liveData;
  ProgressValueListenable<T> _bestData;

  ProgressValueListenable<T> getDataSource(Twitarr twitarr);
  Widget buildView(BuildContext context, T data);

  @override
  void initState() {
    super.initState();
    _updateSource();
  }

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.twitarr != oldWidget.twitarr)
      _updateSource();
  }

  @override
  void dispose() {
    _liveData.removeListener(_updateData);
    _bestData = null;
    super.dispose();
  }

  void _updateSource() {
    _liveData?.removeListener(_updateData);
    _liveData = getDataSource(widget.twitarr)
      ..addListener(_updateData);
    if (_bestData == null) {
      _bestData = _liveData;
    } else {
      _bestData = new _StaticProgress<T>.from(_bestData);
    }
  }

  void _updateData() {
    setState(() {
      bool newIsBetter;
      assert(_bestData != null);
      switch (_liveData.progressStatus) {
        case ProgressStatus.idle:
          newIsBetter = _bestData.progressStatus == ProgressStatus.idle
                     || _bestData.progressStatus == ProgressStatus.active;
          break;
        case ProgressStatus.active:
        case ProgressStatus.failed:
          newIsBetter = _bestData.progressStatus == ProgressStatus.idle
                     || _bestData.progressStatus == ProgressStatus.active
                     || _bestData.progressStatus == ProgressStatus.failed;
          break;
        case ProgressStatus.complete:
        case ProgressStatus.updating:
          newIsBetter = true;
          break;
      }
      assert(newIsBetter != null);
      if (newIsBetter)
        _bestData = _liveData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return new LoadingScreen(
      progress: _bestData,
      builder: (BuildContext context) => buildView(context, _bestData.value),
    );
  }
}

class _StaticProgress<T> implements ProgressValueListenable<T> {
  _StaticProgress.from(ProgressValueListenable<T> source)
    : assert(source != null),
      _value = source.value,
      _progressStatus = source.progressStatus,
      _progressValue = source.progressValue,
      _progressTarget = source.progressTarget,
      _lastError = source.lastError;

  @override
  T get value => _value;
  T _value;

  @override
  ProgressStatus get progressStatus => _progressStatus;
  ProgressStatus _progressStatus;

  @override
  double get progressValue => _progressValue;
  double _progressValue;

  @override
  double get progressTarget => _progressTarget;
  double _progressTarget;

  @override
  String get lastError => _lastError;
  String _lastError;

  @override
  void updatedProgress() { }

  @override
  void forwardProgress(Progress target) { }

  @override
  void addListener(VoidCallback listener) { }

  @override
  void removeListener(VoidCallback listener) { }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({
    Key key,
    @required this.progress,
    @required this.builder,
  }) : assert(progress != null),
       assert(builder != null),
       super(key: key);

  final Progress progress;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return new AnimatedBuilder(
      animation: progress,
      builder: (BuildContext context, Widget child) {
        bool ready;
        double progressValue;
        assert(progress.progressStatus != null);
        switch (progress.progressStatus) {
          case ProgressStatus.idle:
            throw new StateError('$runtimeType used with idle progress');
          case ProgressStatus.active:
            if (progress.progressTarget > 0.0)
              progressValue = progress.progressValue / progress.progressTarget;
            ready = false;
            break;
          case ProgressStatus.failed:
            ready = false;
            break;
          case ProgressStatus.complete:
            ready = true;
            break;
          case ProgressStatus.updating:
            ready = true;
            if (progress.progressTarget > 0.0)
              progressValue = progress.progressValue / progress.progressTarget;
            break;
        }
        assert(ready != null);
        return new AnimatedCrossFade(
          layoutBuilder: _layoutBuilder,
          duration: const Duration(milliseconds: 200),
          firstChild: new Center(
            child: new CircularProgressIndicator(
              value: progressValue,
            ),
          ),
          secondChild: ready ? builder(context) : new Container(),
          crossFadeState: ready ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        );
      },
    );
  }

  Widget _layoutBuilder(Widget topChild, Key topChildKey, Widget bottomChild, Key bottomChildKey) {
    return new Stack(
      fit: StackFit.expand,
      children: <Widget>[
        new KeyedSubtree(key: bottomChildKey, child: bottomChild),
        new KeyedSubtree(key: topChildKey, child: topChild),
      ],
    );
  }
}
