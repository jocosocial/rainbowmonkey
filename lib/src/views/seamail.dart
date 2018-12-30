import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/seamail.dart';
import '../models/user.dart';
import '../progress.dart';
import '../widgets.dart';


class SeamailView extends StatelessWidget implements View {
  const SeamailView({
    Key key,
  }) : super(key: key);

  @override
  Widget buildTab(BuildContext context) {
    final Seamail seamail = Cruise.of(context).seamail;
    return new AnimatedBuilder(
      animation: seamail,
      builder: (BuildContext context, Widget child) {
        return const Tab(
          text: 'Seamail',
          icon: const Icon(Icons.mail),
        );
      },
    );
  }

  @override
  Widget buildFab(BuildContext context) {
    return ValueListenableBuilder<ProgressValue<AuthenticatedUser>>(
      valueListenable: Cruise.of(context).user.best,
      builder: (BuildContext context, ProgressValue<AuthenticatedUser> user, Widget child) {
        const Widget icon = const Icon(Icons.add_comment); // maybe add_comment, or even just add;
        if (user is SuccessfulProgress<AuthenticatedUser> && user.value != null) {
          return new FloatingActionButton(
            child: icon,
            onPressed: () { _createNewSeamail(context, user.value); },
          );
        }
        return new FloatingActionButton(
          child: icon,
          onPressed: null,
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade400,
        );
      },
    );
  }

  Future<void> _createNewSeamail(BuildContext context, User currentUser) async {
    final SeamailThread thread = await Navigator.push(
      context,
      MaterialPageRoute<SeamailThread>(
        builder: (BuildContext context) => StartConversationView(currentUser: currentUser),
      ),
    );
    if (thread == null)
      return;
    showThread(context, thread);
  }

  void showThread(BuildContext context, SeamailThread thread) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => new SeamailThreadView(thread: thread),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // TODO(ianh): track the progress of loading the threads and show a spinner
    final Seamail threads = Cruise.of(context).seamail;
    // TODO(ianh): sort the threads by recency, newest at the top
    return AnimatedBuilder(
      animation: threads,
      builder: (BuildContext context, Widget child) {
        return ListView.builder(
          itemBuilder: (BuildContext context, int index) {
            if (index < threads.length) {
              final SeamailThread thread = threads[index];
              return GestureDetector(
                onTap: () { showThread(context, thread); },
                child: Container(
                  padding: EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[300])),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        child: Icon(
                          thread.unread ? Icons.brightness_1 : null,
                          color: Colors.red[500],
                          size: 10,
                        ),
                        padding: EdgeInsets.all(6),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.only(bottom: 2.0),
                              child: Text(
                                '${thread.subject}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: (thread.unread ? FontWeight.bold : null),
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            Text(
                              '${thread.users}',
                              style: TextStyle( fontSize: 13 ),
                            ),
                            Text(
                              '${prettyTimestamp(thread.timestamp)} - ${thread.messageCount} message${thread.messageCount == 1 ? '' : "s"}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
              // return new ListTile(
              //   leading: new CircleAvatar(child: new Text('${thread.users.length}')), // TODO(ianh): faces
              //   title: new Text(thread.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
              //   subtitle: new Text(
              //     '${thread.messageCount} message${thread.messageCount == 1 ? '' : "s"}',
              //     style: thread.unread ? const TextStyle(fontWeight: FontWeight.bold) : null,
              //   ),
              //   onTap: () { showThread(context, thread); },
              // );
            }
            // return const ListTile(
            //   leading: const CircleAvatar(child: const Icon(Icons.all_inclusive)),
            //   title: const Text('Twitarr'),
            //   // TODO(ianh): Twitarr
            // );
          },
          itemCount: threads.length + 1,
        );
      },
    );
  }
}

class SeamailThreadView extends StatefulWidget {
  const SeamailThreadView({
    Key key,
    this.thread,
  }) : super(key: key);

  final SeamailThread thread;

  @override
  _SeamailThreadViewState createState() => new _SeamailThreadViewState();
}

class _PendingSend {
  _PendingSend(this.progress, this.text);
  final Progress<void> progress;
  final String text;
  String error;
}

class _SeamailThreadViewState extends State<SeamailThreadView> {
  final TextEditingController _textController = new TextEditingController();
  final Set<_PendingSend> _pending = new Set<_PendingSend>();

  Timer _clock;

