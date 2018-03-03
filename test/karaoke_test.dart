import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/views/karaoke.dart';

Future<void> main() async {
  final AssetBundle bundle = new TestAssetBundle();
  await const KaraokeView().createState().initSongs(bundle);

  testWidgets('Karaoke', (WidgetTester tester) async {
    await tester.pumpWidget(
      new MaterialApp(
        home: new DefaultAssetBundle(
          bundle: bundle,
          child: const Material(
            child: const KaraokeView(),
          ),
        ),
      ),
    );
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(find.text('I Feel Fantastic'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'my');
    await tester.pump();
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.text('I Feel Fantastic'), findsNothing);
    await tester.enterText(find.byType(TextField), 'shot my');
    await tester.pump();
    expect(find.byType(ListTile), findsNWidgets(1));
    expect(find.text('I Feel Fantastic'), findsNothing);
    expect(find.text('Alexander Hamilton'), findsOneWidget);
  });
}

class TestAssetBundle extends CachingAssetBundle {
  static const String songs =
    'My Artist\tMy Song\n'
    'Alexander Hamilton\tMy Shot\n'
    'Jonathan Coulton\tI Feel Fantastic';

  @override
  Future<ByteData> load(String key) async {
    if (key == 'resources/JoCoKaraokeSongCatalog.txt')
      return new ByteData.view(new Uint8List.fromList(utf8.encode(songs)).buffer);
    return null;
  }
}
