import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logic/cruise.dart';
import 'models/server_status.dart';
import 'progress.dart';
import 'widgets.dart';

typedef Filter<T> = bool Function(T element);
typedef Parser<T> = List<T> Function(String data);

abstract class Record {
  const Record();
  Widget buildSearchResult(BuildContext context);
}

abstract class SearchModel<T extends Record> {
  Future<void> attach(BuildContext context);
  void detach();

  bool isEnabled(ServerStatus status);

  Progress<List<T>> get records;

  SearchQueryNotifier get searchQueryNotifier => null;

  /// Calling this should update [records].
  void search(String query);
}

abstract class AssetRecord extends Record {
  const AssetRecord();
  bool matches(List<String> keywords);
}

abstract class AssetSearchModel<T extends AssetRecord> extends SearchModel<T> {
  Progress<List<T>> _records;
  AssetBundle _bundle;

  @override
  Future<void> attach(BuildContext context) async {
    final AssetBundle newBundle = DefaultAssetBundle.of(context);
    _bundle ??= newBundle;
    // TODO(ianh): This doesn't support handling the case of the asset bundle
    // changing, since we only run it once even if the bundle is different.
    // (that should only matter for tests though, in normal execution the bundle won't change)
    assert(_bundle == newBundle);
    _records ??= initFromBundle(_bundle);
    return _records.asFuture();
  }

  @override
  void detach() { }

  @protected
  String get resourceName;

  @visibleForTesting
  Progress<List<T>> initFromBundle(AssetBundle bundle) {
    final Future<List<T>> parsedData = bundle.loadStructuredData<List<T>>(
      resourceName,
      (String data) => compute<String, List<T>>(parser(), data),
    );
    return Progress<List<T>>((ProgressController<List<T>> completer) => parsedData);
  }

  /// This must return a static function that implements the parser.
  ///
  /// (It is passed to [Isolate.spawn].)
  @protected
  Parser<T> parser();

  Progress<List<T>> _filteredRecords;

  @override
  Progress<List<T>> get records => _filteredRecords ?? _records;

  @override
  void search(String query) {
    if (query.isEmpty) {
      _filteredRecords = null;
    } else {
      final List<String> keywords = query.toLowerCase().split(' ');
      _filteredRecords = Progress.convert<List<T>, List<T>>(
        _records,
        (List<T> list) => list.where((T value) => value.matches(keywords)).toList()
      );
    }
  }
}

class SearchableListView<T extends Record> extends StatefulWidget implements View {
  SearchableListView({
    PageStorageKey<Object> key,
    @required this.searchModel,
    @required this.icon,
    @required this.label,
  }) : super(key: key ?? PageStorageKey<SearchModel<T>>(searchModel));

  final SearchModel<T> searchModel;

  final Widget icon;

  final Widget label;

  @override
  bool isEnabled(ServerStatus status) => searchModel.isEnabled(status);

  @override
  Widget buildTabIcon(BuildContext context) => icon;

  @override
  Widget buildTabLabel(BuildContext context) => label;

  @override
  Widget buildFab(BuildContext context) {
    return null;
  }

  Widget idleScreen(BuildContext context) {
    return Center(
      child: IconTheme(
        data: IconThemeData(
          size: 64.0,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
        ),
        child: icon,
      ),
    );
  }

  Widget emptyResults(BuildContext context) {
    return const LabeledIconButton(
      icon: Icon(Icons.sentiment_dissatisfied),
      label: Text('No matches.'),
    );
  }

  @override
  _SearchableListViewState<T> createState() => _SearchableListViewState<T>();
}

class _SearchableListViewState<T extends Record> extends State<SearchableListView<T>> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textEditingController = TextEditingController();
  SearchQueryNotifier _searchQueryNotifier;
  bool _new = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _textEditingController.addListener(_storeTextField);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_new) {
      widget.searchModel.attach(context);
    }
    _updateQueryNotifier();
    if (_new) {
      final String pushedQuery = _searchQueryNotifier?.pullQuery(tentative: true);
      if (pushedQuery != null) {
        _textEditingController.value = TextEditingValue(text: pushedQuery);
      } else {
        final TextEditingValue keptValue = PageStorage.of(context).readState(context, identifier: widget.searchModel) as TextEditingValue;
        if (keptValue != null)
          _textEditingController.value = keptValue;
      }
      _new = false;
    }
  }

  @override
  void didUpdateWidget(SearchableListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchModel != oldWidget.searchModel) {
      oldWidget.searchModel.detach();
      widget.searchModel.attach(context);
      _updateQueryNotifier();
    }
  }

  void _updateQueryNotifier() {
    final SearchQueryNotifier newQueryNotifier = widget.searchModel.searchQueryNotifier;
    if (newQueryNotifier != _searchQueryNotifier) {
      _searchQueryNotifier?.removeListener(_updateQuery);
      _searchQueryNotifier = newQueryNotifier;
      _searchQueryNotifier = widget.searchModel.searchQueryNotifier;
      _searchQueryNotifier?.addListener(_updateQuery);
    }
  }

  void _updateQuery() {
    assert(_searchQueryNotifier != null);
    final String newQuery = _searchQueryNotifier.pullQuery().trim();
    if (newQuery != _textEditingController.value.text.trim())
      _textEditingController.value = TextEditingValue(text: newQuery);
  }

  void _storeTextField() {
    setState(() {
      final String newQuery = _textEditingController.value.text.trim();
      if (_query != newQuery) {
        _query = newQuery;
        widget.searchModel.search(_query);
        if (_scrollController.hasClients)
          _scrollController.jumpTo(0.0);
      }
      if (!_new)
        PageStorage.of(context).writeState(context, _textEditingController.value, identifier: widget.searchModel);
    });
  }

  @override
  void dispose() {
    _textEditingController.removeListener(_storeTextField);
    _searchQueryNotifier?.removeListener(_updateQuery);
    widget.searchModel.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets outerPadding = MediaQuery.of(context).padding;
    return Column(
      verticalDirection: VerticalDirection.up,
      children: <Widget>[
        Expanded(
          child: Scrollbar(
            child: ProgressBuilder<List<T>>(
              progress: widget.searchModel.records,
              idleChild: widget.idleScreen(context),
              builder: (BuildContext context, List<T> records) {
                if (records.isEmpty)
                  return widget.emptyResults(context);
                return ListView.builder(
                  controller: _scrollController,
                  padding: outerPadding.copyWith(top: 0.0) + const EdgeInsets.all(8.0),
                  itemCount: records.length,
                  itemBuilder: (BuildContext context, int index) => records[index].buildSearchResult(context),
                );
              },
            ),
          ),
        ),
        Material(
          elevation: 4.0,
          child: Padding(
            padding: outerPadding.copyWith(bottom: 0.0) + const EdgeInsets.all(8.0),
            child: TextField(
              controller: _textEditingController,
              decoration: InputDecoration(
                labelText: 'Search',
                suffixIcon: IconButton(
                  icon: _textEditingController.text.isEmpty ? const Icon(Icons.search) : const Icon(Icons.close),
                  onPressed: _textEditingController.clear,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
