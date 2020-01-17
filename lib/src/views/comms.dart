import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logic/cruise.dart';
import '../logic/forums.dart';
import '../logic/mentions.dart';
import '../logic/seamail.dart';
import '../models/server_status.dart';
import '../models/string.dart';
import '../models/user.dart';
import '../network/twitarr.dart';
import '../pretty_text.dart';
import '../progress.dart';
import '../utils.dart';
import '../widgets.dart';
import 'forums.dart';
import 'seamail.dart';

typedef DividerCallback = Widget Function(Widget child);

abstract class CommsView extends StatelessWidget implements View {
  const CommsView({
    @required PageStorageKey<UniqueObject> key,
  }) : super(key: key);

  @protected
  bool canPost(ServerStatus status);

  @protected
  void startConversation(BuildContext context, AuthenticatedUser user);

  @protected
  IconData get addIcon;

  @override
  Widget buildFab(BuildContext context) {
    final ContinuousProgress<AuthenticatedUser> userProgress = Cruise.of(context).user;
    final ContinuousProgress<ServerStatus> serverStatusProgress = Cruise.of(context).serverStatus;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[userProgress.best, serverStatusProgress.best]),
      builder: (BuildContext context, Widget child) {
        final Widget icon = Icon(addIcon);
        final AuthenticatedUser user = userProgress.currentValue;
        final ServerStatus serverStatus = serverStatusProgress.currentValue ?? const ServerStatus();
        if (user != null && canPost(serverStatus)) {
          return FloatingActionButton(
            child: icon,
            tooltip: 'Start new conversation.',
            onPressed: () => startConversation(context, user),
          );
        }
        return FloatingActionButton(
          child: icon,
          tooltip: 'Start new conversation.',
          onPressed: null,
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade400,
        );
      },
    );
  }

  DividerCallback getDivider(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool showDividers = theme.platform == TargetPlatform.iOS;
    if (showDividers) {
      return (Widget child) {
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border(
              bottom: Divider.createBorderSide(context),
            ),
          ),
          child: child,
        );
      };
    }
    return (Widget child) => child;
  }
}

class PrivateCommsView extends CommsView {
  const PrivateCommsView({
    PageStorageKey<UniqueObject> key,
  }) : super(key: key);

  @override
  bool isEnabled(ServerStatus status) => status.seamailEnabled;

  @override
  bool canPost(ServerStatus status) => status.seamailEnabled;

  @override
  void startConversation(BuildContext context, AuthenticatedUser user) => createNewSeamail(context, user);

  @override
  IconData get addIcon => Icons.mail;

  @override
  Widget buildTabIcon(BuildContext context) {
    final Seamail seamail = Cruise.of(context).seamail;
    return AnimatedBuilder(
      animation: seamail,
      builder: (BuildContext context, Widget child) {
        return Badge(
          child: child,
          enabled: seamail.unreadCount > 0,
        );
      },
      child: const Icon(Icons.mail),
    );
  }

  @override
  Widget buildTabLabel(BuildContext context) => const Text('Seamail');

  static Future<void> createNewSeamail(BuildContext context, User currentUser, { List<User> others }) async {
    assert(currentUser != null);
    final SeamailThread thread = await Navigator.push(
      context,
      MaterialPageRoute<SeamailThread>(
        builder: (BuildContext context) => StartSeamailView(currentUser: currentUser.effectiveUser, initialOtherUsers: others),
      ),
    );
    if (thread == null)
      return;
    showSeamailThread(context, thread);
  }

