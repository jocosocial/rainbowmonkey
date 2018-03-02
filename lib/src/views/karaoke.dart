import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dynamic.dart';

class KaraokeView extends StatefulWidget {
  const KaraokeView({
    Key key,
  }) : super(key: key);

  @override
  _KaraokeViewState createState() => new _KaraokeViewState();
}

class _KaraokeViewState extends State<KaraokeView> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initSongs(DefaultAssetBundle.of(context));
  }

  static String catalogResource = 'resources/JoCoKaraokeSongCatalog.txt';

  static List<Song> _songs;

  static bool _initStarted = false;
  Future<void> initSongs(AssetBundle bundle) async {
    // TODO(ianh): This doesn't support handling the case of the asset bundle
    // changing, since we only run it once even if the bundle is different.
    if (_initStarted)
      return null;
    _initStarted = true;
    _songs = await bundle.loadStructuredData<List<Song>>(
      catalogResource,
      (String data) => compute<String, List<Song>>(_parser, data),
    );
    if (mounted) {
      setState(() {
        // we've updated the catalog
      });
    }
  }

  static List<Song> _parser(String data) {
    final List<String> lines = data.split('\n');
    final List<Song> songs = <Song>[];
    for (String line in lines) {
      final List<String> parts = line.split('\t');
      if (parts.length >= 2)
        songs.add(new Song(parts[1], parts[0]));
    }
    songs.sort();
    return songs;
  }

  List<Song> _filteredList;
  final ScrollController _scrollController = new ScrollController();

  void _filter(String filter) {
    final List<String> keywords = filter.toLowerCase().split(' ');
    setState(() {
      _filteredList = _songs.where((Song song) => song.matches(keywords)).toList();
      _scrollController.jumpTo(0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return new LoadingScreen(
      ready: _songs != null,
      builder: (BuildContext context) {
        final List<Song> list = _filteredList ?? _songs;
        return new Padding(
          padding: const EdgeInsets.all(8.0),
          child: new Column(
            children: <Widget>[
              new TextField(
                decoration: new InputDecoration(
                  labelText: 'Search',
                  suffixIcon: new Icon(Icons.search),
                ),
                onChanged: _filter,
              ),
              new Expanded(
                child: new Scrollbar(
                  child: new ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: list.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Song song = list[index];
                      return new ListTile(
                        title: new Text(song.title),
                        subtitle: new Text(song.artist),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class Song implements Comparable<Song> {
  const Song(this.title, this.artist);

  final String title;
  final String artist;

  @override
  int compareTo(Song other) {
    if (title == other.title)
      return artist.compareTo(other.artist);
    return title.compareTo(other.title);
  }

  bool matches(List<String> substrings) {
    return substrings.every(
      (String substring) {
        return title.toLowerCase().contains(substring)
            || artist.toLowerCase().contains(substring);
      },
    );
  }
}
