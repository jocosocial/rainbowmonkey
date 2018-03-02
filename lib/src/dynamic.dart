import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'network/network.dart';

abstract class DynamicView<T> extends StatefulWidget {
  const DynamicView({
    Key key,
    @required this.twitarr,
  }) : assert(twitarr != null),
       super(key: key);

  final Twitarr twitarr;
}

abstract class DynamicViewState<T, W extends DynamicView<T>> extends State<W> {
  T _data;

  ValueListenable<T> getDataSource(Twitarr twitarr);
  Widget buildView(BuildContext context, T data);

  @override
  void initState() {
    super.initState();
    final ValueListenable<T> source = getDataSource(widget.twitarr)
      ..addListener(_updateData);
    _data = source.value;
  }

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.twitarr != oldWidget.twitarr) {
      getDataSource(oldWidget.twitarr).removeListener(_updateData);
      getDataSource(widget.twitarr).addListener(_updateData);
    }
  }

  @override
  void dispose() {
    getDataSource(widget.twitarr).removeListener(_updateData);
    super.dispose();
  }

  void _updateData() {
    setState(() {
      _data = getDataSource(widget.twitarr).value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return new LoadingScreen(
      ready: _data != null,
      builder: (BuildContext context) => buildView(context, _data),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({
    Key key,
    @required this.ready,
    @required this.builder,
  }) : super(key: key);

  final bool ready;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return new AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      firstChild: const Center(child: const CircularProgressIndicator()),
      secondChild: ready ? builder(context) : new Container(),
      crossFadeState: ready ? CrossFadeState.showSecond : CrossFadeState.showFirst,
    );
  }
}
