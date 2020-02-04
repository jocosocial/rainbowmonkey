import 'package:flutter/material.dart';

import '../models/server_status.dart';
import '../searchable_list.dart';

class GameSearchModel extends AssetSearchModel<Game> {
  @override
  bool isEnabled(ServerStatus status) => status.gamesEnabled;

  @override
  String get resourceName => 'resources/JoCoGamesCatalog.txt';

  @override
  Parser<Game> parser() => _parser;

  static List<Game> _parser(String data) {
    final List<String> lines = data.split('\n');
    final List<Game> games = <Game>[];
    for (String line in lines) {
      if (line.isNotEmpty) {
        final List<String> cells = line.split('\t');
        assert(cells.length == 2);
        games.add(Game(cells.first, int.parse(cells.last)));
      }
    }
    games.sort();
    return games;
  }

  @override
  bool matches(Game record, List<String> substrings) {
    return substrings.every(
      (String substring) {
        return record.name.toLowerCase().contains(substring);
      },
    );
  }
}

class Game extends Record implements Comparable<Game> {
  const Game(this.name, this.count);

  final String name;

  final int count;

  @override
  int compareTo(Game other) {
    return name.compareTo(other.name);
  }

  @override
  Widget buildSearchResult(BuildContext context) {
    return ListTile(
      title: Text(name),
      trailing: Tooltip(
        message: 'Number of copies',
        child: Text('$count'),
      ),
    );
  }
}

final SearchableListView<Game> gamesView = SearchableListView<Game>(
  searchModel: GameSearchModel(),
  icon: const Icon(Icons.toys),
  label: const Text('Games'),
);
