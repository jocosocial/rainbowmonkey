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
    songs.sort();
    return songs;
  }
}

class Song extends AssetRecord implements Comparable<Song> {
  const Song(this.title, this.artist, this.metadata);

  final String title;
  final String artist;
  final String metadata;

  @override
  int compareTo(Song other) {
    if (title == other.title)
      return artist.compareTo(other.artist);
    return title.compareTo(other.title);
  }

  @override
  bool matches(List<String> substrings) {
    return substrings.every(
      (String substring) {
        return title.toLowerCase().contains(substring)
            || artist.toLowerCase().contains(substring);
      },
    );
  }

  @override
  Widget buildSearchResult(BuildContext context) {
    final TextTheme textStyle = Theme.of(context).textTheme;
    Widget trailing;
    switch (metadata) {
      case 'M':
        trailing = Text('M', style: textStyle.caption);
        break;
      case 'VR':
        trailing = Text('VR', style: textStyle.caption);
        break;
      // 'Bowieoke' seems to mean "David Bowie sang this",
      // which is already reflected in the artist, so...
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
