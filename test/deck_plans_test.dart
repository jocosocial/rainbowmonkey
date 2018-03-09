import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/main.dart';
import 'package:cruisemonkey/src/widgets.dart';
import 'package:cruisemonkey/src/views/deck_plans.dart';

import 'mocks.dart';

void main() {
  testWidgets('Deck Plans', (WidgetTester tester) async {
    final TestCruiseModel model = new TestCruiseModel();
    await tester.pumpWidget(
      new Cruise(
        cruiseModel: model,
        child: const CruiseMonkeyHome(),
      ),
    );

    expect(find.byIcon(Icons.directions_boat), findsOneWidget);
    await tester.tap(find.byIcon(Icons.directions_boat));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final double height = tester.getRect(find.byType(DeckPlanView)).height / 10.0;

    expectOpacities(tester, <double>[1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.dragFrom(tester.getCenter(find.text('5')), new Offset(0.0, -height));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.dragFrom(tester.getCenter(find.text('5')), new Offset(0.0, -height * 1.6));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.dragFrom(tester.getCenter(find.text('5')), new Offset(0.0, -height * 1.1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0]);

    await tester.flingFrom(tester.getCenter(find.text('5')), new Offset(0.0, -height * 1.1), 1000.0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0]);

    await tester.dragFrom(tester.getCenter(find.text('5')), new Offset(0.0, height * 7.1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.flingFrom(tester.getCenter(find.text('5')), new Offset(0.0, -height * 7.1), 1000.0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0]);

    await tester.flingFrom(tester.getCenter(find.text('5')), new Offset(0.0, height * 6.2), 1000.0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectOpacities(tester, <double>[0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('9')));
    await gesture.moveBy(new Offset(0.0, height * 0.5));
    expectOpacities(tester, <double>[0.0, 0.5, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

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
