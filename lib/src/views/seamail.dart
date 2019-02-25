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
  final Set<_PendingSend> _pending = <_PendingSend>{};

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
    final TextStyle appBarTitleTextStyle = theme.primaryTextTheme.body1.apply(fontSizeFactor: 0.8);
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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        flexibleSpace: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double height = constraints.maxHeight;
                    return SizedBox(
                      width: (users.length + 1) * height / 2.0,
                      child: Stack(
                        children: List<Widget>.generate(users.length, (int index) {
                          return Positioned(
                            top: 2.0,
                            left: index * height / 2.0,
                            bottom: 0.0,
                            width: height,
                            child: cruise.avatarFor(<User>[users[index]]),
                          );
                        }, growable: false),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text('', style: appBarTitleTextStyle),
              ),
            ],
          ),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                widget.thread.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.primaryTextTheme.body1.apply(fontSizeFactor: 0.8),
              ),
            ),
          ],
        ),
      ),
      body: ModeratorBuilder(
        builder: (BuildContext context, AuthenticatedUser currentUser, bool canModerate, bool isModerating) {
          return Column(
            children: <Widget>[
              Expanded(
                child: BusyIndicator(
                  busy: widget.thread.busy,
                  child: ListView.builder(
                    reverse: true,
                    itemBuilder: (BuildContext context, int index) {
                      // the very first item is the user list
                      if (index == bubbles.length) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12.0, 24.0, 12.0, 56.0),
                          child: ListBody(
                            children: <Widget>[
                              Text(widget.thread.subject, textAlign: TextAlign.center, style: theme.textTheme.title),
                              const SizedBox(height: 24.0),
                              const Divider(),
                              const SizedBox(height: 24.0),
                              Text('Participants', textAlign: TextAlign.center, style: theme.textTheme.subhead),
                              Center(
                                child: DefaultTextStyle(
                                  style: theme.textTheme.body2,
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
                                              cruise.avatarFor(<User>[user], size: 60.0),
                                              const SizedBox(width: 20.0),
                                              Flexible(
                                                child: Text('$user'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    ).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24.0),
                              const Divider(),
                            ],
                          ),
                        );
                      }
                      final int bubbleIndex = bubbles.length - (index + 1);
                      final MessageBubble bubble = bubbles[bubbleIndex];
                      return ChatLine(
                        key: ValueKey<int>(bubbleIndex),
                        user: bubble.user,
                        isCurrentUser: bubble.user.sameAs(currentUser.effectiveUser),
                        messages: bubble.messages.map<String>((SeamailMessage message) => message.text).toList(),
                        photos: null,
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
                  // TODO(ianh): Use a ChatLine or ProgressChatLine for this
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
                      maxLength: 10000,
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
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsetsDirectional.fromSTEB(12.0, 16.0, 8.0, 16.0),
                        counter: const SizedBox.shrink(),
                        hintText: 'Message${ isModerating ? " (as moderator)" : ""}',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    tooltip: 'Send message${ isModerating ? " (as moderator)" : ""}',
                    onPressed: _textController.text.isNotEmpty ? _submitCurrentMessage : null,
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

class StartSeamailView extends StatefulWidget {
  StartSeamailView({
    Key key,
    this.currentUser,
    this.initialOtherUsers,
  }) : assert(currentUser is! AuthenticatedUser || !(currentUser as AuthenticatedUser).credentials.asMod),
       super(key: key);

  final User currentUser;
  final List<User> initialOtherUsers;

  @override
  _StartSeamailViewState createState() => _StartSeamailViewState();
}

class _StartSeamailViewState extends State<StartSeamailView> {
  final TextEditingController _nextUser = TextEditingController();
  final Set<User> _users = <User>{};
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _text = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final FocusNode _subjectFocus = FocusNode();
  final FocusNode _firstMessageFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();

  Progress<List<User>> _autocompleteProgress;

  @override
  void initState() {
    super.initState();
    _users.add(widget.currentUser);
    if (widget.initialOtherUsers != null)
      _users.addAll(widget.initialOtherUsers);
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
      body: ModeratorBuilder(
        builder: (BuildContext context, _, __, bool isModerating) { // using _ to avoid potential conflicts with widget.currentUser
        assert(isModerating == widget.currentUser.isModerator);
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
                      maxLength: 200,
                      focusNode: _subjectFocus,
                      autofocus: true,
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
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
                  sliver: SliverToBoxAdapter(
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: TextFormField(
                        controller: _text,
                        maxLength: 10000,
                        focusNode: _firstMessageFocus,
                        onFieldSubmitted: (String value) {
                          FocusScope.of(context).requestFocus(_usernameFocus);
                        },
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'First message${ isModerating ? " (as moderator)" : ""}',
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
                        focusNode: _usernameFocus,
                        textInputAction: TextInputAction.search,
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
                              leading: Cruise.of(context).avatarFor(<User>[user], enabled: false),
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
                                      child: Cruise.of(context).avatarFor(<User>[user], size: 60.0, enabled: false),
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
          );
        },
      ),
    );
  }
}
