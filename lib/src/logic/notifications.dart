import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meta/meta.dart';

import '../models/string.dart';
import '../models/user.dart';
import '../network/twitarr.dart';
import 'store.dart';

const String kCalendarPayload = ':calendar:';

typedef NotificationCallback = void Function(String payload);
typedef VoidCallback = void Function();

class Notifications {
  Notifications._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @visibleForTesting
  static FlutterLocalNotificationsPlugin overridePlugin;

  static Future<Notifications> _future;
  static Future<Notifications> get instance {
    if (_future != null)
      return _future;
    final Completer<Notifications> completer = Completer<Notifications>();
    _future = completer.future;
    final Notifications result = Notifications._(overridePlugin ?? FlutterLocalNotificationsPlugin());
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

  NotificationCallback get onMessageTap => _onMessageTap;
  NotificationCallback _onMessageTap;
  set onMessageTap(NotificationCallback value) {
    if (value == onMessageTap)
      return;
    _onMessageTap = value;
    if (_pendingPayload != null)
      _handlePayload(_pendingPayload);
  }

  VoidCallback get onEventTap => _onEventTap;
  VoidCallback _onEventTap;
  set onEventTap(VoidCallback value) {
    if (value == onEventTap)
      return;
    _onEventTap = value;
    if (_pendingPayload != null)
      _handlePayload(_pendingPayload);
  }

  Future<void> _handleSelection(String payload) async {
    assert(() {
      print('User tapped notification with payload: $payload');
      return true;
    }());
    _handlePayload(payload);
  }

  void _handlePayload(String payload) {
    _pendingPayload = null;
    if (payload == kCalendarPayload) {
      if (onEventTap == null) {
        _pendingPayload = payload;
      } else {
        onEventTap();
      }
    } else {
      if (onMessageTap == null) {
        _pendingPayload = payload;
      } else {
        onMessageTap(payload);
      }
    }
  }

  void cancelAll() {
    _plugin.cancelAll();
  }

  int _notificationId(String threadId, String messageId) {
    return '$threadId:$messageId'.hashCode;
  }

  int _eventId(String eventId) {
    return eventId.hashCode;
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
      category: 'msg',
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
      enableVibration: true,
      vibrationPattern: _fantasticDrumBeat,
      groupKey: threadId,
      autoCancel: true,
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

  Future<void> event({ String eventId, Duration duration, String from, String to, String name, String location, String description, DataStore store }) async {
    if (await store.didShowEventNotification(eventId))
      return;
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      'cruisemonkey-calendar',
      'Events',
      'JocoCruise event notifications, for events you have favorited.',
      category: 'event',
      style: AndroidNotificationStyle.BigText,
      styleInformation: BigTextStyleInformation(
        '$from-$to $location\n$description',
        contentTitle: name,
        summaryText: '$from-$to $name',
      ),
      playSound: true,
      onlyAlertOnce: true,
      enableVibration: true,
      autoCancel: true,
      channelShowBadge: false,
      timeoutAfter: duration.inMilliseconds,
    );
    final IOSNotificationDetails iOS = IOSNotificationDetails();
    await _plugin.show(
      _eventId(eventId),
      name,
      '$from-$to $location',
      NotificationDetails(android, iOS),
      payload: kCalendarPayload,
    );
    await store.addEventNotification(eventId);
  }

  Future<void> messageRead(String threadId, String messageId) async {
    await _plugin.cancel(_notificationId(threadId, messageId));
  }
}