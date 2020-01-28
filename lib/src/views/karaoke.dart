import 'package:flutter/material.dart';

import '../models/server_status.dart';
import '../searchable_list.dart';

class SongSearchModel extends AssetSearchModel<Song> {
  @override
  bool isEnabled(ServerStatus status) => status.karaokeEnabled;

  @override
  String get resourceName => 'resources/JoCoKaraokeSongCatalog.txt';

  @override
  Parser<Song> parser() => _parser;

  static List<Song> _parser(String data) {
    final List<String> lines = data.split('\n');
    final List<Song> songs = <Song>[];
    for (String line in lines) {
      final List<String> parts = line.split('\t');
      if (parts.length >= 2)
        songs.add(Song(parts[1], parts[0], parts.length > 2 ? parts[2] : ''));
    }
    songs.sort(compareTitles);
    return songs;
  }

  bool _sortByTitles = true;

  @override
  List<Song> sort(List<Song> records) {
    if (_sortByTitles)
      return records.toList()..sort(compareTitles);
    return records.toList()..sort(compareArtists);
  }

  static int compareTitles(Song a, Song b) {
    if (a.title == b.title)
      return a.artist.compareTo(b.artist);
    return a.title.compareTo(b.title);
  }

  static int compareArtists(Song a, Song b) {
    if (a.artist == b.artist)
      return a.title.compareTo(b.title);
    return a.artist.compareTo(b.artist);
  }

  bool _searchTitles = true;
  bool _searchArtists = true;

  bool get _searchMetadata => _searchTitles && _searchArtists;

  @override
  bool matches(Song record, List<String> substrings) {
    return substrings.every(
      (String substring) {
        return (record.title.toLowerCase().contains(substring) && _searchTitles)
            || (record.artist.toLowerCase().contains(substring) && _searchArtists)
            || (record.metadata.toLowerCase().contains(substring) && _searchMetadata);
      },
    );
  }

  @override
  Iterable<Widget> buildToolbar(BuildContext context) sync* {
    assert(setState != null);
    yield Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Wrap(
              spacing: 8.0,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Search all'),
                  selected: _searchTitles && _searchArtists,
                  onSelected: (bool selected) {
                    assert(setState != null);
                    if (selected) {
                      setState(() {
                        _searchTitles = true;
                        _searchArtists = true;
                      });
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Songs'),
                  selected: _searchTitles && !_searchArtists,
                  onSelected: (bool selected) {
                    assert(setState != null);
                    if (selected) {
                      setState(() {
                        _searchTitles = true;
                        _searchArtists = false;
                      });
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Artists'),
                  selected: _searchArtists && !_searchTitles,
                  onSelected: (bool selected) {
                    assert(setState != null);
                    if (selected) {
                      setState(() {
                        _searchTitles = false;
                        _searchArtists = true;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          PopupMenuButton<bool>(
            icon: Icon(Icons.sort),
            onSelected: (bool result) { setState(() { _sortByTitles = result; }); },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<bool>>[
              CheckedPopupMenuItem<bool>(
                value: true,
                checked: _sortByTitles,
                child: const Text('Sort by titles'),
              ),
              CheckedPopupMenuItem<bool>(
                value: false,
                checked: !_sortByTitles,
                child: const Text('Sort by artists'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Song extends Record {
  const Song(this.title, this.artist, this.metadata);

  final String title;
  final String artist;
  final String metadata;

  @override
  Widget buildSearchResult(BuildContext context) {
    final TextTheme textStyle = Theme.of(context).textTheme;
    Widget trailing;
    switch (metadata) {
      case 'M':
        trailing = Tooltip(
          message: 'Home-made MIDI version. Quality may be questionable.',
          child: Text('MIDI', style: textStyle.caption, textAlign: TextAlign.right),
        );
        break;
      case 'VR':
        trailing = Tooltip(
          message: 'Track made by switching the stereo channels to drop the middle channel. Quality may be questionable.',
          child: Text('REDUCED\nVOCALS', style: textStyle.caption, textAlign: TextAlign.right),
        );
        break;
      case 'Bowieoke':
        trailing = Tooltip(
          message: 'ALL BOWIE KARAOKE',
          child: Text('BOWIEOKE', style: textStyle.caption, textAlign: TextAlign.right),
        );
        break;
      case '(No Lyrics)':
        trailing = Tooltip(
          message: 'This track does not show any lyrics on the screen.',
          child: Text('NO LYRICS', style: textStyle.caption, textAlign: TextAlign.right),
        );
        break;
    }
    return ListTile(
      title: Text(title),
      subtitle: Text(artist),
      trailing: trailing,
    );
  }
}

final SearchableListView<Song> karaokeView = SearchableListView<Song>(
  searchModel: SongSearchModel(),
  icon: const Icon(Icons.library_music),
  label: const Text('Karaoke'),
);
