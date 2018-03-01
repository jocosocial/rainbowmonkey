// This is a basic Flutter widget test.
// To perform an interaction with a widget in your test, use the WidgetTester utility that Flutter
// provides. For example, you can send tap and scroll gestures. You can also use WidgetTester to
// find child widgets in the widget tree, read text, and verify that the values of widget properties
// are correct.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/main.dart';
import 'package:cruisemonkey/network.dart';
import 'package:cruisemonkey/models.dart';

void main() {
  testWidgets('Drawer', (WidgetTester tester) async {
    final Twitarr twitarr = new TestTwitarr();
    await tester.pumpWidget(new CruiseMonkey(twitarr: twitarr));

    // Check that the drawer starts closed.
    expect(find.text('CruiseMonkey'), findsOneWidget);
    expect(find.text('Not logged in'), findsNothing);

    // Open the drawer.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump(const Duration(seconds: 1));

    // Check that now we can see the text "not logged in", and can still see the appbar title.
    expect(find.text('CruiseMonkey'), findsOneWidget);
    expect(find.text('Not logged in'), findsOneWidget);

    await tester.pumpWidget(const Placeholder());
    twitarr.dispose();
  });

  testWidgets('Calendar (Updating)', (WidgetTester tester) async {
    final TestTwitarr twitarr = new TestTwitarr();
    await tester.pumpWidget(new CruiseMonkey(twitarr: twitarr));

    expect(find.byIcon(Icons.event), findsOneWidget);
    await tester.tap(find.byIcon(Icons.event));
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

    final TestTwitarr twitarr2 = new TestTwitarr();
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
}

class TestTwitarr extends Twitarr {
  @override
  ValueNotifier<Calendar> calendar = new ValueNotifier<Calendar>(null);

  @override
  void dispose() { }
}

T getFirst<T>(Type ancestor, { Type of, WidgetTester using }) {
  return using.widgetList(find.ancestor(
    of: find.byType(of),
    matching: find.byType(ancestor),
  )).first as T;
}
