import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logic/forums.dart';
import '../logic/seamail.dart';
import '../models/user.dart';
import '../progress.dart';
import '../utils.dart';
import '../widgets.dart';
//import 'forums.dart';
import 'seamail.dart';

class CommsView extends StatelessWidget implements View {
  const CommsView({
    Key key,
  }) : super(key: key);

  @override
  Widget buildTab(BuildContext context) {
    final Seamail seamail = Cruise.of(context).seamail;
    return AnimatedBuilder(
      animation: seamail,
      builder: (BuildContext context, Widget child) {
        return Tab(
          text: 'Messages',
          icon: Badge(
            child: child,
            enabled: seamail.unreadCount > 0,
          ),
        );
      },
      child: const Icon(Icons.mail),
    );
  }

  @override
  Widget buildFab(BuildContext context) {
    return ValueListenableBuilder<ProgressValue<AuthenticatedUser>>(
      valueListenable: Cruise.of(context).user.best,
      builder: (BuildContext context, ProgressValue<AuthenticatedUser> user, Widget child) {
        const Widget icon = Icon(Icons.add_comment);
        if (user is SuccessfulProgress<AuthenticatedUser> && user.value != null) {
          return FloatingActionButton(
            child: icon,
            onPressed: () {
              // TODO(ianh): add an interstitial to pick private vs public
              _createNewSeamail(context, user.value);
            },
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

  static void showThread(BuildContext context, SeamailThread thread) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SeamailThreadView(thread: thread),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle headerStyle = Theme.of(context).textTheme.title;
    final Seamail seamail = Cruise.of(context).seamail;
    final Forums forums = Cruise.of(context).forums;
    return BusyIndicator(
      busy: OrListenable(<ValueListenable<bool>>[seamail.busy, /*forums.busy*/]),
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[seamail, forums]),
        builder: (BuildContext context, Widget child) {
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
                if (b.lastMessageTimestamp != a.lastMessageTimestamp)
                  return b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp);
                return b.id.compareTo(a.id);
              }
            );
          return ListView.builder(
            itemCount: 2 /*headings*/ + math.max<int>(seamailThreads.length, 1) /*seamail*/ + 1 /*twitarr*/ + forums.length /*forums*/,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return ListTile(
                  title: Text('Private messages', style: headerStyle),
                );
              }
              index -= 1;
              if (seamailThreads.isEmpty) {
                if (index == 0) { // ignore: invariant_booleans
                  if (Cruise.of(context).isLoggedIn) {
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
                  return ListTile(
                    leading: CircleAvatar(child: Text('${thread.users.length}')), // TODO(ianh): faces
                    title: Text(thread.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${thread.totalCount} message${thread.totalCount == 1 ? '' : "s"}',
                      style: thread.hasUnread ? const TextStyle(fontWeight: FontWeight.bold) : null,
                    ),
                    onTap: () { showThread(context, thread); },
                  );
                }
                index -= seamailThreads.length;
              }
              if (index == 0) {
                return ListTile(
                  title: Text('Public messages', style: headerStyle),
                );
              }
              index -= 1;
              if (index == 0) {
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.speaker_notes)),
                  title: const Text('Twitarr'),
                  onTap: () { Navigator.pushNamed(context, '/twitarr'); },
                );
              }
              index -= 1;
              // Forums
              final ForumThread forum = forumThreads[index];
              final String unread = forum.unreadCount > 0 ? ' (${forum.unreadCount} new)' : '';
              final DateTime now = Now.of(context);
              final String duration = '${prettyDuration(now.difference(forum.lastMessageTimestamp))}';
              final String lastMessage = 'Most recent from ${forum.lastMessageUser} $duration';
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.forum)),
                title: Text(forum.subject),
                subtitle: Text('${forum.totalCount} message${forum.totalCount == 1 ? '' : "s"}$unread\n$lastMessage'),
                isThreeLine: true,
                onTap: () {
                  // TODO(ianh): Show the forum!
                },
              );
            },
          );
        },
      ),
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
    return 'OrListenable([${_children.join(", ")}])';
  }
}
