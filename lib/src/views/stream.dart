import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../logic/photo_manager.dart';
import '../logic/stream.dart';
import '../models/string.dart';
import '../models/user.dart';
import '../progress.dart';
import '../widgets.dart';
import 'attach_image.dart';

class _PendingSend {
  _PendingSend(this.progress, this.text, this.photo);
  final Progress<void> progress;
  final String text;
  final Uint8List photo;
  String error;
}

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

  Uint8List _photo;

  ScrollController _scrollController;
  AnimationController _currentController;
  Animation<double> _currentAnimation;
  TweetStream _stream;

  final TextEditingController _textController = TextEditingController();
  final List<_PendingSend> _pending = <_PendingSend>[];

  void _submitMessage(String value, Uint8List photo) {
    final Progress<void> progress = _stream.send(text: value, photo: photo);
    final _PendingSend entry = _PendingSend(progress, value, photo);
    setState(() {
      _pending.add(entry);
      progress.asFuture().then(
        (void value) {
          setState(() {
            _pending.remove(entry);
          });
        },
        onError: (dynamic error, StackTrace stack) { },
      );
    });
  }

  void _submitCurrentMessage() {
    _submitMessage(_textController.text, _photo);
    setState(() {
      _textController.clear();
      _photo = null;
    });
  }

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TweetStream newStream = Cruise.of(context).tweetStream;
    if (newStream != _stream) {
      _scrollController?.dispose();
      _scrollController = ScrollController()
        ..addListener(_scrolled);
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
    final bool loggedIn = Cruise.of(context).isLoggedIn;
    final bool canPost = loggedIn && _textController.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twitarr'),
        actions: <Widget>[
          ValueListenableBuilder<bool>(
            valueListenable: _stream.active,
            builder: (BuildContext context, bool active, Widget child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Force refresh',
                onPressed: active ? null : _stream.reload,
              );
            },
          ),
        ],
      ),
      body: ModeratorBuilder(
        builder: (BuildContext context, AuthenticatedUser currentUser, bool canModerate, bool isModerating) {
          return BusyIndicator(
            busy: _stream.busy,
            child: AnimatedBuilder(
              animation: _stream,
              builder: (BuildContext context, Widget child) {
                return ListView.custom(
                  key: ObjectKey(_stream),
                  controller: _scrollController,
                  reverse: true,
                  cacheExtent: 1000.0,
                  padding: EdgeInsets.only(top: 8.0, bottom: MediaQuery.of(context).padding.bottom),
                  childrenDelegate: _SliverChildBuilderDelegate(
                    builder: (BuildContext context, int index) {
                      if (index == 0) {
                        return Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                maxLength: 2000,
                                textCapitalization: TextCapitalization.sentences,
                                onChanged: (String value) {
                                  setState(() {
                                    // changed state is in _textController
                                    assert(_textController.text == value);
                                  });
                                },
                                onSubmitted: canPost ? (String value) {
                                  assert(_textController.text == value);
                                  _submitCurrentMessage();
                                } : null,
                                textInputAction: TextInputAction.send,
                                enabled: loggedIn,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsetsDirectional.fromSTEB(12.0, 16.0, 8.0, 16.0),
                                  counterText: '',
                                  hintText: !loggedIn ? 'Log in to send messages'
                                          : _photo != null ? 'Image caption${ isModerating ? " (as moderator)" : ""}'
                                          : 'Message${ isModerating ? " (as moderator)" : ""}',
                                ),
                              ),
                            ),
                            AttachImageButton(
                              images: _photo == null ? null : <Uint8List>[ _photo ],
                              onUpdate: (List<Uint8List> newPhotos) {
                                setState(() {
                                  _photo = newPhotos.isEmpty ? null : newPhotos.single;
                                });
                              },
                              allowMultiple: false,
                            ),
                            IconButton(
                              icon: const Icon(Icons.send),
                              tooltip: 'Send message{ isModerating ? " (as moderator)" : ""}',
                              onPressed: canPost ? _submitCurrentMessage : null,
                            ),
                          ],
                        );
                      }
                      if (index == 1)
                        return const Divider(height: 0.0);
                      index -= 2;
                      if (index < _pending.length) {
                        final _PendingSend entry = _pending[index];
                        return ProgressChatLine(
                          key: ObjectKey(entry),
                          progress: entry.progress,
                          text: entry.text,
                          photos: entry.photo != null ? <Uint8List>[ entry.photo ] : null,
                          onRetry: () {
                            setState(() {
                              _pending.remove(entry);
                              _submitMessage(entry.text, entry.photo);
                            });
                          },
                          onRemove: () {
                            setState(() {
                              _pending.remove(entry);
                            });
                          },
                        );
                      }
                      index -= _pending.length;
                      final StreamPost post = _stream[index];
                      if (post == const StreamPost.sentinel())
                        return null;
                      if (post != null && post.isDeleted)
                        return const SizedBox(height: 0.0);
                      return Entry(
                        post: post,
                        animation: _animationFor(post),
                        effectiveCurrentUser: currentUser?.effectiveUser,
                        stream: _stream,
                        canModerate: canModerate,
                        isModerating: isModerating,
                        canAlwaysEdit: currentUser != null && currentUser.canAlwaysEdit,
                      );
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
    @required this.effectiveCurrentUser,
    @required this.stream,
    @required this.isModerating,
    @required this.canModerate,
    @required this.canAlwaysEdit,
  }) : assert(post == null || animation != null),
       assert(stream != null),
       assert(isModerating != null),
       assert(canModerate != null),
       assert(canAlwaysEdit != null),
       super(key: key);

  final StreamPost post;

  final Animation<double> animation;

  final User effectiveCurrentUser;

  final TweetStream stream;

  final bool canModerate;

  final bool isModerating;

  final bool canAlwaysEdit;

  @override
  Widget build(BuildContext context) {
    if (post == null) {
      return const ListTile(
        leading: Icon(Icons.more_vert),
        title: Text('...'),
      );
    }
    final bool isCurrentUser = post.user.sameAs(effectiveCurrentUser);

    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: -1.0,
      child: ChatLine(
        user: post.user,
        isCurrentUser: isCurrentUser,
        messages: <TwitarrString>[ post.text ],
        photos: post.photo != null ? <Photo>[ post.photo, ] : null,
        id: post.id,
        isReply: post.hasParents,
        likes: post.reactions.likes,
        onLike: effectiveCurrentUser != null && (!isModerating && !post.reactions.currentUserLiked && (!post.isLocked || canModerate)) ? () {
          ProgressDialog.show<void>(context, stream.react(post.id, 'like', selected: true));
        } : null,
        onUnlike: effectiveCurrentUser != null && (!isModerating && post.reactions.currentUserLiked && (!post.isLocked || canModerate)) ? () {
          ProgressDialog.show<void>(context, stream.react(post.id, 'like', selected: false));
        } : null,
        getLikesCallback: () => stream.getReactions(post.id, 'like'),
        timestamp: post.timestamp,
        onReply: effectiveCurrentUser != null ? () => TweetThreadView.open(context, post.id, reply: true) : null,
        onPressed: () => TweetThreadView.open(context, post.id),
        onDelete: effectiveCurrentUser != null && ((isCurrentUser && !post.isLocked) || canModerate) ? () {
          ProgressDialog.show<void>(context, stream.delete(post.id));
        } : null,
        onLock: effectiveCurrentUser != null && (canModerate && !post.isLocked) ? () {
          ProgressDialog.show<void>(context, stream.lock(post.id, locked: true));
        } : null,
        onUnlock: effectiveCurrentUser != null && (canModerate && post.isLocked) ? () {
          ProgressDialog.show<void>(context, stream.lock(post.id, locked: false));
        } : null,
        onEdit: effectiveCurrentUser != null && ((isCurrentUser && (!post.isLocked || canModerate)) || canAlwaysEdit) ? () {
          EditTweetView.open(context, stream, post);
        } : null,
      ),
    );
  }
}

