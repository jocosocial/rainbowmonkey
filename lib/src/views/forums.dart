import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../logic/forums.dart';
import '../logic/photo_manager.dart';
import '../models/string.dart';
import '../models/user.dart';
import '../progress.dart';
import '../widgets.dart';
import 'attach_image.dart';

class ForumThreadView extends StatefulWidget {
  const ForumThreadView({
    Key key,
    @required this.thread,
  }) : assert(thread != null),
       super(key: key);

  final ForumThread thread;

  @override
  _ForumThreadViewState createState() => _ForumThreadViewState();
}

class _PendingSend {
  _PendingSend(this.progress, this.text, this.photos);
  final Progress<void> progress;
  final String text;
  final List<Uint8List> photos;
  String error;
}

class _ForumThreadViewState extends State<ForumThreadView> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final Set<_PendingSend> _pending = <_PendingSend>{};

  List<Uint8List> _photos = <Uint8List>[];

  @override
  void initState() {
    super.initState();
    widget.thread.addListener(_update);
  }

  @override
  void didUpdateWidget(ForumThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.thread != oldWidget.thread) {
      widget.thread.removeListener(_update);
      widget.thread.addListener(_update);
    }
  }

  @override
  void dispose() {
    widget.thread.removeListener(_update);
    super.dispose();
  }

  void _update() {
    setState(() { /* thread updated */ });
  }

  void _submitMessage(String value, { @required List<Uint8List> photos }) {
    final Progress<void> progress = widget.thread.send(value, photos: photos.isEmpty ? null : photos);
    final _PendingSend entry = _PendingSend(progress, value, photos);
    setState(() {
      _pending.add(entry);
      progress.asFuture().then((void value) {
        if (mounted) {
          setState(() {
            _pending.remove(entry);
          });
        }
      }, onError: (dynamic error, StackTrace stack) {
        if (mounted) {
          setState(() {
            entry.error = error.toString();
          });
        }
      });
    });
  }

  void _submitCurrentMessage() {
    _submitMessage(_textController.text, photos: _photos.toList());
    setState(() {
      _textController.clear();
      _photos.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<ForumMessage> messages = widget.thread.toList().reversed.toList() ?? const <ForumMessage>[];
    final bool loggedIn = Cruise.of(context).isLoggedIn;
    return ModeratorBuilder(
      includeBorder: false,
      builder: (BuildContext context, AuthenticatedUser currentUser, bool canModerate, bool isModerating) {
        final bool canPostInPrinciple = loggedIn && (widget.thread.isLocked ? currentUser.canPostWhenLocked : currentUser.canPost);
        final bool canPost = canPostInPrinciple && _textController.text.trim().isNotEmpty;
        final List<Widget> actions = <Widget>[
          ValueListenableBuilder<bool>(
            valueListenable: widget.thread.active,
            builder: (BuildContext context, bool active, Widget child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Force refresh',
                onPressed: active ? null : widget.thread.reload,
              );
            },
          ),
        ];
        final List<PopupMenuEntry<VoidCallback>> menuItems = <PopupMenuEntry<VoidCallback>>[];
        if (currentUser != null) {
          switch (currentUser.role) {
            case Role.admin:
            case Role.tho:
              menuItems.add(
                CheckedPopupMenuItem<VoidCallback>(
                  child: const Text('Sticky'),
                  checked: widget.thread.isSticky,
                  value: () { widget.thread.sticky(sticky: !widget.thread.isSticky); },
                ),
              );
              continue moderator;
            moderator:
            case Role.moderator:
              menuItems.addAll(<PopupMenuEntry<VoidCallback>>[
                CheckedPopupMenuItem<VoidCallback>(
                  child: const Text('Lock'),
                  checked: widget.thread.isLocked,
                  value: () { widget.thread.lock(locked: !widget.thread.isLocked); },
                ),
                const PopupMenuDivider(),
                PopupMenuItem<VoidCallback>(
                  child: const ListTile(
                    leading: Icon(Icons.delete_forever),
                    title: Text('Delete Forum'),
                  ),
                  value: () async {
                    if (await confirmDialog(context, 'Delete "${widget.thread.subject}" forum?', yes: 'DELETE')) {
                      widget.thread.delete();
                      Navigator.pop(context);
                    }
                  },
                ),
              ]);
              continue user;
            user:
            case Role.user:
            case Role.muted:
            case Role.banned:
            case Role.none:
              break;
          }
        }
        if (menuItems.isNotEmpty) {
          actions.add(PopupMenuButton<VoidCallback>(
            onSelected: (VoidCallback callback) {
              callback();
            },
            itemBuilder: (BuildContext context) => menuItems,
            icon: const Icon(Icons.more_vert),
          ));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.thread.subject),
            actions: actions,
          ),
          body: ModeratorBorder(
            isModerating: isModerating,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: BusyIndicator(
                    busy: widget.thread.busy,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 8.0),
                      reverse: true,
                      itemBuilder: (BuildContext context, int index) {
                        // the very first item is the subject.
                        if (index == messages.length) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12.0, 24.0, 12.0, 56.0),
                            child: Text(widget.thread.subject, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headline6),
                          );
                        }
                        if (index == 0) {
                          // when we see the most recent message, mark the thread as read
                          widget.thread.forceRead();
                        }
                        final ForumMessage message = messages[index];
                        final bool isCurrentUser = message.user.sameAs(currentUser?.effectiveUser);
                        return ChatLine(
                          user: message.user,
                          isCurrentUser: isCurrentUser,
                          messages: <TwitarrString>[ message.text ],
                          photos: message.photos,
                          id: message.id,
                          likes: message.reactions.likes,
                          onLike: currentUser != null && (!isModerating && !message.reactions.currentUserLiked && (!widget.thread.isLocked || canModerate)) ? () {
                            ProgressDialog.show<void>(context, widget.thread.react(message.id, 'like', selected: true));
                          } : null,
                          onUnlike: currentUser != null && (!isModerating && message.reactions.currentUserLiked && (!widget.thread.isLocked || canModerate)) ? () {
                            ProgressDialog.show<void>(context, widget.thread.react(message.id, 'like', selected: false));
                          } : null,
                          getLikesCallback: () => widget.thread.getReactions(message.id, 'like'),
                          timestamp: message.timestamp,
                          onDelete: currentUser != null && ((isCurrentUser && !widget.thread.isLocked) || canModerate) ? () async {
                            final bool threadDeleted = await ProgressDialog.show<bool>(context, widget.thread.deleteMessage(message.id));
                            if (threadDeleted)
                              Navigator.pop(context);
                          } : null,
                          onEdit: currentUser != null && ((isCurrentUser && (!widget.thread.isLocked || canModerate)) || currentUser.canAlwaysEdit) ? () {
                            EditForumPostView.open(context, widget.thread, message);
                          } : null,
                        );
                      },
                      itemCount: messages.length + 1,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _pending.map((_PendingSend entry) {
                    return ProgressChatLine(
                      key: ObjectKey(entry),
                      progress: entry.progress,
                      text: entry.text,
                      photos: entry.photos,
                      onRetry: () {
                        setState(() {
                          _pending.remove(entry);
                          _submitMessage(entry.text, photos: entry.photos);
                        });
                      },
                      onRemove: () {
                        setState(() {
                          _pending.remove(entry);
                        });
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 0.0),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        onChanged: (String value) {
                          setState(() {
                            // changed state is in _textController
                            assert(_textController.text == value);
                          });
                        },
                        onSubmitted: canPost ? (String value) {
                          assert(_textController.text == value);
                          if (_textController.text.trim().isNotEmpty)
                            _submitCurrentMessage();
                        } : null,
                        textInputAction: TextInputAction.newline,
                        maxLength: 10000,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: canPostInPrinciple,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: const EdgeInsetsDirectional.fromSTEB(12.0, 16.0, 8.0, 16.0),
                          hintText: !loggedIn ? 'Log in to send messages'
                                  : widget.thread.isLocked ? 'Forum locked'
                                  : _photos.isEmpty ? 'Message${ isModerating ? " (as moderator)" : ""}'
                                  : _photos.length == 1 ? 'Image caption${ isModerating ? " (as moderator)" : ""}'
                                  : 'Image captions${ isModerating ? " (as moderator)" : ""}',
                        ),
                      ),
                    ),
                    AttachImageButton(
                      images: _photos,
                      enabled: canPostInPrinciple,
                      onUpdate: (List<Uint8List> newPhotos) {
                        setState(() {
                          _photos = newPhotos;
                        });
                      },
                      allowMultiple: true,
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      tooltip: 'Send message${ isModerating ? " (as moderator)" : ""}',
                      onPressed: canPost ? _submitCurrentMessage : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StartForumView extends StatefulWidget {
  const StartForumView({
    Key key,
  }) : super(key: key);

  @override
  _StartForumViewState createState() => _StartForumViewState();
}

class _StartForumViewState extends State<StartForumView> {
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _text = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final FocusNode _subjectFocus = FocusNode();
  final FocusNode _firstMessageFocus = FocusNode();

  List<Uint8List> _photos = <Uint8List>[];

  bool get _valid {
    return _subject.text.trim().isNotEmpty
        && _text.text.trim().isNotEmpty;
  }

  void _send() async {
    final Progress<ForumThread> progress = Cruise.of(context).forums.postThread(
      subject: _subject.text,
      text: _text.text,
      photos: _photos.isEmpty ? null : _photos,
    );
    final ForumThread thread = await ProgressDialog.show<ForumThread>(context, progress);
    if (mounted && thread != null)
      Navigator.pop(context, thread);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start forum'),
      ),
      floatingActionButton: _valid
        ? FloatingActionButton(
            child: const Icon(Icons.send),
            onPressed: _send,
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
            onWillPop: () => confirmDialog(context, 'Abandon creating this forum?'),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12.0, 20.0, 12.0, 0.0),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: TextFormField(
                      controller: _subject,
                      focusNode: _subjectFocus,
                      autofocus: true,
                      maxLength: 200,
                      onFieldSubmitted: (String value) {
                        FocusScope.of(context).requestFocus(_firstMessageFocus);
                      },
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: TextFormField(
                      controller: _text,
                      focusNode: _firstMessageFocus,
                      onFieldSubmitted: (String value) {
                        if (_valid)
                          _send();
                      },
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 10000,
                      maxLines: null,
                      decoration: InputDecoration(
                        labelText: 'First message${ isModerating ? " (as moderator)" : ""}',
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
                    child: AttachImageDialog(
                      images: _photos,
                      onUpdate: (List<Uint8List> newImages) {
                        setState(() {
                          _photos = newImages;
                        });
                      },
                      allowMultiple: true,
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

class EditForumPostView extends StatefulWidget {
  const EditForumPostView({
    Key key,
    this.thread,
    this.message,
  }) : super(key: key);

  final ForumThread thread;
  final ForumMessage message;

  static Future<void> open(BuildContext context, ForumThread thread, ForumMessage message) {
    return Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => EditForumPostView(
          thread: thread,
          message: message,
        ),
      ),
    );
  }

  @override
  _EditForumPostViewState createState() => _EditForumPostViewState();
}

class _EditForumPostViewState extends State<EditForumPostView> {
  final TextEditingController _text = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  List<Photo> _keptPhotos = <Photo>[];
  List<Uint8List> _newPhotos = <Uint8List>[];

  @override
  void initState() {
    super.initState();
    _text.text = widget.message.text.encodedValue;
    _keptPhotos = widget.message.photos;
  }

  void _commit() async {
    final Progress<void> progress = widget.thread.edit(
      messageId: widget.message.id,
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
                      textInputAction: TextInputAction.newline,
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
                      allowMultiple: true,
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
