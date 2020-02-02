import 'dart:isolate';
import 'dart:ui';

import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/calendar.dart';
import '../models/errors.dart';
import '../models/isolate_message.dart';
import '../models/user.dart';
import '../network/rest.dart';
import '../network/twitarr.dart';
import 'disk_store.dart';
import 'notifications.dart';
import 'store.dart';

const bool pollingDisabled = false;

Future<void> runBackground(DataStore store) async {
  if (!await AndroidAlarmManager.initialize()) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: Exception('Android Alarm Manager failed to start up.'),
      library: 'CruiseMonkey',
      context: ErrorDescription('during startup'),
    ));
    return;
  }
  if (pollingDisabled) {
    await AndroidAlarmManager.cancel(0);
    return;
  }
  await rescheduleBackground(store);
}

int backgroundPollingPeriodMinutes = 1;

Future<void> rescheduleBackground(DataStore store) async {
  backgroundPollingPeriodMinutes = (await store.restoreSetting(Setting.notificationCheckPeriod).asFuture() as int ?? 1).clamp(1, 60).toInt();
  if (!await AndroidAlarmManager.periodic(
    Duration(minutes: backgroundPollingPeriodMinutes),
    0, // id
    _periodicCallback,
    wakeup: true,
    rescheduleOnReboot: true,
  )) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: Exception('Android Alarm Manager failed to schedule periodic background task.'),
      library: 'CruiseMonkey',
      context: ErrorDescription('when scheduling background task'),
    ));
    return;
  }
}

bool _initialized = false;

Future<void> _periodicCallback() async {
  if (pollingDisabled) {
    await AndroidAlarmManager.cancel(0);
    return;
  }
  if (!_initialized) {
    AutoTwitarrConfiguration.register();
    RestTwitarrConfiguration.register();
    (await Notifications.instance)
      ..onMessageTap = (String payload) {
        assert(() {
          print('Background thread handled user tapping notification with payload "$payload".');
          return true;
        }());
        final SendPort port = IsolateNameServer.lookupPortByName('main');
        if (port == null) {
          print('Application is not running; could not show thread.');
          return;
        }
        assert(() {
          print('Sending message to main thread...');
          return true;
        }());
        port.send(OpenSeamail(payload));
      }
      ..onEventTap = () {
        assert(() {
          print('Background thread handled user tapping notification with payload "$kCalendarPayload".');
          return true;
        }());
        final SendPort port = IsolateNameServer.lookupPortByName('main');
        if (port == null) {
          print('Application is not running; could not show calendar.');
          return;
        }
        assert(() {
          print('Sending calendar message to main thread...');
          return true;
        }());
        port.send(const OpenCalendar());
      };
    _initialized = true;
  }
  try {
    try {
      final DataStore store = DiskDataStore();
      final Map<Setting, dynamic> settings = await store.restoreSettings().asFuture();
      final String server = settings[Setting.server] as String;
      final Twitarr twitarr = TwitarrConfiguration.from(server, const AutoTwitarrConfiguration()).createTwitarr();
      assert(() {
        if (settings.containsKey(Setting.debugNetworkLatency))
          twitarr.debugLatency = settings[Setting.debugNetworkLatency] as double;
        if (settings.containsKey(Setting.debugNetworkReliability))
          twitarr.debugReliability = settings[Setting.debugNetworkReliability] as double;
        return true;
      }());
      final Credentials credentials = await store.restoreCredentials().asFuture();
      await checkForMessages(credentials, twitarr, store);
      await checkForCalendar(credentials, twitarr, store);
    } on DatabaseException catch (error) {
      if (error.toString() == 'DatabaseException(database is locked (code 5 SQLITE_BUSY))') {
        assert(() {
          print('Found database locked when trying to check for messages.');
          return true;
        }());
        return;
      }
      rethrow;
    }
  } on UserFriendlyError catch (error) {
    print('Skipping background update: $error');
  }
}

