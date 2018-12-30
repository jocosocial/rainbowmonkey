import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/network/rest.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/views/settings.dart';
import 'package:cruisemonkey/src/widgets.dart';

import '../nulls.dart';

Future<void> main() async {
  testWidgets('Settings', (WidgetTester tester) async {
    final TestCruiseModel model = TestCruiseModel();
    await tester.pumpWidget(
      MaterialApp(
        home: Cruise(
          cruiseModel: model,
          child: const Settings(),
        ),
      ),
    );
    expect(model.twitarrConfiguration, null);
    await tester.tap(find.text('gbasden\'s server'));
    await tester.pump();
    expect(model.twitarrConfiguration, const RestTwitarrConfiguration(baseUrl: 'http://69.62.137.54:42111/'));
    await tester.tap(find.text('hendusoone\'s server'));
    await tester.pump();
    expect(model.twitarrConfiguration, const RestTwitarrConfiguration(baseUrl: 'http://twitarrdev.wookieefive.net:3000/'));
  });
}

class TestCruiseModel extends NullCruiseModel with ChangeNotifier {
  @override
  TwitarrConfiguration get twitarrConfiguration => _twitarrConfiguration;
  TwitarrConfiguration _twitarrConfiguration;
  @override
  void selectTwitarrConfiguration(TwitarrConfiguration newConfiguration) {
    _twitarrConfiguration = newConfiguration;
    notifyListeners();
  }
}
