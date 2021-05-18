import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/cruise.dart';
import '../logic/forums.dart';
import '../logic/mentions.dart';
import '../logic/photo_manager.dart';
import '../models/server_status.dart';
import '../models/string.dart';
import '../models/user.dart';
import '../progress.dart';
import '../utils.dart';
import '../widgets.dart';
import 'forums.dart';
import 'stream.dart';

class MentionsView extends StatefulWidget {
  const MentionsView({
    Key key,
  }) : super(key: key);

  @override
  _MentionsViewState createState() => _MentionsViewState();
}

class _MentionsViewState extends State<MentionsView> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final DateTime now = Now.of(context);
    final CruiseModel cruise = Cruise.of(context);
    final Mentions mentions = cruise.mentions;
    final ContinuousProgress<ServerStatus> serverStatusProgress = cruise.serverStatus;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[mentions, serverStatusProgress.best]),
      builder: (BuildContext context, Widget child) {
        final List<MentionsItem> items = mentions.items.toList().reversed.toList();
        final bool hasMentions = items.isNotEmpty;
        final ServerStatus status = serverStatusProgress.currentValue ?? const ServerStatus();
        return ValueListenableBuilder<bool>(
          valueListenable: mentions.busy,
          builder: (BuildContext context, bool busy, Widget child) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Mentions'),
                actions: <Widget>[
                  ValueListenableBuilder<bool>(
                    valueListenable: cruise.isLoggedIn ? mentions.active : const AlwaysStoppedAnimation<bool>(true),
                    builder: (BuildContext context, bool active, Widget child) {
                      return IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Force refresh',
                        onPressed: busy || active ? null : mentions.reload,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: 'Clear the list of mentions',
                    onPressed: busy || !hasMentions ? null : mentions.clear,
                  ),
                ],
              ),
              body: ModeratorBuilder(
                builder: (BuildContext context, AuthenticatedUser currentUser, bool canModerate, bool isModerating) {
                  return Column(
                    children: <Widget>[
                      Expanded(
                        child: BusyIndicator(
                          busy: mentions.busy,
                          child: ListView.builder(
                            itemBuilder: (BuildContext context, int index) {
                              if (!hasMentions) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 48.0),
                                  child: iconAndLabel(icon: Icons.chat_bubble_outline, message: 'No mentions.'),
                                );
                              }
                              final MentionsItem item = items[index];
                              if (item is StreamMentionsItem) {
                                if (!status.streamEnabled)
                                  return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                                  child: ChatLine(
                                    user: item.user,
                                    messages: <TwitarrString>[ item.text ],
                                    photos: item.photo != null ? <Photo>[ item.photo, ] : null,
                                    id: item.id,
                                    likes: item.reactions.likes,
                                    timestamp: item.timestamp,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (BuildContext context) => TweetThreadView(threadId: item.id),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }
                              if (item is ForumMentionsItem) {
                                if (!status.forumsEnabled)
                                  return const SizedBox.shrink();
                                final ForumThread thread = item.thread;
                                assert(thread != null);
                                final String availability = thread == null ? ' (Forum unavailable...)' : '';
                                final String lastMessage = 'Most recent from ${item.thread.lastMessageUser}';
                                return ListTile(
                                  leading: Tooltip(
                                    message: thread.isSticky ? 'Sticky forum' : 'Forum',
                                    child: const CircleAvatar(child: Icon(Icons.forum)),
                                  ),
                                  title: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          thread.subject,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Text(
                                        ' ${prettyDuration(now.difference(thread.lastMessageTimestamp), short: true)}',
                                        style: textTheme.caption,
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${thread.totalCount} message${thread.totalCount == 1 ? '' : "s"}$availability\n$lastMessage',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  isThreeLine: true,
                                  onTap: () {
                                    assert(thread != null);
                                    Navigator.push<void>(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (BuildContext context) => ForumThreadView(thread: thread),
                                      ),
                                    );
                                  },
                                );
                              }
                              return const ListTile(
                                leading: Icon(Icons.error),
                                title: Text('Whispers on the lido deck.'),
                              );
                            },
                            itemCount: math.max(items.length, 1),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
