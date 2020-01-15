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
      if (line.isNotEmpty)
        games.add(Game(line));
    }
    games.sort();
    return games;
  }
}

class Game extends AssetRecord implements Comparable<Game> {
  const Game(this.name);

  final String name;

  @override
  int compareTo(Game other) {
    return name.compareTo(other.name);
  }

  @override
  bool matches(List<String> substrings) {
    return substrings.every(
      (String substring) {
        return name.toLowerCase().contains(substring);
      },
    );
  }

  @override
  Widget buildSearchResult(BuildContext context) {
    return ListTile(
      title: Text(name),
    );
  }
}

final SearchableListView<Game> gamesView = SearchableListView<Game>(
  searchModel: GameSearchModel(),
  icon: const Icon(Icons.toys),
  label: const Text('Games'),
);
