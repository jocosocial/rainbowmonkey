import 'package:cruisemonkey/main.dart';
import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/calendar.dart';
import 'package:cruisemonkey/src/models/errors.dart';
import 'package:cruisemonkey/src/models/string.dart';
import 'package:cruisemonkey/src/progress.dart';
import 'package:cruisemonkey/src/views/calendar.dart';
import 'package:cruisemonkey/src/widgets.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../loggers.dart';
import '../mocks.dart';

Future<void> useModel(WidgetTester tester, CruiseModel model) {
  return tester.pumpWidget(
    Now.fixed(
      dateTime: DateTime(2019),
      child: MaterialApp(
        home: Cruise(
          cruiseModel: model,
          child: Material(child: CalendarView(key: PageStorageKey<UniqueObject>(UniqueObject()))),
        ),
      ),
    ),
  );
}

final DataStore store = TrivialDataStore(<String>[]);

class TestCruiseModel extends CruiseModel {
  TestCruiseModel({
    MutableContinuousProgress<Calendar> calendar,
  }) : calendar = calendar ?? MutableContinuousProgress<Calendar>(),
       super(
         initialTwitarrConfiguration: const LoggingTwitarrConfiguration(0),
         onError: (UserFriendlyError message) { },
         store: store,
       );

  @override
  final MutableContinuousProgress<Calendar> calendar;
}