class TweetThreadView extends StatefulWidget {
  const TweetThreadView({
    Key key,
    this.threadId,
    this.reply = false,
  }) : assert(reply != null),
       super(key: key);

  final String threadId;

  final bool reply;

  static Future<void> open(BuildContext context, String threadId, { bool replace = false, bool reply = false }) {
    final Route<void> route = MaterialPageRoute<void>(
      builder: (BuildContext context) => TweetThreadView(threadId: threadId, reply: reply),
    );
    if (replace)
      return Navigator.pushReplacement(context, route);
    return Navigator.push(context, route);
  }

  @override
  State<TweetThreadView> createState() => _TweetThreadViewState();
}

class _TweetThreadViewState extends State<TweetThreadView> {
  TweetStream _stream;
  Progress<StreamPost> _thread;
  List<FlatStreamPost> _flatList;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TweetStream newStream = Cruise.of(context).tweetStream;
    if (newStream != _stream) {
      _stream = newStream;
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _flatList = null;
      _thread = _stream.fetchFullThread(widget.threadId);
    });
  }

  static List<FlatStreamPost> _flatten(StreamPost post) {
    final List<FlatStreamPost> result = <FlatStreamPost>[];
    _flattenWalker(post, 0, result, last: false);
    return result;
  }

  static void _flattenWalker(StreamPost root, int depth, List<FlatStreamPost> output, { @required bool last }) {
    output.insert(
      0,
      FlatStreamPost(
        post: root,
        depth: depth,
        isLast: last,
      ),
    );
    if (root.children == null)
      return;
    assert(root.children.isNotEmpty);
    depth += 1;
    for (int index = 0; index < root.children.length; index += 1)
      _flattenWalker(root.children[index], depth, output, last: index == root.children.length - 1);
  }

  Uint8List _photo;
  final TextEditingController _textController = TextEditingController();
  final List<_PendingSend> _pending = <_PendingSend>[];

  void _submitMessage(String value, Uint8List photo) {
    final Progress<void> progress = _stream.send(text: value, photo: photo, parentId: widget.threadId);
    final _PendingSend entry = _PendingSend(progress, value, photo);
    setState(() {
      _pending.add(entry);
      progress.asFuture().then(
        (void value) {
          setState(() {
            _pending.remove(entry);
            _reload();
          });
        },
        onError: (dynamic error, StackTrace stack) { },
      );
    });
  }

  void _submitCurrentMessage() {
    _submitMessage(_textController.text, _photo);
    setState(() {
      _textController.clear();
      _photo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twitarr Thread'),
        actions: <Widget>[
          ValueListenableBuilder<bool>(
            valueListenable: _stream.active,
            builder: (BuildContext context, bool active, Widget child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Force refresh',
                onPressed: active ? null : _reload,
              );
            },
          ),
        ],
      ),
      body: ModeratorBuilder(
        builder: (BuildContext context, AuthenticatedUser currentUser, bool canModerate, bool isModerating) {
          return ProgressBuilder<StreamPost>(
            progress: _thread,
            builder: (BuildContext context, StreamPost post) {
              if (!_initialized) {
                _initialized = true;
                if (widget.reply)
                  _textController.text = '@${post.user.username} ${_textController.text}';
              }
              _flatList ??= _flatten(post); // this list is "in reverse", index 0 is the newest
              final bool loggedIn = Cruise.of(context).isLoggedIn;
              final bool canPostInPrinciple = loggedIn && (post.isLocked ? currentUser.canPostWhenLocked : currentUser.canPost);
              final bool canPost = canPostInPrinciple && _textController.text.trim().isNotEmpty;
              return SafeArea(
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: ListView.builder(
                        key: ObjectKey(post),
                        reverse: true,
                        itemCount: _flatList.length + _pending.length + (post.parents != null ? 1 : 0),
                        itemBuilder: (BuildContext context, int index) {
                          if (index < _pending.length) {
                            final _PendingSend entry = _pending[index];
                            return ProgressChatLine(
                              key: ObjectKey(entry),
                              progress: entry.progress,
                              text: entry.text,
                              photos: entry.photo != null ? <Uint8List>[ entry.photo ] : null,
                              onRetry: () {
                                setState(() {
                                  _pending.remove(entry);
                                  _submitMessage(entry.text, entry.photo);
                                });
                              },
                              onRemove: () {
                                setState(() {
                                  _pending.remove(entry);
                                });
                              },
                            );
                          }
                          index -= _pending.length;
                          if (index < _flatList.length) {
                            return NestedEntry(
                              details: _flatList[index],
                              canModerate: canModerate,
                              isModerating: isModerating,
                              canAlwaysEdit: currentUser != null && currentUser.canAlwaysEdit,
                              effectiveCurrentUser: currentUser?.effectiveUser,
                              stream: _stream,
                              onChanged: (bool deleted) {
                                if (deleted && index == _flatList.length - 1) {
                                  Navigator.pop(context);
                                } else {
                                  _reload();
                                }
                              },
                            );
                          }
                          assert(post.parents.isNotEmpty);
                          return ListTile(
                            leading: const Icon(Icons.arrow_upward),
                            title: const Text('Open parent...'),
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) => TweetThreadView(threadId: post.parents.last),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(height: 0.0),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            maxLength: 2000,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (String value) {
                              setState(() {
                                // changed state is in _textController
                                assert(_textController.text == value);
                              });
                            },
                            onSubmitted: canPost ? (String value) {
                              assert(_textController.text == value);
                              _submitCurrentMessage();
                            } : null,
                            textInputAction: TextInputAction.send,
                            enabled: canPostInPrinciple,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: const EdgeInsetsDirectional.fromSTEB(12.0, 16.0, 8.0, 16.0),
                              counterText: '',
                              hintText: !loggedIn ? 'Log in to send messages'
                                      : post.isLocked ? 'Thread locked'
                                      : _photo != null ? 'Image caption${ isModerating ? " (as moderator)" : ""}'
                                      : 'Message${ isModerating ? " (as moderator)" : ""}',
                            ),
                          ),
                        ),
                        AttachImageButton(
                          images: _photo == null ? null : <Uint8List>[ _photo ],
                          enabled: canPostInPrinciple,
                          onUpdate: (List<Uint8List> newPhotos) {
                            setState(() {
                              _photo = newPhotos.isEmpty ? null : newPhotos.single;
                            });
                          },
                          allowMultiple: false,
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          tooltip: 'Send message{ isModerating ? " (as moderator)" : ""}',
                          onPressed: canPost ? _submitCurrentMessage : null,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FlatStreamPost {
  const FlatStreamPost({
    this.post,
    this.depth,
    this.isLast,
  });

  final StreamPost post;
  final int depth;
  final bool isLast;
}

class NestedEntry extends StatelessWidget {
  const NestedEntry({
    Key key,
    @required this.details,
    @required this.effectiveCurrentUser,
    @required this.stream,
    @required this.canModerate,
    @required this.isModerating,
    @required this.canAlwaysEdit,
    @required this.onChanged,
  }) : assert(details != null),
       assert(canModerate != null),
       assert(isModerating != null),
       assert(canAlwaysEdit != null),
       super(key: key);

  final FlatStreamPost details;

  final User effectiveCurrentUser;

  final TweetStream stream;

  final bool canModerate;

  final bool isModerating;

  final bool canAlwaysEdit;

  final ValueSetter<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUser = details.post.user.sameAs(effectiveCurrentUser);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        math.min(details.depth, 6) * 24.0,
        0.0,
        0.0,
        details.isLast ? 4.0 : 0.0,
      ),
      child: ChatLine(
        user: details.post.user,
        isCurrentUser: false, // because otherwise the nesting becomes meaningless
        messages: <TwitarrString>[ details.post.text ],
        photos: details.post.photo != null ? <Photo>[ details.post.photo, ] : null,
        id: details.post.id,
        likes: details.post.reactions.likes,
        onLike: effectiveCurrentUser != null && (!isModerating && !details.post.reactions.currentUserLiked && (!details.post.isLocked || canModerate)) ? () {
          ProgressDialog.show<void>(context, stream.react(details.post.id, 'like', selected: true));
          if (onChanged != null)
            onChanged(false);
        } : null,
        onUnlike: effectiveCurrentUser != null && (!isModerating && details.post.reactions.currentUserLiked && (!details.post.isLocked || canModerate)) ? () {
          ProgressDialog.show<void>(context, stream.react(details.post.id, 'like', selected: false));
          if (onChanged != null)
            onChanged(false);
        } : null,
        getLikesCallback: () => stream.getReactions(details.post.id, 'like'),
        timestamp: details.post.timestamp,
        onDelete: effectiveCurrentUser != null && ((isCurrentUser && !details.post.isLocked) || canModerate) ? () async {
          await ProgressDialog.show<void>(context, stream.delete(details.post.id));
          if (onChanged != null)
            onChanged(true);
        } : null,
        onReply: effectiveCurrentUser != null && (details.depth > 0) ? () => TweetThreadView.open(context, details.post.id, replace: true, reply: true) : null,
        onPressed: details.depth > 0 ? () => TweetThreadView.open(context, details.post.id, replace: true) : null,
        onLock: effectiveCurrentUser != null && (canModerate && !details.post.isLocked) ? () {
          ProgressDialog.show<void>(context, stream.lock(details.post.id, locked: true));
          if (onChanged != null)
            onChanged(false);
        } : null,
        onUnlock: effectiveCurrentUser != null && (canModerate && details.post.isLocked) ? () {
          ProgressDialog.show<void>(context, stream.lock(details.post.id, locked: false));
          if (onChanged != null)
            onChanged(false);
        } : null,
        onEdit: effectiveCurrentUser != null && ((isCurrentUser && (!details.post.isLocked || canModerate)) || canAlwaysEdit) ? () {
          EditTweetView.open(context, stream, details.post);
        } : null,
      ),
    );
  }
}

class EditTweetView extends StatefulWidget {
  const EditTweetView({
    Key key,
    this.stream,
    this.post,
  }) : super(key: key);

  final TweetStream stream;
  final StreamPost post;

  static Future<void> open(BuildContext context, TweetStream stream, StreamPost post) {
    return Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => EditTweetView(
          stream: stream,
          post: post,
        ),
      ),
    );
  }

  @override
  _EditTweetViewState createState() => _EditTweetViewState();
}

class _EditTweetViewState extends State<EditTweetView> {
  final TextEditingController _text = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  List<Photo> _keptPhotos = <Photo>[];
  List<Uint8List> _newPhotos = <Uint8List>[];

  @override
  void initState() {
    super.initState();
    _text.text = widget.post.text.encodedValue;
    _keptPhotos = widget.post.photo != null ? <Photo>[widget.post.photo] : const <Photo>[];
  }

  void _commit() async {
    final Progress<void> progress = widget.stream.edit(
      postId: widget.post.id,
      text: _text.text,
      keptPhotos: _keptPhotos,
      newPhotos: _newPhotos,
    );
    await ProgressDialog.show<void>(context, progress);
    if (progress.value is SuccessfulProgress<void> && mounted)
      Navigator.pop(context);
  }

  bool get _valid => _text.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit'),
      ),
      floatingActionButton: _valid
        ? FloatingActionButton(
            child: const Icon(Icons.send),
            onPressed: _commit,
          )
        : FloatingActionButton(
            child: const Icon(Icons.send),
            onPressed: null,
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.grey.shade400,
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: ModeratorBuilder(
        builder: (BuildContext context, User currentUser, bool canModerate, bool isModerating) {
          return Form(
            key: _formKey,
            onChanged: () {
              setState(() {
                /* need to recheck whether the submit button should be enabled */
              });
            },
            onWillPop: () => confirmDialog(context, 'Abandon editing this post?'),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: TextFormField(
                      controller: _text,
                      onFieldSubmitted: (String value) {
                        if (_valid)
                          _commit();
                      },
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 10000,
                      maxLines: null,
                      decoration: const InputDecoration(
                        labelText: 'Post text',
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
                    child: AttachImageDialog(
                      oldImages: _keptPhotos,
                      onUpdateOldImages: (List<Photo> newKeptPhotos) {
                        setState(() {
                          _keptPhotos = newKeptPhotos;
                        });
                      },
                      images: _newPhotos,
                      onUpdate: (List<Uint8List> newPhotos) {
                        setState(() {
                          _newPhotos = newPhotos;
                        });
                      },
                      allowMultiple: false,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
