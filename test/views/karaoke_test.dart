import 'dart:convert';
import 'dart:typed_data';

import 'package:cruisemonkey/src/views/karaoke.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main() async {
  final AssetBundle bundle = TestAssetBundle();
  await (karaokeView.searchModel as SongSearchModel).initFromBundle(bundle).asFuture();

  testWidgets('Karaoke', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: Material(
            child: karaokeView,
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
      const Song('bb', 'aa', ''),
      const Song('aa', 'bb', ''),
      const Song('aa', 'aa', ''),
      const Song('bb', 'bb', ''),
    ];
    expect(songs, const <Song>[
      Song('bb', 'aa', ''),
      Song('aa', 'bb', ''),
      Song('aa', 'aa', ''),
      Song('bb', 'bb', ''),
    ]);
    songs.sort(SongSearchModel.compareTitles);
    expect(songs, const <Song>[
      Song('aa', 'aa', ''),
      Song('aa', 'bb', ''),
      Song('bb', 'aa', ''),
      Song('bb', 'bb', ''),
    ]);
    songs.sort(SongSearchModel.compareArtists);
    expect(songs, const <Song>[
      Song('aa', 'aa', ''),
      Song('bb', 'aa', ''),
      Song('aa', 'bb', ''),
      Song('bb', 'bb', ''),
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
      return ByteData.view(Uint8List.fromList(utf8.encode(songs)).buffer);
    return null;
  }
}
