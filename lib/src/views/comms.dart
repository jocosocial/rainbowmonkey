import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logic/cruise.dart';
import '../logic/forums.dart';
import '../logic/mentions.dart';
import '../logic/seamail.dart';
import '../models/errors.dart';
import '../models/server_status.dart';
import '../models/user.dart';
import '../progress.dart';
import '../utils.dart';
import '../widgets.dart';
import 'forums.dart';
import 'seamail.dart';

enum _CreateWhat { seamail, forum }

class CommsView extends StatelessWidget implements View {
  const CommsView({
    Key key,
  }) : super(key: key);

  @override
  bool isEnabled(ServerStatus status) => status.seamailEnabled || status.forumsEnabled || status.streamEnabled;

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
  Widget buildTabLabel(BuildContext context) => const Text('Messages');

  Future<_CreateWhat> _getCreateWhat(BuildContext context, ServerStatus status) async {
    if (status.forumsEnabled && status.seamailEnabled) {
      return await showDialog<_CreateWhat>(
        context: context,
        builder: (BuildContext context) => SimpleDialog(
          title: const Text('What would you like to create?'),
          children: <Widget>[
            FlatButton(
              onPressed: () { Navigator.of(context).pop(_CreateWhat.seamail); },
              child: const Text('PRIVATE SEAMAIL'),
            ),
            FlatButton(
              onPressed: () { Navigator.of(context).pop(_CreateWhat.forum); },
              child: const Text('PUBLIC FORUM'),
            ),
          ],
        ),
      );
    }
    if (status.seamailEnabled)
      return _CreateWhat.seamail;
    if (status.forumsEnabled)
      return _CreateWhat.forum;
    assert(false);
    throw const LocalError('Seamail and forums are currently disabled on the server.');
  }

