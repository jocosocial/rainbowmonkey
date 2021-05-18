import 'package:cruisemonkey/main.dart';
import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/models/errors.dart';
import 'package:cruisemonkey/src/views/deck_plans.dart';
import 'package:cruisemonkey/src/widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../loggers.dart';
import '../mocks.dart';

void main() {
  final List<String> log = <String>[];
  LoggingTwitarrConfiguration.register(log);

  testWidgets('Deck Plans', (WidgetTester tester) async {
    log.clear();
    final CruiseModel model = CruiseModel(
      initialTwitarrConfiguration: const LoggingTwitarrConfiguration(0),
      store: TrivialDataStore(log),
      onError: (UserFriendlyError error) { log.add('error: $error!'); },
    );
    await tester.pumpWidget(
      Now.fixed(
        dateTime: DateTime(2019),
        child: Cruise(
          cruiseModel: model,
          child: const CruiseMonkeyHome(),
        ),
      ),
    );

    final Finder elevatorFinder = find.byWidgetPredicate((Widget widget) => widget is CustomPaint && widget.painter is Elevator);

    expect(find.byIcon(Icons.directions_boat), findsOneWidget);
    await tester.tap(find.byIcon(Icons.directions_boat));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final double height = tester.getRect(elevatorFinder).height / 11.0;

    expectOpacities(tester, <double>[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0]);

    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.dragFrom(tester.getCenter(find.text('5')), Offset(0.0, -height - kDragSlopDefault));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.dragFrom(tester.getCenter(find.text('5')), Offset(0.0, -height * 1.6 - kDragSlopDefault));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.dragFrom(tester.getCenter(find.text('5')), Offset(0.0, -height * 1.1 - kDragSlopDefault));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.flingFrom(tester.getCenter(find.text('5')), Offset(0.0, -height * 1.1 - kDragSlopDefault), 1000.0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0]);

    await tester.dragFrom(tester.getCenter(find.text('5')), Offset(0.0, height * 7.1 + kDragSlopDefault));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.flingFrom(tester.getCenter(find.text('5')), Offset(0.0, -height * 7.1 - kDragSlopDefault), 1000.0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0]);

    await tester.flingFrom(tester.getCenter(find.text('5')), Offset(0.0, height * 6.2 + kDragSlopDefault), 1000.0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('9')));
    await gesture.moveBy(const Offset(0.0, kDragSlopDefault));
    await gesture.moveBy(Offset(0.0, height * 0.5));
    await tester.pump();
    expectOpacities(tester, <double>[0.0, 0.5, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.pumpWidget(const Placeholder());
    model.dispose();
  });
}

void expectOpacities(WidgetTester tester, List<double> opacities) {
  final List<FadeTransition> transitions = tester.widgetList(find.descendant(
    of: find.byType(Deck),
    matching: find.byType(FadeTransition),
  )).map<FadeTransition>((Widget widget) => widget as FadeTransition).toList();
  expect(transitions, hasLength(opacities.length));
  expect(transitions.map<double>((FadeTransition transition) => transition.opacity.value), opacities);
}
