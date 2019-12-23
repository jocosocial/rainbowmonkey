import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/server_status.dart';
import 'progress.dart';
import 'widgets.dart';

typedef Parser<T> = List<T> Function(String data);

abstract class Record {
  const Record();
  bool matches(List<String> keywords);
  Widget build(BuildContext context);
}

abstract class RecordsLoader<T> {
  bool _initStarted = false;
  Progress<List<T>> _records;
  AssetBundle _bundle;

  Future<void> init(AssetBundle bundle) async {
    // TODO(ianh): This doesn't support handling the case of the asset bundle
    // changing, since we only run it once even if the bundle is different.
    // (that should only matter for tests though, in normal execution the bundle won't change)
    if (_initStarted) {
      assert(_bundle == bundle);
      assert(_records != null);
      return;
    }
    assert(_bundle == null);
    assert(_records == null);
    _initStarted = true;
    _bundle = bundle;
    final Future<List<T>> parsedData = bundle.loadStructuredData<List<T>>(
      resourceName,
      (String data) => compute<String, List<T>>(parser(), data),
    );
    _records = Progress<List<T>>((ProgressController<List<T>> completer) => parsedData);
    await parsedData;
  }

  bool isEnabled(ServerStatus status);

  @protected
  String get resourceName;

  /// This must return a static function that implements the parser.
  ///
  /// (It is passed to [Isolate.spawn].)
  @protected
  Parser<T> parser();
}

typedef bool Filter<T extends Record>(T element);

class SearchableListView<T extends Record> extends StatefulWidget implements View {
  SearchableListView({
    PageStorageKey<Object> key,
    @required this.recordsLoader,
    @required this.icon,
    @required this.label,
  }) : super(key: key ?? PageStorageKey<RecordsLoader<T>>(recordsLoader));

  final RecordsLoader<T> recordsLoader;

  final Widget icon;

  final Widget label;

  @override
  bool isEnabled(ServerStatus status) => recordsLoader.isEnabled(status);

  @override
  Widget buildTabIcon(BuildContext context) => icon;

  @override
  Widget buildTabLabel(BuildContext context) => label;

  @override
  Widget buildFab(BuildContext context) {
    return null;
  }

  @override
  _SearchableListViewState<T> createState() => _SearchableListViewState<T>();
}

class _SearchableListViewState<T extends Record> extends State<SearchableListView<T>> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textEditingController = TextEditingController();
  Filter<T> _filter;
  bool _new = true;

  @override
  void initState() {
    super.initState();
    _textEditingController.addListener(_storeTextField);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_new) {
      final TextEditingValue keptValue = PageStorage.of(context).readState(context, identifier: widget.recordsLoader) as TextEditingValue;
      if (keptValue != null)
        _textEditingController.value = keptValue;
      _new = false;
    }
    widget.recordsLoader.init(DefaultAssetBundle.of(context));
  }

  void _storeTextField() {
    setState(() {
      final String query = _textEditingController.value.text.trim();
      if (query.isEmpty) {
        _filter = null;
      } else {
        final List<String> keywords = query.toLowerCase().split(' ');
        _filter = (T value) => value.matches(keywords);
      }
      if (!_new) {
        _scrollController.jumpTo(0.0);
        PageStorage.of(context).writeState(context, _textEditingController.value, identifier: widget.recordsLoader);
      }
    });
  }

  @override
  void dispose() {
    _textEditingController.removeListener(_storeTextField);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProgressBuilder<List<T>>(
      progress: widget.recordsLoader._records,
      builder: (BuildContext context, List<T> records) {
        if (_filter != null)
          records = records.where(_filter).toList();
        final EdgeInsets outerPadding = MediaQuery.of(context).padding;
        return Column(
          children: <Widget>[
            Material(
              elevation: 4.0,
              child: Padding(
                padding: outerPadding.copyWith(bottom: 0.0) + const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _textEditingController,
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    suffixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Scrollbar(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: outerPadding.copyWith(top: 0.0) + const EdgeInsets.all(8.0),
                  itemCount: records.length,
                  itemBuilder: (BuildContext context, int index) => records[index].build(context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
