import 'dart:io';
import 'dart:typed_data';

import '../models/user.dart';
import '../progress.dart';
import 'photo_manager.dart';

enum Setting {
  server,
  debugNetworkLatency,
  debugNetworkReliability,
  debugTimeDilation,
  notificationFreshnessToken,
  lastNotificationsCheck,
  lastCalendarCheck,
  notificationCheckPeriod,
}

typedef FreshnessCallback = Future<int> Function(int token);

abstract class DataStore {
  Progress<void> saveCredentials(Credentials value);
  Progress<Credentials> restoreCredentials();

  Progress<void> saveSetting(Setting id, dynamic value);
  Progress<Map<Setting, dynamic>> restoreSettings();
  Progress<dynamic> restoreSetting(Setting id);

  Future<void> addNotification(String threadId, String messageId);
  Future<void> removeNotification(String threadId, String messageId);
  Future<List<String>> getNotifications(String threadId);

  Future<void> addEventNotification(String eventId);
  Future<bool> didShowEventNotification(String eventId);

  Future<void> updateFreshnessToken(FreshnessCallback callback);

  Future<void> heardAboutUserPhoto(String id, DateTime updateTime);
  Future<Map<String, DateTime>> restoreUserPhotoList();
  Future<Uint8List> putImageIfAbsent(String serverKey, String cacheName, String photoId, ImageFetcher callback);
  Future<File> putImageFileIfAbsent(String serverKey, String cacheName, String photoId, ImageFetcher callback);
  Future<void> removeImage(String serverKey, String cacheName, String photoId);
}
