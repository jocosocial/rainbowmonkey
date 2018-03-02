import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../json.dart';
import '../models/calendar.dart';

/// An interface for communicating with the server.
abstract class Twitarr {
  /// The events list from the server.
  ValueListenable<Calendar> get calendar;

  void dispose();
}

abstract class _LazyValueNotifier<T> extends ValueNotifier<T> {
  _LazyValueNotifier() : super(null);

  @protected
  void start();

  @protected
  void stop();

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners)
      start();
    super.addListener(listener);
    assert(hasListeners);
  }

  @override
  void removeListener(VoidCallback listener) {
    assert(hasListeners);
    super.removeListener(listener);
    if (!hasListeners)
      stop();
  }

  @override
  void dispose() {
    if (hasListeners)
      stop();
    super.dispose();
  }
}

class _PollingValueNotifier<T> extends _LazyValueNotifier<T> {
  _PollingValueNotifier({
    this.getter,
    this.interval,
  });

  final ValueGetter<Future<T>> getter;

  final Duration interval;

  Timer _timer;
  Future<T> _future;

  @override
  void start() {
    _timer = new Timer.periodic(interval, _tick);
    _tick(_timer);
  }

  @override
  void stop() {
    _timer.cancel();
    _timer = null;
  }

  void _tick(Timer timer) {
    assert(timer == _timer);
    _future ??= getter()
      ..then<void>(_update);
  }

  void _update(T newValue) {
    if (_timer != null) {
      value = newValue;
      _future = null;
    }
  }
}

/// An implementation of [Twitarr] that uses the /api/v2/ HTTP protocol
/// implemented by <https://github.com/seamonkeysocial/twitarr>.
class RestTwitarr implements Twitarr {
  RestTwitarr({
    this.baseUrl,
    this.pollInterval = const Duration(seconds: 60),
  }) {
    _client = new HttpClient();
    _parsedBaseUrl = Uri.parse(baseUrl);
    _calendar = new _PollingValueNotifier<Calendar>(getter: _getCalendar, interval: pollInterval);
  }

  final String baseUrl;
  final Duration pollInterval;

  HttpClient _client;
  Uri _parsedBaseUrl;
  _PollingValueNotifier<Calendar> _calendar;

  @override
  ValueListenable<Calendar> get calendar => _calendar;

  Future<Calendar> _getCalendar() async {
    final dynamic data = Json.parse(await _request('get', '/api/v2/event.json'));
    try {
      final dynamic values = data.event.asIterable().single;
      if (values.status != 'ok')
        throw const FormatException('status invalid');
      if (values.total_count != (values.events.asIterable() as Iterable<dynamic>).length)
        throw const FormatException('total_count invalid');
      return new Calendar(events: (values.events.asIterable() as Iterable<dynamic>).map<Event>((dynamic value) {
        return new Event(
          id: value.id.toString(),
          title: value.title.toString(),
          official: value.official.toBoolean() as bool,
          description: value['description']?.toString(),
          location: value.location.toString(),
          startTime: DateTime.parse(value.start_time.toString()),
          endTime: DateTime.parse(value.end_time.toString()),
        );
      }).toList());
    } on FormatException {
      return null;
    } on NoSuchMethodError {
      return null;
    }
  }

  Future<String> _request(String method, String path) async {
    final HttpClientRequest request = await _client.openUrl(method, _parsedBaseUrl.resolve(path));
    final HttpClientResponse response = await request.close();
    return response.transform(utf8.decoder).join();
  }

  @override
  void dispose() {
    _calendar.dispose();
    _client.close(force: true);
  }
}
