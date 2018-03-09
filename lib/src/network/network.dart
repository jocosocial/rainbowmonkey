import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../json.dart';
import '../models/calendar.dart';
import '../progress.dart';

/// An interface for communicating with the server.
abstract class Twitarr {
  /// The events list from the server.
  ProgressValueListenable<Calendar> get calendar;

  void dispose();
}

/// An implementation of [Twitarr] that uses the /api/v2/ HTTP protocol
/// implemented by <https://github.com/seamonkeysocial/twitarr>.
class RestTwitarr implements Twitarr {
  RestTwitarr({
    this.baseUrl,
    this.frequentPollInterval = const Duration(seconds: 30), // e.g. twitarr
    this.rarePollInterval = const Duration(seconds: 600), // e.g. calendar
  }) {
    _client = new HttpClient();
    _parsedBaseUrl = Uri.parse(baseUrl);
    _calendar = new PollingValueNotifier<Calendar>(getter: _getCalendar, interval: rarePollInterval);
  }

  final String baseUrl;
  final Duration rarePollInterval;
  final Duration frequentPollInterval;

  HttpClient _client;
  Uri _parsedBaseUrl;
  PollingValueNotifier<Calendar> _calendar;

  @override
  ProgressValueListenable<Calendar> get calendar => _calendar;

  FutureWithProgress<Calendar> _getCalendar() {
    final CompleterWithProgress<Calendar> completer = new CompleterWithProgress<Calendar>();
    final Progress fetchingProgress = _request('get', '/api/v2/event.json')
      ..then<Calendar>((String rawEventData) {
        completer.setProgress(0.0, 0.0);
        return compute(_parseCalendar, rawEventData);
      }).then(completer.complete, onError: completer.completeError);
    completer.absorbProgress(fetchingProgress);
    return completer.future;
  }

  static Calendar _parseCalendar(String rawEventData) {
    final dynamic data = Json.parse(rawEventData);
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
  }

  FutureWithProgress<String> _request(String method, String path) {
    final CompleterWithProgress<String> completer = new CompleterWithProgress<String>();
    completer.complete(() async {
      final HttpClientRequest request = await _client.openUrl(method, _parsedBaseUrl.resolve(path));
      final HttpClientResponse response = await request.close();
      if (response.contentLength > 0)
        completer.setProgress(0.0, response.contentLength.toDouble());
      int count = 0;
      return response
        .map((List<int> bytes) {
          if (response.contentLength > 0) {
            count += bytes.length;
            completer.setProgress(count.toDouble(), response.contentLength.toDouble());
          }
          return bytes;
        })
        .transform(utf8.decoder)
        .join();
    }());
    return completer.future;
  }

  @override
  void dispose() {
    _calendar.dispose();
    _client.close(force: true);
  }
}