void main() {
  LoggingTwitarrConfiguration.register(<String>[]);
  testWidgets('Calendar', (WidgetTester tester) async {
    final TestCruiseModel model1 = TestCruiseModel();

    Future<void> setupAppWithModel(WidgetTester tester, CruiseModel model) {
      return tester.pumpWidget(
        Now.fixed(
          dateTime: DateTime(2019),
          child: Cruise(
            cruiseModel: model,
            child: const CruiseMonkeyHome(),
          ),
        ),
      );
    }

    await setupAppWithModel(tester, model1);

    expect(find.text('Calendar is empty'), findsNothing);
    expect(find.byIcon(Icons.event), findsOneWidget);
    await tester.tap(find.byIcon(Icons.event));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Calendar is empty'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    model1.calendar.addProgress(Progress<Calendar>.completed(Calendar(events: const <Event>[])));
    await tester.pump();
    expect(find.text('Calendar is empty'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    model1.calendar.addProgress(Progress<Calendar>((ProgressController<Calendar> completer) async {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      return Calendar(events: <Event>[
        Event(
          id: 'a',
          title: 'Test A',
          location: 'Apple Deck',
          official: true,
          startTime: DateTime(2019, 3, 9, 20, 00),
          endTime: DateTime(2019, 3, 9, 21, 30),
        ),
      ]);
    }));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(getFirst<FadeTransition>(FadeTransition, of: CircularProgressIndicator, using: tester).opacity.value, 0.0);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(getFirst<FadeTransition>(FadeTransition, of: CircularProgressIndicator, using: tester).opacity.value, 1.0);

    await tester.pump(const Duration(seconds: 1));
    expect(getFirst<FadeTransition>(FadeTransition, of: CircularProgressIndicator, using: tester).opacity.value, 1.0);
    expect(find.text('Saturday March 9'), findsOneWidget);
    expect(find.text('Test A'), findsOneWidget);
    expect(find.text('Apple Deck'), findsOneWidget);
    expect(find.text('8:00pm'), findsOneWidget);
    expect(find.text('-9:30pm'), findsOneWidget);
    expect(find.text('null'), findsNothing);

    await tester.pump(const Duration(milliseconds: 10));
    expect(getFirst<FadeTransition>(FadeTransition, of: CircularProgressIndicator, using: tester).opacity.value, lessThan(1.0));

    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    model1.calendar.addProgress(Progress<Calendar>.completed(Calendar(events: <Event>[
      Event(
        id: 'a',
        title: 'Actual Event',
        location: 'Apple Deck',
        official: true,
        startTime: DateTime(2019, 3, 9, 20, 00),
        endTime: DateTime(2019, 3, 9, 21, 30),
      ),
      Event(
        id: 'b',
        title: 'Shadow Event',
        location: 'Banana Deck',
        description: const TwitarrString('Eat some food.'),
        official: false,
        startTime: DateTime(2019, 3, 9, 20, 00),
        endTime: DateTime(2019, 3, 10, 00, 00),
      ),
    ])));
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
    expect(tester.getRect(find.text('Actual Event')).bottom, lessThan(tester.getRect(find.text('Shadow Event')).top));
    expect(tester.getRect(find.text('Shadow Event')).left, equals(tester.getRect(find.text('Actual Event')).left));

    model1.calendar.addProgress(Progress<Calendar>.completed(Calendar(events: <Event>[
      Event(
        id: 'a',
        title: 'Actual Event',
        location: 'Apple Deck',
        official: true,
        startTime: DateTime(2019, 3, 9, 20, 00),
        endTime: DateTime(2019, 3, 10, 00, 00),
      ),
      Event(
        id: 'b',
        title: 'Shadow Event',
        location: 'Banana Deck',
        description: const TwitarrString('Eat some food.'),
        official: false,
        startTime: DateTime(2019, 3, 9, 20, 00),
        endTime: DateTime(2019, 3, 9, 21, 30),
      ),
    ])));
    await tester.pump();
    expect(find.text('Saturday March 9'), findsOneWidget);
    expect(find.text('Test A'), findsNothing);
    expect(find.text('Actual Event'), findsOneWidget);
    expect(find.text('Apple Deck'), findsOneWidget);
    expect(find.text('8:00pm'), findsNWidgets(2));
    expect(find.text('-12:00am'), findsOneWidget);
    expect(find.text('Shadow Event'), findsOneWidget);
    expect(find.text('Banana Deck'), findsOneWidget);
    expect(find.text('Eat some food.'), findsOneWidget);
    expect(find.text('-9:30pm'), findsOneWidget);
    expect(find.text('Sunday March 10'), findsNothing);
    expect(find.text('null'), findsNothing);
    expect(tester.getRect(find.text('Shadow Event')).bottom, lessThan(tester.getRect(find.text('Actual Event')).top));
    expect(tester.getRect(find.text('Shadow Event')).left, equals(tester.getRect(find.text('Actual Event')).left));

    model1.calendar.addProgress(Progress<Calendar>.completed(Calendar(events: <Event>[
      Event(
        id: 'c',
        title: 'Coconuts',
        location: 'Ship',
        official: true,
        startTime: DateTime(2019, 3, 9, 12, 00),
        endTime: DateTime(2019, 3, 9, 13, 00),
      ),
    ])));
    await tester.pump();
    expect(find.text('12:00nn'), findsOneWidget);
    expect(find.text('-1:00pm'), findsOneWidget);
    expect(find.text('Coconuts'), findsOneWidget);
    expect(find.text('Dragonfruit'), findsNothing);
    expect(find.text('Elderberry'), findsNothing);

    final TestCruiseModel model2 = TestCruiseModel();
    await setupAppWithModel(tester, model2);

    expect(find.text('Coconuts'), findsOneWidget);
    expect(find.text('Dragonfruit'), findsNothing);
    expect(find.text('Elderberry'), findsNothing);

    // update old calendar, check it has no effect
    model1.calendar.addProgress(Progress<Calendar>.completed(Calendar(events: <Event>[
      Event(
        id: 'd',
        title: 'Dragonfruit',
        location: 'Ship',
        official: true,
        startTime: DateTime(2019, 3, 9, 12, 00),
        endTime: DateTime(2019, 3, 9, 13, 00),
      ),
    ])));
    await tester.pump();
    expect(find.text('Coconuts'), findsOneWidget);
    expect(find.text('Dragonfruit'), findsNothing);
    expect(find.text('Elderberry'), findsNothing);

    // update calendar, check that it works
    model2.calendar.addProgress(Progress<Calendar>.completed(Calendar(events: <Event>[
      Event(
        id: 'e',
        title: 'Elderberry',
        location: 'Ship',
        official: true,
        startTime: DateTime(2019, 3, 9, 12, 00),
        endTime: DateTime(2019, 3, 9, 13, 00),
      ),
    ])));
    await tester.pump();
    expect(find.text('Coconuts'), findsOneWidget);
    expect(find.text('Dragonfruit'), findsNothing);
    expect(find.text('Elderberry'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Coconuts'), findsNothing);
    expect(find.text('Dragonfruit'), findsNothing);
    expect(find.text('Elderberry'), findsOneWidget);

    await tester.pumpWidget(const Placeholder());
    model1.dispose();
    model2.dispose();
  });

  testWidgets('Calendar (Details)', (WidgetTester tester) async {
    final TestCruiseModel model = TestCruiseModel();
    model.calendar.addProgress(Progress<Calendar>.completed(Calendar(events: <Event>[
      Event(
        id: 'f',
        title: 'Fruit',
        location: 'Ship',
        official: false,
        startTime: DateTime(2019, 3, 12, 07, 00),
        endTime: DateTime(2019, 3, 13, 07, 00),
      ),
    ])));

    await useModel(tester, model);

    expect(find.text('Tuesday March 12'), findsOneWidget);
    expect(find.text('Fruit'), findsOneWidget);
    expect(find.text('f'), findsNothing);
    expect(find.text('7:00am'), findsNothing);
    expect(find.text('all day'), findsOneWidget);
    expect(find.text('null'), findsNothing);

    model.calendar.addProgress(Progress<Calendar>.completed(Calendar(events: <Event>[
      Event(
        id: 'g',
        title: 'Grapes',
        location: 'Ship',
        official: false,
        startTime: DateTime(2020, 12, 31, 12, 10),
        endTime: DateTime(2021, 1, 1, 00, 23),
      ),
    ])));

    await tester.pump();
    expect(find.text('Thursday December 31'), findsOneWidget);
    expect(find.text('12:10pm'), findsOneWidget);
    expect(find.text('-12:23am'), findsOneWidget);

    await tester.pumpWidget(const Placeholder());
    model.dispose();
  });

  testWidgets('Calendar (no reload on return)', (WidgetTester tester) async {
    int index = 0;
    final TestCruiseModel model = TestCruiseModel(
      calendar: PeriodicProgress<Calendar>(const Duration(seconds: 1), (ProgressController<Calendar> completer) async {
        await Future<void>.delayed(const Duration(seconds: 10));
        index += 1;
        return Calendar(events: <Event>[
          Event(
            id: 'test$index',
            title: 'Test$index',
            location: 'Test $index',
            official: false,
            startTime: DateTime(2000, index, index, 0, 0),
            endTime: DateTime(2000, index, index, 0, 10),
          ),
        ]);
      }),
    );

    await useModel(tester, model);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(seconds: 2)); // 1 second into first load
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final HitTestResult result1 = tester.hitTestOnBinding(tester.getCenter(find.byType(CircularProgressIndicator)));

    await tester.pump(const Duration(seconds: 5)); // 6 seconds into first load
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final HitTestResult result2 = tester.hitTestOnBinding(tester.getCenter(find.byType(CircularProgressIndicator)));
    expect(result1.path.map((HitTestEntry entry) => entry.target),
           result2.path.map((HitTestEntry entry) => entry.target));

    await tester.pump(const Duration(seconds: 6)); // end of first load, start of next load (continually loading, since load takes longer than delay between loads)
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    final HitTestResult result3 = tester.hitTestOnBinding(tester.getCenter(find.byType(CircularProgressIndicator).first));
    expect(result2.path.map((HitTestEntry entry) => entry.target),
           isNot(result3.path.map((HitTestEntry entry) => entry.target)));

    await tester.pump(const Duration(seconds: 1)); // 2 seconds into second load, first load's progress indicator has gone away
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final HitTestResult result4 = tester.hitTestOnBinding(tester.getCenter(find.byType(CircularProgressIndicator)));
    expect(result3.path.map((HitTestEntry entry) => entry.target),
           isNot(result4.path.map((HitTestEntry entry) => entry.target)));

    await tester.pump(const Duration(seconds: 600)); // a whole bunch of updates happen here
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final HitTestResult result5 = tester.hitTestOnBinding(tester.getCenter(find.byType(CircularProgressIndicator)));
    expect(result4.path.map((HitTestEntry entry) => entry.target),
           result5.path.map((HitTestEntry entry) => entry.target));

    await tester.pumpWidget(const Placeholder());
    await tester.pump(const Duration(seconds: 10)); // give time for the final future above to get canceled
    expect(find.byType(CircularProgressIndicator), findsNothing);
    model.dispose();
  });

  testWidgets('Calendar model - sorting 1', (WidgetTester tester) async {
    final Calendar a = Calendar(events: <Event>[
      Event(
        id: 'id',
        title: 'title2',
        official: true,
        location: 'A',
        startTime: DateTime(1999),
        endTime: DateTime(2000),
      ),
      Event(
        id: 'id',
        title: 'title1',
        official: true,
        location: 'A',
        startTime: DateTime(1999),
        endTime: DateTime(2000),
      ),
    ]);
    expect(a.events, hasLength(2));
    expect(a.events.first.title, 'title1');
    expect(a.events.last.title, 'title2');
  });

  testWidgets('Calendar model - sorting 2', (WidgetTester tester) async {
    final Calendar a = Calendar(events: <Event>[
      Event(
        id: 'id',
        title: 'title2',
        official: true,
        location: 'A',
        startTime: DateTime(1999),
        endTime: DateTime(2000),
      ),
      Event(
        id: 'id',
        title: 'title1',
        official: true,
        location: 'B',
        startTime: DateTime(1999),
        endTime: DateTime(2000),
      ),
    ]);
    expect(a.events, hasLength(2));
    expect(a.events.first.title, 'title2');
    expect(a.events.last.title, 'title1');
  });
}

T getFirst<T>(Type ancestor, { Type of, WidgetTester using }) {
  return using.widgetList(find.ancestor(
    of: find.byType(of),
    matching: find.byType(ancestor),
  )).first as T;
}
