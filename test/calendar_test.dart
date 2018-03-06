import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/main.dart';
import 'package:cruisemonkey/src/models/calendar.dart';
import 'package:cruisemonkey/src/network/network.dart';
import 'package:cruisemonkey/src/progress.dart';

import 'mocks.dart';

void main() {
  testWidgets('Calendar', (WidgetTester tester) async {
    final TestTwitarr twitarr = new TestTwitarr()
      ..calendar.startProgress();
    await tester.pumpWidget(new CruiseMonkey(twitarr: twitarr));

    expect(find.byIcon(Icons.event), findsOneWidget);
    await tester.tap(find.byIcon(Icons.event));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(getFirst<FadeTransition>(FadeTransition, of: CircularProgressIndicator, using: tester).opacity.value, 1.0);

    twitarr.calendar.value = new Calendar(events: <Event>[
      new Event(
        id: 'a',
        title: 'Test A',
        location: 'Apple Deck',
        official: true,
        startTime: new DateTime(2019, 3, 9, 20, 00),
        endTime: new DateTime(2019, 3, 9, 21, 30),
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(getFirst<FadeTransition>(FadeTransition, of: CircularProgressIndicator, using: tester).opacity.value, 0.0);
    expect(find.text('Saturday March 9'), findsOneWidget);
    expect(find.text('Test A'), findsOneWidget);
    expect(find.text('Apple Deck'), findsOneWidget);
    expect(find.text('8:00pm'), findsOneWidget);
    expect(find.text('-9:30pm'), findsOneWidget);
    expect(find.text('null'), findsNothing);

    twitarr.calendar.value = new Calendar(events: <Event>[
      new Event(
        id: 'a',
        title: 'Actual Event',
        location: 'Apple Deck',
        official: true,
        startTime: new DateTime(2019, 3, 9, 20, 00),
        endTime: new DateTime(2019, 3, 9, 21, 30),
      ),
      new Event(
        id: 'b',
        title: 'Shadow Event',
        location: 'Banana Deck',
        description: 'Eat some food.',
        official: false,
        startTime: new DateTime(2019, 3, 9, 20, 00),
        endTime: new DateTime(2019, 3, 10, 00, 00),
      ),
    ]);
    await tester.pump();
    expect(find.text('Saturday March 9'), findsOneWidget);
    expect(find.text('Test A'), findsNothing);
    expect(find.text('Actual Event'), findsOneWidget);
    expect(find.text('Apple Deck'), findsOneWidget);
    expect(find.text('8:00pm'), findsNWidgets(2));
    expect(find.text('-9:30pm'), findsOneWidget);
    expect(find.text('Shadow Event'), findsOneWidget);
    expect(find.text('Banana Deck'), findsOneWidget);
    expect(find.text('Eat some food.'), findsOneWidget);
    expect(find.text('-12:00am'), findsOneWidget);
    expect(find.text('Sunday March 10'), findsNothing);
    expect(find.text('null'), findsNothing);
    expect(tester.getRect(find.text('Shadow Event')).bottom, lessThan(tester.getRect(find.text('Actual Event')).top));
    expect(tester.getRect(find.text('Shadow Event')).left, equals(tester.getRect(find.text('Actual Event')).left));

    twitarr.calendar.value = new Calendar(events: <Event>[
      new Event(
        id: 'c',
        title: 'Coconuts',
        location: 'Ship',
        official: true,
        startTime: new DateTime(2019, 3, 9, 12, 00),
        endTime: new DateTime(2019, 3, 9, 13, 00),
      ),
    ]);
    await tester.pump();
    expect(find.text('12:00nn'), findsOneWidget);
    expect(find.text('-1:00pm'), findsOneWidget);
    expect(find.text('Coconuts'), findsOneWidget);

    final TestTwitarr twitarr2 = new TestTwitarr()
      ..calendar.startProgress();
    await tester.pumpWidget(new CruiseMonkey(twitarr: twitarr2));
    expect(find.text('Coconuts'), findsOneWidget);

    // update old calendar, check it has no effect
    twitarr.calendar.value = new Calendar(events: <Event>[
      new Event(
        id: 'd',
        title: 'Dragonfruit',
        location: 'Ship',
        official: true,
        startTime: new DateTime(2019, 3, 9, 12, 00),
        endTime: new DateTime(2019, 3, 9, 13, 00),
      ),
    ]);
    await tester.pump();
    expect(find.text('Coconuts'), findsOneWidget);
    expect(find.text('Dragonfruit'), findsNothing);

    // update new calendar, check that it works
    twitarr2.calendar.value = new Calendar(events: <Event>[
      new Event(
        id: 'e',
        title: 'Elderberry',
        location: 'Ship',
        official: true,
        startTime: new DateTime(2019, 3, 9, 12, 00),
        endTime: new DateTime(2019, 3, 9, 13, 00),
      ),
    ]);
    await tester.pump();
    expect(find.text('Coconuts'), findsNothing);
    expect(find.text('Dragonfruit'), findsNothing);
    expect(find.text('Elderberry'), findsOneWidget);

    await tester.pumpWidget(const Placeholder());
    twitarr.dispose();
    twitarr2.dispose();
  });

  testWidgets('Calendar (Details)', (WidgetTester tester) async {
    final TestTwitarr twitarr = new TestTwitarr();
    twitarr.calendar.value = new Calendar(events: <Event>[
      new Event(
        id: 'f',
        title: 'Fruit',
        location: 'Ship',
        official: false,
        startTime: new DateTime(2019, 3, 12, 07, 00),
        endTime: new DateTime(2019, 3, 13, 07, 00),
      ),
    ]);

    await tester.pumpWidget(new CruiseMonkey(twitarr: twitarr));
    expect(getFirst<FadeTransition>(FadeTransition, of: CircularProgressIndicator, using: tester).opacity.value, 0.0);
    expect(find.text('Tuesday March 12'), findsOneWidget);
    expect(find.text('Fruit'), findsOneWidget);
    expect(find.text('f'), findsNothing);
    expect(find.text('7:00am'), findsNothing);
    expect(find.text('all day'), findsOneWidget);
    expect(find.text('null'), findsNothing);

    twitarr.calendar.value = new Calendar(events: <Event>[
      new Event(
        id: 'g',
        title: 'Grapes',
        location: 'Ship',
        official: false,
        startTime: new DateTime(2020, 12, 31, 12, 10),
        endTime: new DateTime(2021, 1, 1, 00, 23),
      ),
    ]);

    await tester.pumpWidget(new CruiseMonkey(twitarr: twitarr));
    expect(find.text('Thursday December 31'), findsOneWidget);
    expect(find.text('12:10pm'), findsOneWidget);
    expect(find.text('-12:23am'), findsOneWidget);

    await tester.pumpWidget(const Placeholder());
    twitarr.dispose();
  });

  testWidgets('Calendar (no reload on return)', (WidgetTester tester) async {
    int index = 0;
    final Twitarr twitarr = new AutoupdatingTestTwitarr(
      calendarGetter: () {
        final CompleterWithProgress<Calendar> completer = new CompleterWithProgress<Calendar>();
        new Future<void>.delayed(const Duration(seconds: 10)).then((void data) {
          index += 1;
          completer.complete(new Calendar(events: <Event>[
            new Event(
              id: 'test$index',
              title: 'Test$index',
              location: 'Test $index',
              official: false,
              startTime: new DateTime(2000, index, index, 0, 0),
              endTime: new DateTime(2000, index, index, 0, 10),
            ),
          ]));
        });
        return completer.future;
      },
    );
    await tester.pumpWidget(new CruiseMonkey(twitarr: twitarr));
    final HitTestResult result1 = tester.hitTestOnBinding(tester.getCenter(find.byType(CircularProgressIndicator)));
    await tester.pump(const Duration(seconds: 6));
    final HitTestResult result2 = tester.hitTestOnBinding(tester.getCenter(find.byType(CircularProgressIndicator)));
    expect(result1.path.map((HitTestEntry entry) => entry.target),
           result2.path.map((HitTestEntry entry) => entry.target));

    await tester.pump(const Duration(seconds: 6));
    final HitTestResult result3 = tester.hitTestOnBinding(tester.getCenter(find.byType(CircularProgressIndicator)));
    expect(result2.path.map((HitTestEntry entry) => entry.target),
           isNot(result3.path.map((HitTestEntry entry) => entry.target)));

    await tester.pump(const Duration(seconds: 600));

    final HitTestResult result4 = tester.hitTestOnBinding(tester.getCenter(find.byType(CircularProgressIndicator)));
    expect(result3.path.map((HitTestEntry entry) => entry.target),
           result4.path.map((HitTestEntry entry) => entry.target));

    await tester.pump(const Duration(seconds: 10));

    final HitTestResult result5 = tester.hitTestOnBinding(tester.getCenter(find.byType(CircularProgressIndicator)));
    expect(result4.path.map((HitTestEntry entry) => entry.target),
           result5.path.map((HitTestEntry entry) => entry.target));

    await tester.pumpWidget(const Placeholder());
    await tester.pump(const Duration(seconds: 10)); // give time for the final future above to get canceled
    twitarr.dispose();
  });
}

T getFirst<T>(Type ancestor, { Type of, WidgetTester using }) {
  return using.widgetList(find.ancestor(
    of: find.byType(of),
    matching: find.byType(ancestor),
  )).first as T;
}
