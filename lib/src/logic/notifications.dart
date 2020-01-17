import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/string.dart';
import '../models/user.dart';
import '../network/twitarr.dart';
import 'store.dart';

typedef NotificationCallback = void Function(String payload);

class Notifications {
  Notifications._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static Future<Notifications> _future;
  static Future<Notifications> get instance {
    if (_future != null)
      return _future;
    final Completer<Notifications> completer = Completer<Notifications>();
    _future = completer.future;
    final Notifications result = Notifications._(FlutterLocalNotificationsPlugin());
    result._plugin.initialize(
      const InitializationSettings(
        AndroidInitializationSettings('@drawable/notifications'),
        IOSInitializationSettings(),
      ),
      onSelectNotification: result._handleSelection,
    ).then((bool value) {
      if (value) {
        result._plugin.getNotificationAppLaunchDetails().then((NotificationAppLaunchDetails launchStatus) {
          if (launchStatus.didNotificationLaunchApp)
            result._handleSelection(launchStatus.payload);
        });
        completer.complete(result);
      } else {
        completer.completeError(Exception('Flutter Local Notifications plugin failed to start up.'));
      }
    });
    return _future;
  }

  String _pendingPayload;

  NotificationCallback get onTap => _onTap;
  NotificationCallback _onTap;
  set onTap(NotificationCallback value) {
    if (value == onTap)
      return;
    _onTap = value;
    if (_pendingPayload != null) {
      assert(_onTap != null); // otherwise value would have been non-null and we should not have set _pendingPayload
      final String payload = _pendingPayload;
      _pendingPayload = null;
      _onTap(payload);
    }
  }

  Future<void> _handleSelection(String payload) async {
    assert(() {
      print('User tapped notification with payload: $payload');
      return true;
    }());
    if (onTap == null) {
      _pendingPayload = payload;
    } else {
      onTap(payload);
    }
  }

  void cancelAll() {
    _plugin.cancelAll();
  }

  int _notificationId(String threadId, String messageId) {
    return '$threadId:$messageId'.hashCode;
  }

  final Int64List _fantasticDrumBeat = Int64List.fromList(<int>[0, 60, 60, 60, 60, 180, 60, 60, 60, 60, 60, 180, 60]);

  Future<String> _fetchAvatar(String username, Twitarr twitarr, DataStore store) async {
    return (await store.putImageFileIfAbsent(
      twitarr.photoCacheKey,
      'avatar',
      username,
      () => twitarr.fetchProfilePicture(username).asFuture(),
    )).absolute.path;
  }

  Future<void> messageUnread(String threadId, String messageId, DateTime timestamp, String subject, User user, TwitarrString message, Twitarr twitarr, DataStore store) async {
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      'cruisemonkey-seamail',
      'Seamail',
      'Seamail notifications',
      // icon
      importance: Importance.High,
      priority: Priority.High,
      style: AndroidNotificationStyle.Messaging,
      styleInformation: MessagingStyleInformation(
        Person(name: 'You'),
        conversationTitle: subject,
        messages: <Message>[
          Message(
            message.toString(),
            timestamp,
            Person(
              icon: await _fetchAvatar(user.username, twitarr, store),
              iconSource: IconSource.FilePath,
              name: '$user',
            ),
          ),
        ],
      ),
      playSound: true,
      // sound
      enableVibration: true,
      vibrationPattern: _fantasticDrumBeat,
      groupKey: threadId,
      // setAsGroupSummary
      // groupAlertBehavior
      autoCancel: true,
      // color
      // largeIcon
      // largeIconBitmapSource
      // onlyAlertOnce
      channelShowBadge: true,
    );
    final IOSNotificationDetails iOS = IOSNotificationDetails();
    await _plugin.show(
      _notificationId(threadId, messageId),
      subject,
      message.toString(),
      NotificationDetails(android, iOS),
      payload: threadId,
    );
  }

  Future<void> messageRead(String threadId, String messageId) async {
    await _plugin.cancel(_notificationId(threadId, messageId));
  }
}