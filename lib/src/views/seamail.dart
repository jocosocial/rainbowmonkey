import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

import '../logic/cruise.dart';
import '../logic/seamail.dart';
import '../models/user.dart';
import '../progress.dart';
import '../widgets.dart';

class SeamailThreadView extends StatefulWidget {
  const SeamailThreadView({
    Key key,
    @required this.thread,
  }) : assert(thread != null),
       super(key: key);

  final SeamailThread thread;

  @override
  _SeamailThreadViewState createState() => _SeamailThreadViewState();
}

class _PendingSend {
  _PendingSend(this.progress, this.text);
  final Progress<void> progress;
  final String text;
  String error;
}

class MessageBubble {
  MessageBubble({ this.user });
  final User user;
  final List<SeamailMessage> messages = <SeamailMessage>[];
}

class _SeamailThreadViewState extends State<SeamailThreadView> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final Set<_PendingSend> _pending = Set<_PendingSend>();

  @override
  void initState() {
    super.initState();
    didChangeAppLifecycleState(SchedulerBinding.instance.lifecycleState);
  }

  bool _listening = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    bool _newState;
    switch (state) {
      case AppLifecycleState.inactive:
        _newState = true;
        break;
      case AppLifecycleState.paused:
        _newState = false;
        break;
      case AppLifecycleState.resumed:
        _newState = true;
        break;
      case AppLifecycleState.suspending:
        _newState = false;
        break;
      default:
        _newState = true; // app probably just started
    }
    if (_newState != _listening) {
      if (_newState) {
        widget.thread.addListener(_update); // this will mark the thread as read when we update
      } else {
        widget.thread.removeListener(_update);
      }
      _listening = _newState;
    }
  }

  @override
  void didUpdateWidget(SeamailThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.thread != oldWidget.thread && _listening) {
      widget.thread.removeListener(_update);
      widget.thread.addListener(_update);
    }
  }

  @override
  void dispose() {
    if (_listening)
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
    final ThemeData theme = Theme.of(context);
    final CruiseModel cruise = Cruise.of(context);
    final List<User> users = widget.thread.users.toList();
    final List<SeamailMessage> messages = widget.thread.getMessages() ?? const <SeamailMessage>[];
    final List<MessageBubble> bubbles = <MessageBubble>[];
    MessageBubble currentBubble = MessageBubble();
    SeamailMessage lastMessage = const SeamailMessage(user: User.none());
    for (SeamailMessage message in messages) {
      if (!message.user.sameAs(lastMessage.user) ||
          message.timestamp.difference(lastMessage.timestamp) > const Duration(minutes: 2)) {
        currentBubble = MessageBubble(user: message.user);
        bubbles.add(currentBubble);
      }
      currentBubble.messages.add(message);
      lastMessage = message;
    }
    return ValueListenableBuilder<ProgressValue<AuthenticatedUser>>(
      valueListenable: Cruise.of(context).user.best,
      builder: (BuildContext context, ProgressValue<AuthenticatedUser> user, Widget child) {
        User currentUser;
        if (user is SuccessfulProgress<AuthenticatedUser>)
          currentUser = user.value;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.thread.subject), // TODO(ianh): faces
          ),
          body: Column(
            children: <Widget>[
              Expanded(
                child: BusyIndicator(
                  busy: widget.thread.busy,
                  child: ListView.builder(
                    reverse: true,
                    itemBuilder: (BuildContext context, int index) {
                      // the very first item is the user list
                      if (index == bubbles.length) {
                        return ListBody(
                          children: <Widget>[
                            const SizedBox(height: 20.0),
                            Text('Participants', textAlign: TextAlign.center, style: theme.textTheme.display2),
                            Center(
                              child: DefaultTextStyle(
                                style: theme.textTheme.subhead,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: users.map<Widget>(
                                    (User user) {
                                      return Padding(
                                        padding: const EdgeInsetsDirectional.only(top: 10.0, end: 60.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            cruise.avatarFor(user, size: 60.0),
                                            const SizedBox(width: 20.0),
                                            Text(user.displayName),
                                          ],
                                        ),
                                      );
                                    }
                                  ).toList(),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 24.0, bottom: 48.0, left: 64.0, right: 64.0),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(width: 8.0, color: theme.dividerColor),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      final int bubbleIndex = bubbles.length - (index + 1);
                      final MessageBubble bubble = bubbles[bubbleIndex];
                      return ChatLine(
                        key: ValueKey<int>(bubbleIndex),
                        user: bubble.user,
                        isCurrentUser: bubble.user.sameAs(currentUser),
                        messages: bubble.messages.map<String>((SeamailMessage message) => message.text).toList(),
                        timestamp: bubble.messages.first.timestamp,
                      );
                    },
                    itemCount: bubbles.length + 1,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: _pending.map((_PendingSend entry) {
                  // TODO(ianh): Use a ChatLine for this, somehow, so it matches the direction and style of other speech bubbles.
                  if (entry.error != null) {
                    return ListTile(
                      key: ObjectKey(entry),
                      leading: const Icon(Icons.error, size: 40.0, color: Colors.red),
                      title: Text(entry.text),
                      subtitle: Text('Failed: ${entry.error}. Tap to retry.'),
                      onTap: () {
                        _pending.remove(entry);
                        _submitMessage(entry.text);
                      },
                    );
                  }
                  return ListTile(
                    key: ObjectKey(entry),
                    leading: ProgressBuilder<void>(
                      progress: entry.progress,
                      nullChild: const Icon(Icons.error, size: 40.0, color: Colors.purple),
                      idleChild: const Icon(Icons.error, size: 40.0, color: Colors.orange),
                      startingChild: const CircularProgressIndicator(),
                      failedBuilder: (BuildContext context, Exception error, StackTrace stackTrace) => const Icon(Icons.error, size: 40.0, color: Colors.pink),
                      builder: (BuildContext context, void value) => const Icon(Icons.error, size: 40.0, color: Colors.yellow),
                    ),
                    title: Text(entry.text),
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
                      onSubmitted: (String value) {
                        assert(_textController.text == value);
                        if (_textController.text.isNotEmpty)
                          _submitCurrentMessage();
                      },
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsetsDirectional.fromSTEB(12.0, 16.0, 8.0, 16.0),
                        hintText: 'Message',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    tooltip: 'Send message',
                    onPressed: _textController.text.isNotEmpty ? _submitCurrentMessage : null,
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

class StartSeamailView extends StatefulWidget {
  const StartSeamailView({
    Key key,
    this.currentUser,
  }) : super(key: key);

  final User currentUser;

  @override
  _StartSeamailViewState createState() => _StartSeamailViewState();
}

class _StartSeamailViewState extends State<StartSeamailView> {
  final TextEditingController _nextUser = TextEditingController();
  final Set<User> _users = Set<User>();
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _text = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Progress<List<User>> _autocompleteProgress;

  @override
  void initState() {
    super.initState();
    _users.add(widget.currentUser);
  }

  @override
  void didUpdateWidget(StartSeamailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser != widget.currentUser) {
      _users.remove(oldWidget.currentUser);
      _users.add(widget.currentUser);
    }
  }

  bool get _valid {
    return _users.length >= 2
        && _subject.text.isNotEmpty
        && _text.text.isNotEmpty;
  }

  static const Widget _autocompletePlaceholder = SliverToBoxAdapter(
    child: Text('Begin typing a username in the search field above, then select the specific user from the list here.'),
  );

  void _removeUser(User user) {
    assert(_users.contains(user));
    assert(user != widget.currentUser);
    setState(() {
      _users.remove(user);
    });
  }

  void _addUser(User user) {
    assert(!_users.contains(user));
    assert(user != widget.currentUser);
    setState(() {
      _users.add(user);
    });
  }

  bool _shouldShowUser(User user) {
    return !widget.currentUser.sameAs(user)
        && !_users.any((User candidate) => candidate.sameAs(user));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start conversation'),
      ),
      floatingActionButton: _valid
        ? FloatingActionButton(
            child: const Icon(Icons.send),
            onPressed: () async {
              final Progress<SeamailThread> progress = Cruise.of(context).seamail.postThread(
                users: _users,
                subject: _subject.text,
                text: _text.text,
              );
              final SeamailThread thread = await showDialog<SeamailThread>(
                context: context,
                builder: (BuildContext context) => ProgressDialog<SeamailThread>(
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
              title: const Text('Abandon creating this conversation?'),
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12.0, 24.0, 12.0, 0.0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Participants',
                  style: Theme.of(context).textTheme.title,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: TextField(
                    controller: _nextUser,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'User name',
                    ),
                    onChanged: (String value) {
                      setState(() {
                        if (value.isNotEmpty) {
                          _autocompleteProgress = Cruise.of(context).getUserList(value);
                        } else {
                          _autocompleteProgress = const Progress<List<User>>.idle();
                        }
                      });
                    },
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12.0, 6.0, 12.0, 12.0),
              sliver: ProgressBuilder<List<User>>(
                // TODO(ianh): create a SliverStack, SliverAnimatedOpacity, SliverAnimatedSwitcher, etc
                // and make this look as half-reasonable as it would in a box world.
                progress: _autocompleteProgress,
                nullChild: _autocompletePlaceholder,
                idleChild: _autocompletePlaceholder,
                startingChild: const SliverToBoxAdapter(
                  key: ProgressBuilder.activeKey,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: CircularProgressIndicator()
                    ),
                  ),
                ),
                activeBuilder: (BuildContext context, double progress, double target) {
                  return SliverToBoxAdapter(
                    key: ProgressBuilder.activeKey,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: CircularProgressIndicator(value: progress / target)
                      ),
                    ),
                  );
                },
                failedBuilder: (BuildContext context, Exception error, StackTrace stackTrace) {
                  return SliverToBoxAdapter(
                    child: ProgressBuilder.defaultFailedBuilder(context, error, stackTrace),
                  );
                },
                builder: (BuildContext context, List<User> users) {
                  assert(users != null);
                  final Iterable<User> filteredUsers = users.where(_shouldShowUser);
                  if (filteredUsers.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12.0, 6.0, 12.0, 6.0),
                        child: Text('No users match "${_nextUser.text}".', textAlign: TextAlign.center),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildListDelegate(
                      filteredUsers.map<Widget>((User user) {
                        return ListTile(
                          key: ValueKey<String>(user.username),
                          leading: Cruise.of(context).avatarFor(user),
                          title: Text(user.toString()),
                          onTap: () {
                            _addUser(user);
                            setState(() {
                              _autocompleteProgress = const Progress<List<User>>.idle();
                              _nextUser.clear();
                            });
                          },
                        );
                      }).toList(),
                    ),
                  );
                },
                fadeWrapper: (BuildContext context, Widget child) => child,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(12.0),
              sliver: SliverToBoxAdapter(
                child: ListBody(
                  children: <Widget>[
                    const Text('Selected users (tap to remove):'),
                    const SizedBox(
                      height: 8.0,
                    ),
                    Container(
                      decoration: ShapeDecoration(
                        shape: const StadiumBorder(
                          side: BorderSide(),
                        ),
                        color: Theme.of(context).accentColor,
                      ),
                      height: 76.0,
                      child: ClipPath(
                        clipper: const ShapeBorderClipper(
                          shape: StadiumBorder(),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(4.0, 4.0, 4.0, 4.0),
                          scrollDirection: Axis.horizontal,
                          children: _users.map<Widget>((User user) {
                            return Padding(
                              key: ValueKey<String>(user.username),
                              padding: const EdgeInsets.all(4.0),
                              child: Tooltip(
                                message: user.username.toString(),
                                child: GestureDetector(
                                  onTap: user == widget.currentUser ? null : () { _removeUser(user); },
                                  child: Cruise.of(context).avatarFor(user, size: 60.0),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