  static void showSeamailThread(BuildContext context, SeamailThread thread) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SeamailThreadView(thread: thread),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final TextStyle headerStyle = textTheme.title;
    final CruiseModel cruise = Cruise.of(context);
    final Seamail seamail = cruise.seamail;
    final ContinuousProgress<ServerStatus> serverStatusProgress = cruise.serverStatus;
    return ModeratorBuilder(
      builder: (BuildContext context, User currentUser, bool canModerate, bool isModerating) {
        return BusyIndicator(
          busy: OrListenable(<ValueListenable<bool>>[seamail.busy]),
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[seamail, serverStatusProgress.best]),
            builder: (BuildContext context, Widget child) {
              final List<SeamailThread> seamailThreads = seamail.toList()
                ..sort(
                  // Default SeamailThread sort is not time-based, it's subject-based.
                  (SeamailThread a, SeamailThread b) {
                    if (b.lastMessageTimestamp != a.lastMessageTimestamp)
                      return b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp);
                    return b.id.compareTo(a.id);
                  }
                );
              final DividerCallback divide = getDivider(context);
              Widget noMessagesWidget;
              if (seamailThreads.isEmpty) {
                if (cruise.isLoggedIn) {
                  noMessagesWidget = const ListTile(
                    leading: Icon(Icons.phonelink_erase, size: 40.0),
                    title: Text('I check my messages'),
                    subtitle: Text('but I don\'t have any messages.'),
                  );
                } else {
                  noMessagesWidget = const ListTile(
                    leading: Icon(Icons.account_circle, size: 40.0),
                    title: Text('Seamail is only available when logged in'),
                  );
                }
              }
              return JumpToTop(
                builder: (BuildContext context, ScrollController controller) => CustomScrollView(
                  controller: controller,
                  slivers: <Widget>[
                    SliverSafeArea(
                      bottom: false,
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          <Widget>[
                            if (canModerate)
                              divide(SwitchListTile(
                                key: const Key('masquerade'),
                                title: const Text('Masquerade as @moderator'),
                                value: isModerating,
                                onChanged: (bool value) {
                                  cruise.setAsMod(enabled: value);
                                },
                              )),
                            divide(ListTile(
                              key: const Key('private'),
                              title: Text('Private messages', style: headerStyle),
                              trailing: ValueListenableBuilder<bool>(
                                valueListenable: cruise.isLoggedIn ? seamail.active : const AlwaysStoppedAnimation<bool>(true),
                                builder: (BuildContext context, bool active, Widget child) {
                                  return IconButton(
                                    icon: const Icon(Icons.refresh),
                                    color: DefaultTextStyle.of(context).style.color,
                                    tooltip: 'Force refresh',
                                    onPressed: active ? null : seamail.reload,
                                  );
                                },
                              ),
                            )),
                            if (noMessagesWidget != null)
                              divide(noMessagesWidget),
                          ],
                        ),
                      ),
                    ),
                    SliverSafeArea(
                      top: false,
                      sliver: SliverPrototypeExtentList(
                        prototypeItem: const SeamailListTile.prototype(),
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) => divide(SeamailListTile(thread: seamailThreads[index])),
                          childCount: seamailThreads.length,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class PublicCommsView extends CommsView {
  const PublicCommsView({
    PageStorageKey<UniqueObject> key,
  }) : super(key: key);

  @override
  bool isEnabled(ServerStatus status) => status.forumsEnabled || status.streamEnabled;

  @override
  bool canPost(ServerStatus status) => status.forumsEnabled;

  @override
  void startConversation(BuildContext context, AuthenticatedUser user) => createNewForum(context);

  @override
  IconData get addIcon => Icons.add_comment;

  @override
  Widget buildTabIcon(BuildContext context) => const Icon(Icons.forum);

  @override
  Widget buildTabLabel(BuildContext context) => const Text('Forums');

  static Future<void> createNewForum(BuildContext context) async {
    final ForumThread thread = await Navigator.push(
      context,
      MaterialPageRoute<ForumThread>(
        builder: (BuildContext context) => const StartForumView(),
      ),
    );
    if (thread == null)
      return;
    showForumThread(context, thread);
  }

  static void showForumThread(BuildContext context, ForumThread thread) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ForumThreadView(thread: thread),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final TextStyle headerStyle = textTheme.title;
    final CruiseModel cruise = Cruise.of(context);
    final Forums forums = cruise.forums;
    final Mentions mentions = cruise.mentions;
    final ContinuousProgress<ServerStatus> serverStatusProgress = cruise.serverStatus;
    return ModeratorBuilder(
      builder: (BuildContext context, User currentUser, bool canModerate, bool isModerating) {
        return BusyIndicator(
          busy: OrListenable(<ValueListenable<bool>>[forums.busy]),
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[forums, mentions, serverStatusProgress.best]),
            builder: (BuildContext context, Widget child) {
              final ServerStatus status = serverStatusProgress.currentValue ?? const ServerStatus();
              final List<ForumThread> forumThreads = forums.toList()
                ..sort(
                  // Default ForumThread sort is not time-based, it's subject-based.
                  (ForumThread a, ForumThread b) {
                    if (a.isSticky != b.isSticky) {
                      if (a.isSticky)
                        return -1;
                      assert(b.isSticky);
                      return 1;
                    }
                    if (b.lastMessageTimestamp != a.lastMessageTimestamp)
                      return b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp);
                    return b.id.compareTo(a.id);
                  }
                )
                ..length = forums.totalCount;
              final DividerCallback divide = getDivider(context);
              return JumpToTop(
                builder: (BuildContext context, ScrollController controller) => CustomScrollView(
                  controller: controller,
                  slivers: <Widget>[
                    SliverSafeArea(
                      bottom: !status.forumsEnabled,
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          <Widget>[
                            if (canModerate)
                              divide(SwitchListTile(
                                key: const Key('masquerade'),
                                title: const Text('Masquerade as @moderator'),
                                value: isModerating,
                                onChanged: (bool value) {
                                  cruise.setAsMod(enabled: value);
                                },
                              )),
                            divide(ListTile(
                              key: const Key('public'),
                              title: Text('Public messages', style: headerStyle),
                              trailing: ValueListenableBuilder<bool>(
                                valueListenable: forums.active,
                                builder: (BuildContext context, bool active, Widget child) {
                                  return IconButton(
                                    icon: const Icon(Icons.refresh),
                                    color: DefaultTextStyle.of(context).style.color,
                                    tooltip: 'Force refresh',
                                    onPressed: active ? null : forums.reload,
                                  );
                                },
                              ),
                            )),
                            if (!isModerating && cruise.isLoggedIn)
                              divide(KeyedSubtree(
                                key: const Key('mentions'),
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: mentions.hasMentions,
                                  builder: (BuildContext context, bool hasMentions, Widget child) {
                                    return ListTile(
                                      leading: Badge(
                                        child: CircleAvatar(child: Icon(hasMentions ? Icons.notifications_active : Icons.notifications)),
                                        alignment: const AlignmentDirectional(1.1, 1.1),
                                        enabled: hasMentions,
                                      ),
                                      title: const Text('Mentions'),
                                      onTap: () { Navigator.pushNamed(context, '/mentions'); },
                                    );
                                  },
                                ),
                              )),
                            if (status.streamEnabled)
                              divide(ListTile(
                                key: const Key('twitarr'),
                                leading: const CircleAvatar(child: Icon(Icons.speaker_notes)),
                                title: const Text('Twitarr'),
                                onTap: () { Navigator.pushNamed(context, '/twitarr'); },
                              )),
                            if (status.forumsEnabled && forumThreads.isEmpty)
                              iconAndLabel(
                                icon: Icons.forum,
                                message: forums.busy.value ? 'Loading forums...' : forums.pending ? 'Forums not yet loaded.' : 'No forums.',
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (status.forumsEnabled)
                      SliverSafeArea(
                        top: false,
                        sliver: SliverPrototypeExtentList(
                          prototypeItem: const ForumListTile.prototype(),
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              forums.observing(index);
                              return divide(ForumListTile(thread: forumThreads[index]));
                            },
                            childCount: forumThreads.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class OrListenable extends ValueNotifier<bool> {
  OrListenable(this._children) : super(_children.fold<bool>(false, _merge));

  final List<ValueListenable<bool>> _children;

  static bool _merge(bool previousValue, ValueListenable<bool> child) {
    return previousValue || child.value;
  }

  void _update() {
    value = _children.fold<bool>(false, _merge);
  }

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners) {
      for (final Listenable child  in _children)
        child.addListener(_update);
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      for (final Listenable child  in _children)
        child.removeListener(_update);
    }
  }

  @override
  String toString() {
    return '$runtimeType([${_children.join(", ")}])';
  }
}

class ForumListTile extends StatelessWidget {
  const ForumListTile({ Key key, this.thread }) : super(key: key);

  const ForumListTile.prototype({ Key key }) : thread = null, super(key: key);

  final ForumThread thread;

  @override
  Widget build(BuildContext context) {
    if (thread == null) {
      return const ListTile(
        leading: CircleAvatar(child: Icon(Icons.forum)),
        title: Text('...'),
        subtitle: Text(''),
        isThreeLine: true,
      );
    }
    final String unread = thread.unreadCount > 0 ? ' (${thread.unreadCount} new)' : '';
    final String recentMessageMetadata = 'Most recent from ${thread.lastMessageUser}';
    return AnimatedOpacity(
      key: ValueKey<ForumThread>(thread),
      opacity: thread.fresh ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      child: ListTile(
        leading: Tooltip(
          message: thread.isSticky ? 'Sticky forum' : 'Forum',
          child: Badge(
            child: CircleAvatar(child: Icon(thread.isSticky ? Icons.feedback : Icons.forum)),
            alignment: const AlignmentDirectional(1.1, 1.1),
            enabled: thread.hasUnread,
          ),
        ),
        title: Text(
          thread.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: thread.hasUnread ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${thread.totalCount} message${thread.totalCount == 1 ? '' : "s"}$unread',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  ' ${prettyDuration(Now.of(context).difference(thread.lastMessageTimestamp), short: true)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Text(
              recentMessageMetadata,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () { PublicCommsView.showForumThread(context, thread); },
      ),
    );
  }
}

class _PrototypeSeamailMessage implements SeamailThread {
  const _PrototypeSeamailMessage();

  @override
  final Duration maxUpdatePeriod = null;

  @override
  final ThreadReadCallback onThreadRead = null;

  @override
  final String id = null;

  @override
  final String subject = '';

  @override
  final Iterable<User> users = const <User>[User.prototype()];

  @override
  DateTime get lastMessageTimestamp => DateTime(2000);

  @override
  final bool hasUnread = false;

  @override
  final int unreadCount = 0;

  @override
  final int totalCount = 0;

  @override
  List<SeamailMessage> getMessages() => const <SeamailMessage>[];

  @override
  Future<void> update() async { }

  @override
  bool updateFrom(SeamailThreadSummary thread) => false;

  @override
  Progress<void> send(String text) => null;

  @override
  final ValueListenable<bool> active = null;

  @override
  void reload() { }

  @override
  final ValueListenable<bool> busy = null;

  @override
  void startBusy() { }

  @override
  void endBusy() { }

  @override
  void addListener(VoidCallback listener) { }

  @override
  void removeListener(VoidCallback listener) { }

  @override
  void dispose() { }

  @override
  void notifyListeners() { }

  @override
  final bool hasListeners = false;

  @override
  int compareTo(SeamailThread other) => 0;
}

class SeamailListTile extends StatelessWidget {
  const SeamailListTile({
    Key key,
    this.thread,
  }) : super(key: key);

  const SeamailListTile.prototype({
    Key key,
  }) : thread = const _PrototypeSeamailMessage(),
       super(key: key);

  final SeamailThread thread;

  @override
  Widget build(BuildContext context) {
    final List<SeamailMessage> messages = thread.getMessages();
    String lastMessagePrefix;
    TwitarrString lastMessageBody;
    if (messages.isNotEmpty) {
      lastMessagePrefix = '${messages.last.user}: ';
      lastMessageBody = messages.last.text;
    } else if (thread.unreadCount > 0) {
      lastMessagePrefix = '${thread.unreadCount} new message${thread.unreadCount == 1 ? '' : "s"}';
      lastMessageBody = const TwitarrString('');
    } else {
      lastMessagePrefix = '${thread.totalCount} message${thread.totalCount == 1 ? '' : "s"}';
      lastMessageBody = const TwitarrString('');
    }
    return ListTile(
      key: ValueKey<SeamailThread>(thread),
      leading: Badge(
        child: Cruise.of(context).avatarFor(thread.users, size: 56.0),
        alignment: const AlignmentDirectional(1.1, 1.1),
        enabled: thread.hasUnread,
      ),
      title: Text(
        thread.subject,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: thread.hasUnread ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            thread.users.map<String>((User user) => user.toString()).join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: PrettyText(
                  lastMessageBody,
                  prefix: lastMessagePrefix,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                ' ${prettyDuration(Now.of(context).difference(thread.lastMessageTimestamp), short: true)}',
                style: Theme.of(context).textTheme.caption,
              ),
            ],
          ),
        ],
      ),
      onTap: () { PrivateCommsView.showSeamailThread(context, thread); },
      isThreeLine: true,
    );
  }
}
