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
      new MaterialApp(
        home: new Cruise(
          cruiseModel: model,
          child: const Settings(),
        ),
      ),
    );
    expect(model.twitarrConfiguration, null);
    await tester.tap(find.text('prosedev.com test server'));
    await tester.pump();
    expect(model.twitarrConfiguration, const RestTwitarrConfiguration(baseUrl: 'http://drang.prosedev.com:3000/api/v2/'));
    await tester.tap(find.text('example.com'));
    await tester.pump();
    expect(model.twitarrConfiguration, const RestTwitarrConfiguration(baseUrl: 'http://example.com/'));
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
