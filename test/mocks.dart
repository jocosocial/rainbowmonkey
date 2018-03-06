import 'package:cruisemonkey/src/models/calendar.dart';
import 'package:cruisemonkey/src/network/network.dart';
import 'package:cruisemonkey/src/progress.dart';
import 'package:flutter/foundation.dart';

class TestTwitarr extends Twitarr {
  @override
  ProgressValueNotifier<Calendar> calendar = new ProgressValueNotifier<Calendar>(null);

  @override
  void dispose() { }
}

class AutoupdatingTestTwitarr extends Twitarr {
  AutoupdatingTestTwitarr({
    this.calendarGetter,
    this.calendarInterval: const Duration(seconds: 600),
  }) {
    calendar = new PollingValueNotifier<Calendar>(
      getter: calendarGetter,
      interval: calendarInterval,
    );
  }

  final ValueGetter<FutureWithProgress<Calendar>> calendarGetter;
  final Duration calendarInterval;

  @override
  PollingValueNotifier<Calendar> calendar;

  @override
  void dispose() {
    calendar.dispose();
  }
}
