import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logic/forums.dart';
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
        setState(() {
          _pending.remove(entry);
        });
      }, onError: (dynamic error, StackTrace stack) {
        setState(() {
          entry.error = error.toString();
        });
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.thread.subject),
      ),
      body: ModeratorBuilder(
        builder: (BuildContext context, AuthenticatedUser currentUser, bool canModerate, bool isModerating) {
          final bool canPostInPrinciple = loggedIn && (widget.thread.locked ? currentUser.canPostWhenLocked : currentUser.canPost);
          final bool canPost = canPostInPrinciple && _textController.text.isNotEmpty;
          return Column(
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
                          child: Text(widget.thread.subject, textAlign: TextAlign.center, style: Theme.of(context).textTheme.title),
                        );
                      }
                      final ForumMessage message = messages[index];
                      return ChatLine(
                        user: message.user,
                        isCurrentUser: message.user.sameAs(currentUser?.effectiveUser),
                        messages: <String>[ message.text ],
                        photos: message.photos,
                        timestamp: message.timestamp,
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
                        if (_textController.text.isNotEmpty)
                          _submitCurrentMessage();
                      } : null,
                      textInputAction: TextInputAction.send,
                      maxLength: 10000,
                      enabled: canPostInPrinciple,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsetsDirectional.fromSTEB(12.0, 16.0, 8.0, 16.0),
                        counter: const SizedBox.shrink(),
                        hintText: !loggedIn ? 'Log in to send messages'
                                : widget.thread.locked ? 'Forum locked'
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
          );
        },
      ),
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
    return _subject.text.isNotEmpty
        && _text.text.isNotEmpty;
  }

  void _send() async {
    final Progress<ForumThread> progress = Cruise.of(context).forums.postThread(
      subject: _subject.text,
      text: _text.text,
      photos: _photos.isEmpty ? null : _photos,
    );
    final ForumThread thread = await showDialog<ForumThread>(
      context: context,
      builder: (BuildContext context) => ProgressDialog<ForumThread>(
        progress: progress,
      ),
    );
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
            onWillPop: () async {
              return await showDialog<bool>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('Abandon creating this forum?'),
                  actions: <Widget>[
                    FlatButton(
                      onPressed: () { Navigator.of(context).pop(true); },
                      child: const Text('YES'),
                    ),
                    FlatButton(
                      onPressed: () { Navigator.of(context).pop(false); },
                      child: const Text('NO'),
                    ),
                  ],
                ),
              ) == true;
            },
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
                      textInputAction: TextInputAction.send,
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
