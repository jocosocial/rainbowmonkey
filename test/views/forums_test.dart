import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/models/errors.dart';
import 'package:cruisemonkey/src/models/reactions.dart';
import 'package:cruisemonkey/src/models/string.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/progress.dart';
import 'package:cruisemonkey/src/views/comms.dart';
import 'package:cruisemonkey/src/widgets.dart';

import '../loggers.dart';
import '../mocks.dart';

class ForumsTwitarrConfiguration extends LoggingTwitarrConfiguration {
  const ForumsTwitarrConfiguration(int id) : super(id);

  @override
  ForumsTwitarr createTwitarr() => ForumsTwitarr(this, LoggingTwitarrConfiguration.log);
}

class ForumsTwitarr extends LoggingTwitarr {
  ForumsTwitarr(ForumsTwitarrConfiguration configuration, List<String> log) : super(configuration, log);

  @override
  Progress<ForumListSummary> getForumThreads({
    Credentials credentials,
    @required int fetchCount,
  }) {
    addLog('getForumThreads $fetchCount');
    return Progress<ForumListSummary>.completed(ForumListSummary(
      forums: List<ForumSummary>.generate(fetchCount, (int index) => ForumSummary(
        id: 'id$index',
        subject: 'subject$index',
        sticky: false,
        locked: false,
        totalCount: 1,
        unreadCount: 0,
        lastMessageUser: UserSummary(username: 'user$index', photoTimestamp: DateTime(2019)),
        lastMessageTimestamp: DateTime(2019).add(Duration(minutes: -index)),
      )).toSet(),
      totalCount: 300,
    ));
  }

  @override
  Progress<ForumSummary> getForumThread({
    Credentials credentials,
    @required String threadId,
  }) {
    addLog('getForumThread $threadId');
    final int index = int.parse(threadId.substring(2)); // generated as 'id$index'
    return Progress<ForumSummary>.completed(ForumSummary(
      id: threadId,
      subject: 'subject$threadId',
      sticky: false,
      locked: false,
      totalCount: 1,
      unreadCount: 0,
      lastMessageUser: UserSummary(username: 'user$index', photoTimestamp: DateTime(2019)),
      lastMessageTimestamp: DateTime(2019).add(Duration(minutes: -index)),
      messages: <ForumMessageSummary>[
        ForumMessageSummary(
          id: 'message${threadId}_0',
          user: UserSummary(username: 'user$index', photoTimestamp: DateTime(2019)),
          text: TwitarrString('message 0 of thread $threadId'),
          photos: null,
          timestamp: DateTime(2019).add(Duration(minutes: -index)),
          read: true,
          reactions: <String, ReactionSummary>{},
        ),
      ],
    ));
  }
}

