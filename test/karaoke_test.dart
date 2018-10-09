import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/views/karaoke.dart';
import 'package:cruisemonkey/src/progress.dart';

Future<void> main() async {
  final AssetBundle bundle = new TestAssetBundle();
  const KaraokeView().createState().initSongs(bundle);
  final Completer<void> completer = new Completer<void>();
  final Progress<void> status = KaraokeView.loadStatus;
  void listener() {
    if (status.value is SuccessfulProgress) {
      completer.complete();
      status.removeListener(listener);
    }
  }
  status.addListener(listener);
  await completer.future;

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

  testWidgets('Song', (WidgetTester tester) async {
    final List<Song> songs = <Song>[
      const Song('bb', 'aa'),
      const Song('aa', 'bb'),
      const Song('aa', 'aa'),
      const Song('bb', 'bb'),
    ];
    expect(songs, const <Song>[
      Song('bb', 'aa'),
      Song('aa', 'bb'),
      Song('aa', 'aa'),
      Song('bb', 'bb'),
    ]);
    songs.sort();
    expect(songs, const <Song>[
      Song('aa', 'aa'),
      Song('aa', 'bb'),
      Song('bb', 'aa'),
      Song('bb', 'bb'),
    ]);
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
