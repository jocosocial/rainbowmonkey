import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../progress.dart';
import '../widgets.dart';

typedef bool Filter<T>(T element);

class GamesView extends StatefulWidget implements View {
  const GamesView({
    Key key,
  }) : super(key: key);

  @override
  Widget buildTabIcon(BuildContext context) => const Icon(Icons.toys);

  @override
  Widget buildTabLabel(BuildContext context) => const Text('Games');

  @override
  Widget buildFab(BuildContext context) {
    return null;
  }

  @visibleForTesting
  static Progress<void> get loadStatus {
    return Progress.convert<List<Game>, void>(_GamesViewState._games, (List<Game> games) => null);
  }

  @override
  _GamesViewState createState() => _GamesViewState();
}

class _GamesViewState extends State<GamesView> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initGames(DefaultAssetBundle.of(context));
  }

  static String catalogResource = 'resources/JoCoGamesCatalog.txt';
  static Progress<List<Game>> _games;
  static AssetBundle _gameBundle;

  static bool _initStarted = false;
  void initGames(AssetBundle bundle) async {
    // TODO(ianh): This doesn't support handling the case of the asset bundle
    // changing, since we only run it once even if the bundle is different.
    // (that should only matter for tests though, in normal execution the bundle won't change)
    if (_initStarted) {
      assert(_gameBundle == bundle);
      assert(_games != null);
      return;
    }
    assert(_gameBundle == null);
    assert(_games == null);
    _initStarted = true;
    _gameBundle = bundle;
    _games = Progress<List<Game>>((ProgressController<List<Game>> completer) async {
      return await bundle.loadStructuredData<List<Game>>(
        catalogResource,
        (String data) => compute<String, List<Game>>(_parser, data),
      );
    });
  }

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

  Filter<Game> _filter;
  final ScrollController _scrollController = ScrollController();

  void _applyFilter(String query) {
    setState(() {
      query = query.trim();
      if (query.isEmpty) {
        _filter = null;
      } else {
        final List<String> keywords = query.toLowerCase().split(' ');
        _filter = (Game game) => game.matches(keywords);
      }
      _scrollController.jumpTo(0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProgressBuilder<List<Game>>(
      progress: _games,
      builder: (BuildContext context, List<Game> gameList) {
        if (_filter != null)
          gameList = gameList.where(_filter).toList();
        final EdgeInsets outerPadding = MediaQuery.of(context).padding;
        return Column(
          children: <Widget>[
            Material(
              elevation: 4.0,
              child: Padding(
                padding: outerPadding.copyWith(bottom: 0.0) + const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: _applyFilter,
                ),
              ),
            ),
            Expanded(
              child: Scrollbar(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: outerPadding.copyWith(top: 0.0) + const EdgeInsets.all(8.0),
                  itemCount: gameList.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Game game = gameList[index];
                    return ListTile(
                      title: Text(game.name),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class Game implements Comparable<Game> {
  const Game(this.name);

  final String name;

  @override
  int compareTo(Game other) {
    return name.compareTo(other.name);
  }

  bool matches(List<String> substrings) {
    return substrings.every(
      (String substring) {
        return name.toLowerCase().contains(substring);
      },
    );
  }
}
