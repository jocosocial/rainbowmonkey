import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logic/cruise.dart';
import '../logic/forums.dart';
import '../logic/seamail.dart';
import '../logic/stream.dart';
import '../models/calendar.dart';
import '../models/search.dart';
import '../models/server_status.dart';
import '../models/user.dart';
import '../progress.dart';
import '../searchable_list.dart';
import '../widgets.dart';
import 'calendar.dart';
import 'comms.dart';
import 'stream.dart';

abstract class CardRecord extends Record {
  const CardRecord();

  @protected
  Widget buildInterior(BuildContext context, AuthenticatedUser currentUser, ServerStatus serverStatus);

  @override
  Widget buildSearchResult(BuildContext context) {
    final CruiseModel cruiseModel = Cruise.of(context);
    final ContinuousProgress<AuthenticatedUser> userProgressSource = cruiseModel.user;
    final ContinuousProgress<ServerStatus> serverStatusProgressSource = cruiseModel.serverStatus;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Card(
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[userProgressSource.best, serverStatusProgressSource.best]),
          builder: (BuildContext context, Widget child) {
            final ProgressValue<User> currentUserProgress = userProgressSource.best.value;
            final AuthenticatedUser currentUser = currentUserProgress is SuccessfulProgress<AuthenticatedUser> ? currentUserProgress.value : null;
            final ProgressValue<ServerStatus> serverStatusProgress = serverStatusProgressSource.best.value;
            final ServerStatus serverStatus = serverStatusProgress is SuccessfulProgress<ServerStatus> ? serverStatusProgress.value : const ServerStatus();
            return buildInterior(context, currentUser, serverStatus);
          },
        ),
      ),
    );
  }
}

class SeamailListEntry extends CardRecord {
  const SeamailListEntry(this.threads);

  final List<SeamailThread> threads;

  @override
  Widget buildInterior(BuildContext context, AuthenticatedUser currentUser, ServerStatus serverStatus) {
    final List<Widget> children = <Widget>[];
    for (SeamailThread thread in threads)
      children.add(SeamailListTile(thread: thread));
    assert(children.isNotEmpty);
    children.insert(0,
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'Matching seamail${ children.length == 1 ? "" : "s" }',
          style: Theme.of(context).textTheme.subhead,
        )
      ),
    );
    return ListBody(
      children: children,
    );
  }
}

class UserListEntry extends CardRecord {
  const UserListEntry(this.users);

  final List<User> users;

  void _startConversation(BuildContext context, User currentUser, User otherUser) {
    PrivateCommsView.createNewSeamail(context, currentUser, others: <User>[otherUser]);
  }

  @override
  Widget buildInterior(BuildContext context, AuthenticatedUser currentUser, ServerStatus serverStatus) {
    final List<Widget> children = <Widget>[];
    for (User user in users) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: <Widget>[
              Cruise.of(context).avatarFor(<User>[user], size: 60.0),
              const SizedBox(width: 20.0),
              Expanded(
                child: Text('$user'),
              ),
              IconButton(
                icon: const Icon(Icons.mail),
                tooltip: 'Tap to start conversation with $user',
                onPressed: (currentUser != null && serverStatus.seamailEnabled) ? () => _startConversation(context, currentUser, user) : null,
              ),
            ],
          ),
        ),
      );
    }
    assert(children.isNotEmpty);
    children.insert(0,
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'Matching user${ children.length == 1 ? "" : "s" }',
          style: Theme.of(context).textTheme.subhead,
        )
      ),
    );
    return ListBody(
      children: children,
    );
  }
}

class EventEntry extends CardRecord {
  const EventEntry(this.event);

  final Event event;

  @override
  Widget buildInterior(BuildContext context, AuthenticatedUser currentUser, ServerStatus serverStatus) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TimeSlice(
        event: event,
        now: Now.of(context),
        isLoggedIn: currentUser != null,
        direction: GrowthDirection.forward,
        isLast: true,
        lastStartTime: null,
        onFavorite: null, // TODO(ianh): support toggling favorites
        isFavorite: event.following,
        favoriteOverride: false,
      ),
    );
  }
}

class ForumListEntry extends CardRecord {
  const ForumListEntry(this.threads);

  final List<ForumThread> threads;

  @override
  Widget buildInterior(BuildContext context, AuthenticatedUser currentUser, ServerStatus serverStatus) {
    final List<Widget> children = <Widget>[];
    for (ForumThread thread in threads)
      children.add(ForumListTile(thread: thread));
    assert(children.isNotEmpty);
    children.insert(0,
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'Matching forum${ children.length == 1 ? "" : "s" }',
          style: Theme.of(context).textTheme.subhead,
        )
      ),
    );
    return ListBody(
      children: children,
    );
  }
}

class StreamListEntry extends CardRecord {
  const StreamListEntry(this.streamPosts);

  final List<StreamPost> streamPosts;

  @override
  Widget buildInterior(BuildContext context, AuthenticatedUser currentUser, ServerStatus serverStatus) {
    final List<Widget> children = <Widget>[];
    for (StreamPost post in streamPosts) {
      children.add(Entry(
        post: post,
        animation: const AlwaysStoppedAnimation<double>(1.0),
        effectiveCurrentUser: currentUser?.effectiveUser,
        stream: Cruise.of(context).tweetStream,
        canModerate: currentUser != null && currentUser.canModerate,
        isModerating: currentUser != null && currentUser.isModerating,
        canAlwaysEdit: currentUser != null && currentUser.canAlwaysEdit,
      ));
    }
    assert(children.isNotEmpty);
    children.insert(0,
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'Matching Twitarr post${ children.length == 1 ? "" : "s" }',
          style: Theme.of(context).textTheme.subhead,
        )
      ),
    );
    return ListBody(
      children: children,
    );
  }
}

class SearchSearchModel extends SearchModel<Record> {
  @override
  bool isEnabled(ServerStatus status) {
    return status.forumsEnabled
        || status.streamEnabled
        || status.seamailEnabled
        || status.calendarEnabled
        || status.userProfileEnabled
        || status.registrationEnabled;
  }

  Progress<List<Record>> _records;

  @override
  Progress<List<Record>> get records => _records ?? const Progress<List<Record>>.idle();

  @override
  SearchQueryNotifier get searchQueryNotifier {
    assert(context != null);
    return Cruise.of(context).searchQueryNotifier;
  }

  @override
  void search(String query) {
    if (query.isEmpty) {
      _records = null;
      return;
    }
    _records = Progress.convert<Set<SearchResult>, List<Record>>(
      Cruise.of(context).search(query),
      (Set<SearchResult> results) {
        final List<SeamailThread> seamailThreads = results.whereType<SeamailThread>().toList()..sort();
        final List<Event> events = results.whereType<Event>().toList()..sort();
        final List<User> users = results.whereType<User>().toList()..sort();
        final List<ForumThread> forumThreads = results.whereType<ForumThread>().toList()..sort();
        final List<StreamPost> streamPosts = results.whereType<StreamPost>().toList()..sort();
        return <Record>[
          if (seamailThreads.isNotEmpty)
            SeamailListEntry(seamailThreads),
          ...events.map<Record>((Event event) => EventEntry(event)),
          if (users.isNotEmpty)
            UserListEntry(users),
          if (forumThreads.isNotEmpty)
            ForumListEntry(forumThreads),
          if (streamPosts.isNotEmpty)
            StreamListEntry(streamPosts),
        ];
      }
    );
  }
}

final SearchableListView<Record> searchView = SearchableListView<Record>(
  searchModel: SearchSearchModel(),
  icon: const Icon(Icons.search),
  label: const Text('Search'),
);
