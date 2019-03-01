import 'dart:isolate';
import 'dart:ui';

import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../network/rest.dart';
import '../network/twitarr.dart';
import 'disk_store.dart';
import 'notifications.dart';
import 'store.dart';

Future<void> runBackground(DataStore store) async {
  if (!await AndroidAlarmManager.initialize()) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: Exception('Android Alarm Manager failed to start up.'),
      library: 'CruiseMonkey',
      context: 'during startup',
    ));
    return;
  }
  await rescheduleBackground(store);
}

int backgroundPollingPeriodMinutes = 1;

Future<void> rescheduleBackground(DataStore store) async {
  backgroundPollingPeriodMinutes = (await store.restoreSetting(Setting.notificationCheckPeriod).asFuture() as int).clamp(1, 60).toInt();
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
      context: 'when scheduling background task',
    ));
    return;
  }
}

bool _initialized = false;

Future<void> _periodicCallback() async {
  if (!_initialized) {
    AutoTwitarrConfiguration.register();
    RestTwitarrConfiguration.register();
    (await Notifications.instance).onTap = (String payload) {
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
      port.send(payload);
    };
    _initialized = true;
  }
  try {
    try {
      final DataStore store = DiskDataStore();
      final Map<Setting, dynamic> settings = await store.restoreSettings().asFuture();
      final String server = settings[Setting.server] as String;
      final Twitarr twitarr = TwitarrConfiguration.from(server, const AutoTwitarrConfiguration()).createTwitarr();
      if (settings.containsKey(Setting.debugNetworkLatency))
        twitarr.debugLatency = settings[Setting.debugNetworkLatency] as double;
      if (settings.containsKey(Setting.debugNetworkReliability))
        twitarr.debugReliability = settings[Setting.debugNetworkReliability] as double;
      final Credentials credentials = await store.restoreCredentials().asFuture();
      await checkForMessages(credentials, twitarr, store);
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
    if (!forced && now.difference(lastCheck) < const Duration(minutes: 1)) {
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
      final List<Future<void>> futures = <Future<void>>[];
      final Notifications notifications = await Notifications.instance;
      for (SeamailThreadSummary thread in summary.threads) {
        for (SeamailMessageSummary message in thread.messages) {
          futures.add(notifications.messageUnread(thread.id, message.id, message.timestamp, thread.subject, message.user.toUser(null), message.text, twitarr, store));
          futures.add(store.addNotification(thread.id, message.id));
        }
      }
      await Future.wait(futures);
    }
  } on UserFriendlyError catch (error) {
    print('Failed to check for messages: $error');
  }
}