  @override
  Widget buildFab(BuildContext context) {
    final ContinuousProgress<AuthenticatedUser> userProgress = Cruise.of(context).user;
    final ContinuousProgress<ServerStatus> serverStatusProgress = Cruise.of(context).serverStatus;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[userProgress.best, serverStatusProgress.best]),
      builder: (BuildContext context, Widget child) {
        const Widget icon = Icon(Icons.add_comment);
        final AuthenticatedUser user = userProgress.currentValue;
        final ServerStatus serverStatus = serverStatusProgress.currentValue ?? const ServerStatus();
        if (user != null && (serverStatus.seamailEnabled || serverStatus.forumsEnabled)) {
          return FloatingActionButton(
            child: icon,
            onPressed: () async {
              switch (await _getCreateWhat(context, serverStatus)) {
                case _CreateWhat.seamail:
                  return createNewSeamail(context, user);
                case _CreateWhat.forum:
                  return createNewForum(context);
              }
            }
          );
        }
        return FloatingActionButton(
          child: icon,
          onPressed: null,
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade400,
        );
      },
    );
  }

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
    final Seamail seamail = cruise.seamail;
    final Forums forums = cruise.forums;
    final Mentions mentions = cruise.mentions;
    final ContinuousProgress<ServerStatus> serverStatusProgress = cruise.serverStatus;
    final DateTime now = Now.of(context);
    return ModeratorBuilder(
      builder: (BuildContext context, User currentUser, bool canModerate, bool isModerating) {
        return BusyIndicator(
          busy: OrListenable(<ValueListenable<bool>>[seamail.busy, forums.busy]),
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[seamail, forums, mentions, serverStatusProgress.best]),
            builder: (BuildContext context, Widget child) {
              final ServerStatus status = serverStatusProgress.currentValue ?? const ServerStatus();
              final List<SeamailThread> seamailThreads = seamail.toList()
                ..sort(
                  (SeamailThread a, SeamailThread b) {
                    if (b.lastMessageTimestamp != a.lastMessageTimestamp)
                      return b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp);
                    return b.id.compareTo(a.id);
                  }
                );
              final List<ForumThread> forumThreads = forums.toList()
                ..sort(
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
                );
              final bool showDividers = theme.platform == TargetPlatform.iOS;
              int itemCount = 0;
              if (canModerate)
                itemCount += 1; // masquerade
              if (status.seamailEnabled) {
                itemCount += 1; // "private" heading
                itemCount += math.max<int>(seamailThreads.length, 1 /* "no messages" */);
              }
              if (status.forumsEnabled || status.streamEnabled) {
                itemCount += 1; // "public" heading
                if (!isModerating && cruise.isLoggedIn)
                  itemCount += 1; // mentions
                if (status.streamEnabled)
                  itemCount += 1; // twitarr
                if (status.forumsEnabled)
                  itemCount += forums.length;
              }
              return ListView.builder(
                itemCount: itemCount,
                itemBuilder: (BuildContext context, int index) {
                  Widget generateTile() {
                    if (canModerate) {
                      if (index == 0) {
                        return SwitchListTile(
                          title: const Text('Masquerade as @moderator'),
                          value: isModerating,
                          onChanged: (bool value) {
                            cruise.setAsMod(enabled: value);
                          },
                        );
                      }
                      index -= 1;
                    }
                    if (status.seamailEnabled) {
                      if (index == 0) {
                        return ListTile(
                          title: Text('Private messages', style: headerStyle),
                          trailing: ValueListenableBuilder<bool>(
                            valueListenable: cruise.isLoggedIn ? seamail.active : const AlwaysStoppedAnimation<bool>(true),
                            builder: (BuildContext context, bool active, Widget child) {
                              return IconButton(
                                icon: const Icon(Icons.refresh),
                                color: Colors.black,
                                tooltip: 'Force refresh',
                                onPressed: active ? null : seamail.reload,
                              );
                            },
                          ),
                        );
                      }
                      index -= 1;
                      if (seamailThreads.isEmpty) {
                        if (index == 0) { // ignore: invariant_booleans
                          if (cruise.isLoggedIn) {
                            return const ListTile(
                              leading: Icon(Icons.phonelink_erase, size: 40.0),
                              title: Text('I check my messages'),
                              subtitle: Text('but I don\'t have any messages.'),
                            );
                          }
                          return const ListTile(
                            leading: Icon(Icons.account_circle, size: 40.0),
                            title: Text('Seamail is only available when logged in'),
                          );
                        }
                        index -= 1;
                      } else {
                        if (index < seamailThreads.length) {
                          final SeamailThread thread = seamailThreads[index];
                          final List<SeamailMessage> messages = thread.getMessages();
                          String lastMessage;
                          if (messages.isNotEmpty) {
                            lastMessage = '${messages.last.user}: ${messages.last.text}';
                          } else if (thread.unreadCount > 0) {
                            lastMessage = '${thread.unreadCount} new message${thread.unreadCount == 1 ? '' : "s"}';
                          } else {
                            lastMessage = '${thread.totalCount} message${thread.totalCount == 1 ? '' : "s"}';
                          }
                          return ListTile(
                            leading: Badge(
                              child: cruise.avatarFor(thread.users, size: 56.0),
                              alignment: const AlignmentDirectional(1.1, 1.1),
                              enabled: thread.hasUnread,
                            ),
                            title: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    thread.subject,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: thread.hasUnread ? const TextStyle(fontWeight: FontWeight.bold) : null,
                                  ),
                                ),
                                Text(
                                  ' ${prettyDuration(now.difference(thread.lastMessageTimestamp), short: true)}',
                                  style: textTheme.caption,
                                ),
                              ],
                            ),
                            subtitle: ListBody(
                              children: <Widget>[
                                Text(
                                  thread.users.map<String>((User user) => user.toString()).join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            onTap: () { showSeamailThread(context, thread); },
                            isThreeLine: true,
                          );
                        }
                        index -= seamailThreads.length;
                      }
                    }
                    if (status.forumsEnabled || status.streamEnabled) {
                      if (index == 0) {
                        return ListTile(
                          title: Text('Public messages', style: headerStyle),
                          trailing: ValueListenableBuilder<bool>(
                            valueListenable: forums.active,
                            builder: (BuildContext context, bool active, Widget child) {
                              return IconButton(
                                icon: const Icon(Icons.refresh),
                                color: Colors.black,
                                tooltip: 'Force refresh',
                                onPressed: active ? null : forums.reload,
                              );
                            },
                          ),
                        );
                      }
                      index -= 1;
                      if (!isModerating && cruise.isLoggedIn) {
                        if (index == 0) {
                          return ValueListenableBuilder<bool>(
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
                          );
                        }
                        index -= 1;
                      }
                      if (status.streamEnabled) {
                        if (index == 0) {
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.speaker_notes)),
                            title: const Text('Twitarr'),
                            onTap: () { Navigator.pushNamed(context, '/twitarr'); },
                          );
                        }
                        index -= 1;
                      }
                      if (status.forumsEnabled) {
                        // Forums
                        // TODO(ianh): make these appear less suddenly
                        final ForumThread forum = forumThreads[index];
                        final String unread = forum.unreadCount > 0 ? ' (${forum.unreadCount} new)' : '';
                        final String lastMessage = 'Most recent from ${forum.lastMessageUser}';
                        return ListTile(
                          leading: Tooltip(
                            message: forum.isSticky ? 'Sticky forum' : 'Forum',
                            child: Badge(
                              child: CircleAvatar(child: Icon(forum.isSticky ? Icons.feedback : Icons.forum)),
                              alignment: const AlignmentDirectional(1.1, 1.1),
                              enabled: forum.hasUnread,
                            ),
                          ),
                          title: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  forum.subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: forum.hasUnread ? const TextStyle(fontWeight: FontWeight.bold) : null,
                                ),
                              ),
                              Text(
                                ' ${prettyDuration(now.difference(forum.lastMessageTimestamp), short: true)}',
                                style: textTheme.caption,
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${forum.totalCount} message${forum.totalCount == 1 ? '' : "s"}$unread\n$lastMessage',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          onTap: () { showForumThread(context, forum); },
                        );
                      }
                    }
                    assert(false);
                    return null;
                  }
                  Widget result = generateTile();
                  if (showDividers) {
                    result = DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: Divider.createBorderSide(context),
                        ),
                      ),
                      child: result,
                    );
                  }
                  return result;
                },
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