  @override
  void initState() {
    super.initState();
    // our build is dependent on the clock, so we have to rebuild occasionally:
    _clock = new Timer.periodic(new Duration(minutes: 1), (Timer timer) { setState(() { /* time passed */ }); });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  void _submitMessage(String value) {
    final Progress<void> progress = widget.thread.send(value);
    final _PendingSend entry = new _PendingSend(progress, value);
    setState(() {
      _pending.add(entry);
      progress.asFuture().then((void value) {
        setState(() {
          _pending.remove(entry);
          widget.thread.forceUpdate();
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

  String _tooltipFor(SeamailMessage message) {
    return '${message.user.toString()} • ${message.timestamp}';
  }

  String _demangleText(String text) {
    return text
      .replaceAll('<br />', '\n')
      .replaceAll('&#39;', '\'')
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<') // must be after "<br />"
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&'); // must be last
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(widget.thread.subject), // TODO(ianh): faces
      ),
      body: new Column(
        children: <Widget>[
          new Expanded(
            child: new ContinuousProgressBuilder<List<SeamailMessage>>(
              progress: widget.thread.messages,
              builder: (BuildContext context, List<SeamailMessage> messages) {
                return new ListView.builder(
                  reverse: true,
                  itemBuilder: (BuildContext context, int index) {
                    final int messageIndex = messages.length - (index + 1);
                    final SeamailMessage message = messages[messageIndex];
                    return new Tooltip(
                      message: _tooltipFor(message),
                      child: new ChatLine(
                        key: new ValueKey<int>(messageIndex),
                        avatar: Cruise.of(context).avatarFor(message.user),
                        message: new Text(_demangleText(message.text)),
                        metadata: new Text(prettyDuration(now.difference(message.timestamp))),
                      ),
                    );
                  },
                  itemCount: messages.length,
                );
              },
            ),
          ),
          new Column(
            mainAxisSize: MainAxisSize.min,
            children: _pending.map((_PendingSend entry) {
              if (entry.error != null) {
                return new ListTile(
                  key: new ObjectKey(entry),
                  leading: const Icon(Icons.error, size: 40.0, color: Colors.red),
                  title: new Text(entry.text),
                  subtitle: new Text('Failed: ${entry.error}. Tap to retry.'),
                  onTap: () {
                    _pending.remove(entry);
                    _submitMessage(entry.text);
                  },
                );
              }
              return new ListTile(
                key: new ObjectKey(entry),
                leading: new ProgressBuilder<void>(
                  progress: entry.progress,
                  nullChild: const Icon(Icons.error, size: 40.0, color: Colors.purple),
                  idleChild: const Icon(Icons.error, size: 40.0, color: Colors.orange),
                  startingChild: const CircularProgressIndicator(),
                  failedBuilder: (BuildContext context, Exception error, StackTrace stackTrace) => const Icon(Icons.error, size: 40.0, color: Colors.pink),
                  builder: (BuildContext context, void value) => const Icon(Icons.error, size: 40.0, color: Colors.yellow),
                ),
                title: new Text(entry.text),
              );
            }).toList(),
          ),
          const Divider(height: 0.0),
          new Row(
            children: <Widget>[
              new Expanded(
                child: new TextField(
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
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsetsDirectional.fromSTEB(12.0, 16.0, 8.0, 16.0),
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
  }
}

class ChatLine extends StatelessWidget {
  const ChatLine({
    Key key,
    @required this.avatar,
    @required this.message,
    @required this.metadata,
  }) : assert(avatar != null),
       assert(message != null),
       assert(metadata != null),
       super(key: key);

  final Widget avatar;
  final Widget message;
  final Widget metadata;

  @override
  Widget build(BuildContext context) {
    return new Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        new Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
          child: new Stack(
            children: <Widget>[
              avatar,
              // in case the avatar doesn't have a baseline, create a fake one:
              new Positioned.fill(
                child: new Center(
                  child: new Text('', style: Theme.of(context).textTheme.subhead),
                ),
              ),
            ],
          ),
        ),
        new Expanded(
          child: new Padding(
            padding: const EdgeInsets.fromLTRB(0.0, 20.0, 16.0, 8.0),
            child: new Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                new DefaultTextStyle(
                  style: Theme.of(context).textTheme.subhead,
                  textAlign: TextAlign.start,
                  child: message,
                ),
                const SizedBox(height: 4.0),
                DefaultTextStyle.merge(
                  style: new TextStyle(fontSize: 8.0, color: Colors.grey.shade500),
                  textAlign: TextAlign.end,
                  child: metadata,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String prettyTimestamp(DateTime timestamp) {
  final DateTime now = DateTime.now();
  final Duration duration = now.difference(timestamp);
  if (duration.inMinutes < 1)
    return 'just now';
  if (duration.inMinutes < 59.5)
    return '${duration.inMinutes.round()} ago';
  if (now.day == timestamp.day)
    return '${DateFormat("h:mm a' Today'").format(timestamp)}';
  if ((now.day - 1) == timestamp.day)
    return '${DateFormat("h:mm a' Yesterday'").format(timestamp)}';
  if (duration.inDays < 7)
    return '${DateFormat("h:mm a' on 'EEEEE").format(timestamp)}';
  return '${DateFormat.yMMMMd("en_US").format(timestamp)}';
}

String prettyDuration(Duration duration) {
  final int microseconds = duration.inMicroseconds;
  final double minutes = microseconds / (1000 * 1000 * 60);
  if (minutes < 1)
    return 'just now';
  if (minutes < 59.5)
    return '${minutes.round()}m ago';
  final double hours = microseconds / (1000 * 1000 * 60 * 60);
  if (hours < 10)
    return '${hours.truncate()}h ${(minutes - hours.truncate() * 60).truncate()}m ago';
  if (hours < 23.5)
    return '${hours.round()}h ago';
  final double days = microseconds / (1000 * 1000 * 60 * 60 * 24);
  if (days < 7)
    return '${days.truncate()}d ${(hours - days.truncate() * 24).truncate()}h ago';
  final double weeks = microseconds / (1000 * 1000 * 60 * 60 * 24 * 7);
  if (weeks < 3)
    return '${weeks.truncate()}w ${(days - weeks.truncate() * 7).truncate()}d ago';
  return '${weeks.round()}w ago';
}

class StartConversationView extends StatefulWidget {
  const StartConversationView({
    Key key,
    this.currentUser,
  }) : super(key: key);

  final User currentUser;

  @override
  _StartConversationViewState createState() => new _StartConversationViewState();
}

class _StartConversationViewState extends State<StartConversationView> {
  final TextEditingController _nextUser = new TextEditingController();
  final Set<User> _users = new Set<User>();
  final TextEditingController _subject = new TextEditingController();
  final TextEditingController _message = new TextEditingController();
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();

  Progress<List<User>> _autocompleteProgress;

  @override
  void initState() {
    super.initState();
    _users.add(widget.currentUser);
  }

  @override
  void didUpdateWidget(StartConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser != widget.currentUser) {
      _users.remove(oldWidget.currentUser);
      _users.add(widget.currentUser);
    }
  }

  bool get _valid {
    return _users.length >= 2
        && _subject.text.isNotEmpty
        && _message.text.isNotEmpty;
  }

  static const Widget _autocompletePlaceholder = const SliverToBoxAdapter(
    child: const Text('Begin typing a username in the search field above, then select the specific user from the list here.'),
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
    return new Scaffold(
      appBar: new AppBar(
        title: const Text('Start conversation'),
      ),
      floatingActionButton: _valid
        ? new FloatingActionButton(
            child: const Icon(Icons.send),
            onPressed: () async {
              final Progress<SeamailThread> progress = Cruise.of(context).newSeamail(
                _users,
                _subject.text,
                _message.text,
              );
              final SeamailThread thread = await showDialog<SeamailThread>(
                context: context,
                builder: (BuildContext context) => new ProgressDialog<SeamailThread>(
                  progress: progress,
                ),
              );
              if (mounted && thread != null)
                Navigator.pop(context, thread);
            },
          )
        : new FloatingActionButton(
            child: const Icon(Icons.send),
            onPressed: null,
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.grey.shade400,
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: new Form(
        key: _formKey,
        onChanged: () {
          setState(() {
            /* need to recheck whether the submit button should be enabled */
          });
        },
        onWillPop: () async {
          return await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => new AlertDialog(
              title: const Text('Abandon creating this conversation?'),
              actions: <Widget>[
                new FlatButton(
                  onPressed: () { Navigator.of(context).pop(true); },
                  child: const Text('YES'),
                ),
                new FlatButton(
                  onPressed: () { Navigator.of(context).pop(false); },
                  child: const Text('NO'),
                ),
              ],
            ),
          ) == true;
        },
        child: new CustomScrollView(
          slivers: <Widget>[
            new SliverPadding(
              padding: const EdgeInsets.fromLTRB(12.0, 20.0, 12.0, 0.0),
              sliver: new SliverToBoxAdapter(
                child: new Align(
                  alignment: AlignmentDirectional.topStart,
                  child: new TextFormField(
                    controller: _subject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                    ),
                  ),
                ),
              ),
            ),
            new SliverPadding(
              padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
              sliver: new SliverToBoxAdapter(
                child: new Align(
                  alignment: AlignmentDirectional.topStart,
                  child: new TextFormField(
                    controller: _message,
                    decoration: const InputDecoration(
                      labelText: 'First message',
                    ),
                  ),
                ),
              ),
            ),
            new SliverPadding(
              padding: const EdgeInsets.fromLTRB(12.0, 24.0, 12.0, 0.0),
              sliver: new SliverToBoxAdapter(
                child: new Text(
                  'Participants',
                  style: Theme.of(context).textTheme.title,
                ),
              ),
            ),
            new SliverPadding(
              padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
              sliver: new SliverToBoxAdapter(
                child: new Align(
                  alignment: AlignmentDirectional.topStart,
                  child: new TextField(
                    controller: _nextUser,
                    decoration: const InputDecoration(
                      prefixIcon: const Icon(Icons.search),
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
            new SliverPadding(
              padding: const EdgeInsets.fromLTRB(12.0, 6.0, 12.0, 12.0),
              sliver: ProgressBuilder<List<User>>(
                // TODO(ianh): create a SliverStack, SliverAnimatedOpacity, SliverAnimatedSwitcher, etc
                // and make this look as half-reasonable as it would in a box world.
                progress: _autocompleteProgress,
                nullChild: _autocompletePlaceholder,
                idleChild: _autocompletePlaceholder,
                startingChild: const SliverToBoxAdapter(
                  key: ProgressBuilder.activeKey,
                  child: const Center(
                    child: const Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: const CircularProgressIndicator()
                    ),
                  ),
                ),
                activeBuilder: (BuildContext context, double progress, double target) {
                  return new SliverToBoxAdapter(
                    key: ProgressBuilder.activeKey,
                    child: new Center(
                      child: new Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: new CircularProgressIndicator(value: progress / target)
                      ),
                    ),
                  );
                },
                failedBuilder: (BuildContext context, Exception error, StackTrace stackTrace) {
                  return new SliverToBoxAdapter(
                    child: ProgressBuilder.defaultFailedBuilder(context, error, stackTrace),
                  );
                },
                builder: (BuildContext context, List<User> users) {
                  assert(users != null);
                  final Iterable<User> filteredUsers = users.where(_shouldShowUser);
                  if (filteredUsers.isEmpty) {
                    return new SliverToBoxAdapter(
                      child: new Padding(
                        padding: const EdgeInsets.fromLTRB(12.0, 6.0, 12.0, 6.0),
                        child: new Text('No users match "${_nextUser.text}".', textAlign: TextAlign.center),
                      ),
                    );
                  }
                  return new SliverList(
                    delegate: new SliverChildListDelegate(
                      filteredUsers.map<Widget>((User user) {
                        return ListTile(
                          key: new ValueKey<String>(user.username),
                          leading: Cruise.of(context).avatarFor(user),
                          title: new Text(user.toString()),
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
            new SliverPadding(
              padding: const EdgeInsets.all(12.0),
              sliver: new SliverToBoxAdapter(
                child: new ListBody(
                  children: <Widget>[
                    const Text('Selected users (tap to remove):'),
                    const SizedBox(
                      height: 8.0,
                    ),
                    new Container(
                      decoration: new ShapeDecoration(
                        shape: const StadiumBorder(
                          side: const BorderSide(),
                        ),
                        color: Theme.of(context).accentColor,
                      ),
                      height: 76.0,
                      child: new ClipPath(
                        clipper: const ShapeBorderClipper(
                          shape: const StadiumBorder(),
                        ),
                        child: new ListView(
                          padding: const EdgeInsets.fromLTRB(4.0, 4.0, 4.0, 4.0),
                          scrollDirection: Axis.horizontal,
                          children: _users.map<Widget>((User user) {
                            return new Padding(
                              key: new ValueKey<String>(user.username),
                              padding: const EdgeInsets.all(4.0),
                              child: new Tooltip(
                                message: user.username.toString(),
                                child: new GestureDetector(
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
