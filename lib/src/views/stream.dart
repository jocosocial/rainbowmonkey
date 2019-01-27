import 'package:flutter/material.dart';

import '../logic/stream.dart';
import '../widgets.dart';

class TweetStreamView extends StatefulWidget {
  const TweetStreamView({
    Key key,
  }) : super(key: key);

  @override
  State<TweetStreamView> createState() => _TweetStreamViewState();
}

class _TweetStreamViewState extends State<TweetStreamView> with TickerProviderStateMixin<TweetStreamView> {

  final Map<String, Animation<double>> _animations = <String, Animation<double>>{};
  final List<AnimationController> _controllers = <AnimationController>[];

  ScrollController _scrollController;
  AnimationController _currentController;
  Animation<double> _currentAnimation;
  TweetStream _stream;

  bool get _atZero => _scrollController.position.pixels <= 0.0;

  Animation<double> _animationFor(StreamPost post) {
    if (post == null)
      return null;
    return _animations.putIfAbsent(post.id, () {
      if (_stream.postIsNew(post)) {
        if (_currentAnimation == null) {
          assert(_currentController == null);
          _currentController = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 250),
          );
          if (_atZero)
            _currentController.forward();
          _controllers.add(_currentController);
          _currentAnimation = _currentController.drive(CurveTween(curve: Curves.fastOutSlowIn));
        }
        return _currentAnimation;
      }
      return const AlwaysStoppedAnimation<double>(1.0);
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(_scrolled);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TweetStream newStream = Cruise.of(context).createTweetStream();
    if (newStream != _stream) {
      if (_scrollController.hasClients)
        _scrollController.jumpTo(0.0);
      _stream = newStream;
      _stream.pin(false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (AnimationController controller in _controllers)
      controller.dispose();
    super.dispose();
  }

  void _scrolled() {
    if (_atZero) {
      _currentController?.forward();
      _currentController = null;
      _currentAnimation = null;
      _stream.pin(false);
    } else {
      _stream.pin(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twitarr'),
        // TODO(ianh): add a manual refresh button that shows when we're busy
        // TODO(ianh): (or find another way to use _stream.busy)
      ),
      body: AnimatedBuilder(
        animation: _stream,
        builder: (BuildContext context, Widget child) {
          return ListView.custom(
            controller: _scrollController,
            reverse: true,
            cacheExtent: 1000.0,
            childrenDelegate: _SliverChildBuilderDelegate(
              builder: (BuildContext context, int index) {
                final StreamPost post = _stream[index];
                if (post == const StreamPost.sentinel())
                  return null;
                return Entry(post: post, animation: _animationFor(post));
                // TODO(ianh): add a text field at the bottom, for sending posts
              },
              onDidFinishLayout: () {
                if (_atZero) {
                  _currentController = null;
                  _currentAnimation = null;
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _SliverChildBuilderDelegate extends SliverChildBuilderDelegate {
  _SliverChildBuilderDelegate({
    IndexedWidgetBuilder builder,
    this.onDidFinishLayout,
  }) : super(builder);

  final VoidCallback onDidFinishLayout;

  @override
  void didFinishLayout(int firstIndex, int lastIndex) {
    super.didFinishLayout(firstIndex, lastIndex);
    if (onDidFinishLayout != null)
      onDidFinishLayout();
  }
}

class Entry extends StatelessWidget {
  const Entry({
    Key key,
    @required this.post,
    @required this.animation,
  }) : assert(post == null || animation != null),
       super(key: key);

  final StreamPost post;

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    if (post == null) {
      return ListTile(
        leading: const Icon(Icons.more_vert),
        title: const Text('...'),
      );
    }
    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: -1.0,
      child: ChatLine(
        user: post.user,
        isCurrentUser: false, // TODO(ianh): determine if it's the current user
        messages: <String>[ post.text ],
        timestamp: post.timestamp,
      ),
    );
  }
}