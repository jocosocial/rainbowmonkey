import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../progress.dart';
import '../widgets.dart';

typedef bool Filter<T>(T element);

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
  static Progress<List<Song>> _songs;

  static bool _initStarted = false;
  void initSongs(AssetBundle bundle) async {
    // TODO(ianh): This doesn't support handling the case of the asset bundle
    // changing, since we only run it once even if the bundle is different.
    // (that should only matter for tests though, in normal execution the bundle won't change)
    if (_initStarted) {
      assert(_songs != null);
      return;
    }
    assert(_songs == null);
    _initStarted = true;
    _songs = new Progress<List<Song>>((ProgressController<List<Song>> completer) async {
      return await bundle.loadStructuredData<List<Song>>(
        catalogResource,
        (String data) => compute<String, List<Song>>(_parser, data),
      );
    });
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

  Filter<Song> _filter;
  final ScrollController _scrollController = new ScrollController();

  void _applyFilter(String query) {
    setState(() {
      query = query.trim();
      if (query.isEmpty) {
        _filter = null;
      } else {
        final List<String> keywords = query.toLowerCase().split(' ');
        _filter = (Song song) => song.matches(keywords);
      }
      _scrollController.jumpTo(0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return new ProgressBuilder<List<Song>>(
      progress: _songs,
      builder: (BuildContext context, List<Song> songList) {
        if (_filter != null)
          songList = songList.where(_filter).toList();
        return new Padding(
          padding: const EdgeInsets.all(8.0),
          child: new Column(
            children: <Widget>[
              new TextField(
                decoration: const InputDecoration(
                  labelText: 'Search',
                  suffixIcon: const Icon(Icons.search),
                ),
                onChanged: _applyFilter,
              ),
              new Expanded(
                child: new Scrollbar(
                  child: new ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: songList.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Song song = songList[index];
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
