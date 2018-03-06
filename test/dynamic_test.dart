import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/dynamic.dart';
import 'package:cruisemonkey/src/progress.dart';

void main() {
  testWidgets('DynamicView', (WidgetTester tester) async {
    final CompleterWithProgress<int> completer = new CompleterWithProgress<int>();
    await tester.pumpWidget(new MaterialApp(
      home: new Material(
        child: new LoadingScreen(
          progress: completer.future,
          builder: (BuildContext context) => const SizedBox.expand(child: const Text('X')),
        ),
      ),
    ));
    final Offset center1 = tester.getCenter(find.byType(CircularProgressIndicator));
    expect(find.text('X'), findsNothing);
    completer.complete(1);
    await tester.pump();
    final Offset center2 = tester.getCenter(find.byType(CircularProgressIndicator));
    expect(find.text('X'), findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
    final Offset center3 = tester.getCenter(find.byType(CircularProgressIndicator));
    expect(find.text('X'), findsOneWidget);
    expect(center1, center2);
    expect(center2, center3);
  });
}
