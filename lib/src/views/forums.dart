import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logic/forums.dart';
import '../models/user.dart';
import '../progress.dart';
import '../widgets.dart';

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
  _PendingSend(this.progress, this.text);
  final Progress<void> progress;
  final String text;
  String error;
}

class _ForumThreadViewState extends State<ForumThreadView> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final Set<_PendingSend> _pending = Set<_PendingSend>();

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

  void _submitMessage(String value) {
    final Progress<void> progress = widget.thread.send(value);
    final _PendingSend entry = _PendingSend(progress, value);
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
    _submitMessage(_textController.text);
    setState(_textController.clear);
  }

  @override
  Widget build(BuildContext context) {
    final List<ForumMessage> messages = widget.thread.toList().reversed.toList() ?? const <ForumMessage>[];
    final bool loggedIn = Cruise.of(context).isLoggedIn;
    final bool canPost = loggedIn && _textController.text.isNotEmpty; // TODO(ianh): or image selected
    return ValueListenableBuilder<ProgressValue<AuthenticatedUser>>(
      valueListenable: Cruise.of(context).user.best,
      builder: (BuildContext context, ProgressValue<AuthenticatedUser> user, Widget child) {
        User currentUser;
        if (user is SuccessfulProgress<AuthenticatedUser>)
          currentUser = user.value;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.thread.subject),
          ),
          body: Column(
            children: <Widget>[
              Expanded(
                child: BusyIndicator(
                  busy: widget.thread.busy,
                  child: ListView.builder(
                    reverse: true,
                    itemBuilder: (BuildContext context, int index) {
                      final ForumMessage message = messages[index];
                      return ChatLine(
                        user: message.user,
                        isCurrentUser: message.user.sameAs(currentUser),
                        messages: <String>[ message.text ],
                        timestamp: message.timestamp,
                      );
                    },
                    itemCount: messages.length,
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
                    onRetry: () {
                      setState(() {
                        _pending.remove(entry);
                        _submitMessage(entry.text);
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
                      enabled: loggedIn,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsetsDirectional.fromSTEB(12.0, 16.0, 8.0, 16.0),
                        hintText: loggedIn ? 'Message' : 'Log in to send messages',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    tooltip: 'Send message',
                    onPressed: canPost ? _submitCurrentMessage : null,
                  ),
                ],
              ),
            ],
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

  bool get _valid {
    return _subject.text.isNotEmpty
        && _text.text.isNotEmpty;
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
            onPressed: () async {
              final Progress<ForumThread> progress = Cruise.of(context).forums.postThread(
                subject: _subject.text,
                text: _text.text,
              );
              final ForumThread thread = await showDialog<ForumThread>(
                context: context,
                builder: (BuildContext context) => ProgressDialog<ForumThread>(
                  progress: progress,
                ),
              );
              if (mounted && thread != null)
                Navigator.pop(context, thread);
            },
          )
        : FloatingActionButton(
            child: const Icon(Icons.send),
            onPressed: null,
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.grey.shade400,
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: Form(
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
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12.0, 20.0, 12.0, 0.0),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: TextFormField(
                    controller: _subject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: TextFormField(
                    controller: _text,
                    decoration: const InputDecoration(
                      labelText: 'First message',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