void main() {
  final List<String> log = <String>[];
  LoggingTwitarrConfiguration.register(log);

  testWidgets('Forums page', (WidgetTester tester) async {
    log.clear();
    final CruiseModel model = CruiseModel(
      initialTwitarrConfiguration: const ForumsTwitarrConfiguration(0),
      store: TrivialDataStore(log),
      onError: (UserFriendlyError error) { log.add('error: $error'); },
    );
    await model.login(username: 'username', password: 'password').asFuture();

    log.add('--bookmark 1--');

    await tester.pumpWidget(
      MaterialApp(
        home: Now.fixed(
          dateTime: DateTime(2019),
          child: Cruise(
            cruiseModel: model,
            child: const Material(
              child: PublicCommsView(),
            ),
          ),
        ),
      ),
    );

    log.add('--bookmark 2--');

    expect(find.text('subject0'), findsNothing);
    expect(find.text('subject1'), findsNothing);
    expect(find.text('subject4'), findsNothing);
    expect(find.text('subject5'), findsNothing);
    expect(find.text('...'), findsNothing);
    await tester.pump();
    expect(find.text('subject0'), findsOneWidget);
    expect(find.text('subject1'), findsOneWidget);
    expect(find.text('subject4'), findsOneWidget);
    expect(find.text('subject5'), findsNothing);
    expect(find.text('...'), findsNothing);

    await tester.drag(
      find.byType(CustomScrollView),
      Offset(
        0.0,
        -75 * tester.getSize(
          find.ancestor(
            of: find.text('subject1'),
            matching: find.byType(ListTile),
          )
        ).height
      ),
    );

    log.add('--bookmark 3--');
    await tester.pump();
    expect(find.text('subject0'), findsNothing);
    expect(find.text('subject4'), findsNothing);
    expect(find.text('subject71'), findsNothing);
    expect(find.text('subject72'), findsOneWidget);
    expect(find.text('subject73'), findsOneWidget);
    expect(find.text('subject74'), findsOneWidget);
    expect(find.text('subject75'), findsNothing);
    expect(find.text('subject76'), findsNothing);
    expect(find.text('subject77'), findsNothing);
    expect(find.text('subject78'), findsNothing);
    expect(find.text('subject79'), findsNothing);
    expect(find.text('subject80'), findsNothing);
    expect(find.text('...'), findsNWidgets(5));

    log.add('--bookmark 4--');
    await tester.pump();
    expect(find.text('subject0'), findsNothing);
    expect(find.text('subject4'), findsNothing);
    expect(find.text('subject71'), findsNothing);
    expect(find.text('...'), findsNothing);
    expect(find.text('subject72'), findsOneWidget);
    expect(find.text('subject73'), findsOneWidget);
    expect(find.text('subject74'), findsOneWidget);
    expect(find.text('subject75'), findsOneWidget);
    expect(find.text('subject76'), findsOneWidget);
    expect(find.text('subject77'), findsOneWidget);
    expect(find.text('subject78'), findsOneWidget);
    expect(find.text('subject79'), findsOneWidget);
    expect(find.text('subject80'), findsNothing);

    log.add('--end--');

    await tester.pumpWidget(Container());
    model.dispose();
    await tester.idle(); // give timers time to be canceled

    expect(log, <String>[
            'LoggingDataStore.restoreSettings',
            'LoggingTwitarr(0).login username / password',
            'LoggingDataStore.restoreCredentials',
            'LoggingDataStore.saveCredentials Credentials(username)',
            '--bookmark 1--',
            'LoggingTwitarr(0).getCalendar(Credentials(username))',
            'LoggingTwitarr(0).getAnnouncements()',
            'LoggingTwitarr(0).getSectionStatus()',
            'ForumsTwitarr(0).getUpdateIntervals()',
            'getForumThreads 75',
            'getMentions',
            '--bookmark 2--',
            '--bookmark 3--',
            'getForumThreads 170',
            '--bookmark 4--',
            '--end--',
            'ForumsTwitarr(0).dispose()'
    ]);
  });

  testWidgets('Forum itself', (WidgetTester tester) async {
    log.clear();
    final CruiseModel model = CruiseModel(
      initialTwitarrConfiguration: const ForumsTwitarrConfiguration(0),
      store: TrivialDataStore(log),
      onError: (UserFriendlyError error) { log.add('error: $error'); },
    );
    await model.login(username: 'username', password: 'password').asFuture();

    log.add('--bookmark 1--');

    await tester.pumpWidget(
      Cruise(
        cruiseModel: model,
        child: Now.fixed(
          dateTime: DateTime(2019),
          child: const MaterialApp(
            home: Material(
              child: PublicCommsView(),
            ),
          ),
        ),
      ),
    );

    log.add('--bookmark 2--');

    expect(find.text('subject0'), findsNothing);
    await tester.pump();
    expect(find.text('subject0'), findsOneWidget);

    log.add('--bookmark 3--');

    await tester.tap(find.text('subject0'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.getRect(find.byType(TextField)), const Rect.fromLTRB(0.0, 552.0, 704.0, 600.0));

    log.add('--end--');

    await tester.pumpWidget(Container());
    model.dispose();
    await tester.idle(); // give timers time to be canceled

    expect(log, <String>[
            'LoggingDataStore.restoreSettings',
            'LoggingTwitarr(0).login username / password',
            'LoggingDataStore.restoreCredentials',
            'LoggingDataStore.saveCredentials Credentials(username)',
            '--bookmark 1--',
            'LoggingTwitarr(0).getCalendar(Credentials(username))',
            'LoggingTwitarr(0).getAnnouncements()',
            'LoggingTwitarr(0).getSectionStatus()',
            'ForumsTwitarr(0).getUpdateIntervals()',
            'getForumThreads 75',
            'getMentions',
            '--bookmark 2--',
            '--bookmark 3--',
            'getForumThread id0',
            'LoggingTwitarr(0).getAuthenticatedUser Credentials(username)',
            'LoggingTwitarr(0).getAnnouncements()',
            'LoggingTwitarr(0).getSectionStatus()',
            'ForumsTwitarr(0).getUpdateIntervals()',
            'fetchProfilePicture',
            '--end--',
            'ForumsTwitarr(0).dispose()'
    ]);
  });
}