Future<void> checkForMessages(Credentials credentials, Twitarr twitarr, DataStore store, { bool forced = false }) async {
  try {
    if (credentials == null) {
      assert(() {
        print('Not logged in; skipping check for messages.');
        return true;
      }());
      return;
    }
    assert(() {
      print('I call my phone and I check my messages.');
      return true;
    }());
    final DateTime lastCheck = DateTime.fromMillisecondsSinceEpoch(
      await store.restoreSetting(Setting.lastNotificationsCheck).asFuture() as int ?? 0,
      isUtc: true,
    );
    final DateTime now = DateTime.now().toUtc();
    if (!forced && now.difference(lastCheck) < const Duration(seconds: 30)) {
      assert(() {
        print('Excessive checking of messages detected.');
        return true;
      }());
      return;
    }
    SeamailSummary summary;
    await store.updateFreshnessToken((int freshnessToken) async {
      // this callback must not touch the database!
      summary = await twitarr.getUnreadSeamailMessages(
        credentials: credentials,
        freshnessToken: freshnessToken,
      ).asFuture();
      final int result = summary.freshnessToken;
      if (freshnessToken == null)
        summary = null;
      return result;
    });
    await store.saveSetting(Setting.lastNotificationsCheck, now.millisecondsSinceEpoch).asFuture();
    if (summary != null) {
      bool didNotify = false;
      final List<Future<void>> futures = <Future<void>>[];
      final Notifications notifications = await Notifications.instance;
      for (SeamailThreadSummary thread in summary.threads) {
        for (SeamailMessageSummary message in thread.messages) {
          futures.add(notifications.messageUnread(
            thread.id,
            message.id,
            message.timestamp,
            thread.subject,
            message.user.toUser(null),
            message.text,
            twitarr,
            store,
          ));
          futures.add(store.addNotification(thread.id, message.id));
          didNotify = true;
        }
      }
      if (didNotify)
        IsolateNameServer.lookupPortByName('main')?.send(const CheckMail());
      await Future.wait(futures);
    }
  } on UserFriendlyError catch (error) {
    print('Failed to check for messages: $error');
  }
}

Future<void> checkForCalendar(Credentials credentials, Twitarr twitarr, DataStore store, { bool forced = false }) async {
  try {
    if (credentials == null) {
      assert(() {
        print('Not logged in; skipping check for calendar.');
        return true;
      }());
      return;
    }
    assert(() {
      print('Checking calendar.');
      return true;
    }());
    final DateTime lastCheck = DateTime.fromMillisecondsSinceEpoch(
      await store.restoreSetting(Setting.lastCalendarCheck).asFuture() as int ?? 0,
      isUtc: true,
    );
    final DateTime now = DateTime.now().toUtc();
    if (!forced && now.difference(lastCheck) < const Duration(minutes: 5)) {
      assert(() {
        print('Excessive checking of calendar detected.');
        return true;
      }());
      return;
    }
    final List<Future<void>> futures = <Future<void>>[];
    final Notifications notifications = await Notifications.instance;
    final UpcomingCalendar calendar = await twitarr.getUpcomingEvents(credentials: credentials, window: const Duration(minutes: 20)).asFuture();
    final bool use24Hour = window.alwaysUse24HourFormat;
    for (Event event in calendar.events) {
      final Duration duration = event.startTime.difference(calendar.serverTime) + const Duration(minutes: 5);
      futures.add(notifications.event(
        eventId: event.id,
        duration: duration, // how long to leave the notification up
        from: Calendar.getHours(event.startTime.toLocal(), use24Hour: use24Hour),
        to: Calendar.getHours(event.endTime.toLocal(), use24Hour: use24Hour),
        name: event.title,
        location: event.location,
        description: event.description.toString(),
        store: store,
      ));
    }
    await Future.wait(futures);
    await store.saveSetting(Setting.lastCalendarCheck, now.millisecondsSinceEpoch).asFuture();
  } on UserFriendlyError catch (error) {
    print('Failed to check for messages: $error');
  }
}
