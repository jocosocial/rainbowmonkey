import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cruisemonkey/src/logic/photo_manager.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/progress.dart';

class TrivialDataStore implements DataStore {
  TrivialDataStore(this.log);

  final List<String> log;

  Credentials storedCredentials;

  @override
  Progress<void> saveCredentials(Credentials value) {
    log.add('LoggingDataStore.saveCredentials $value');
    return Progress<void>.completed(null);
  }

  @override
  Progress<Credentials> restoreCredentials() {
    log.add('LoggingDataStore.restoreCredentials');
    return Progress<Credentials>.completed(storedCredentials);
  }

  Map<Setting, dynamic> storedSettings = <Setting, dynamic>{};

  @override
  Progress<void> saveSetting(Setting id, dynamic value) {
    log.add('LoggingDataStore.saveSetting $id $value');
    storedSettings[id] = value;
    return Progress<void>.completed(null);
  }

  @override
  Progress<Map<Setting, dynamic>> restoreSettings() {
    log.add('LoggingDataStore.restoreSettings');
    return Progress<Map<Setting, dynamic>>.completed(storedSettings);
  }

  @override
  Progress<dynamic> restoreSetting(Setting id) {
    log.add('LoggingDataStore.restoreSetting $id');
    return Progress<dynamic>.completed(storedSettings[id]);
  }

  Map<String, Set<String>> storedNotifications = <String, Set<String>>{};

  @override
  Future<void> addNotification(String threadId, String messageId) async {
    log.add('LoggingDataStore.addNotification($threadId, $messageId)');
    final Set<String> thread = storedNotifications.putIfAbsent(threadId, () => <String>{});
    thread.add(messageId);
  }

  @override
  Future<void> removeNotification(String threadId, String messageId) async {
    log.add('LoggingDataStore.removeNotification($threadId, $messageId)');
    final Set<String> thread = storedNotifications.putIfAbsent(threadId, () => <String>{});
    thread.remove(messageId);
  }

  @override
  Future<List<String>> getNotifications(String threadId) async {
    log.add('LoggingDataStore.getNotifications($threadId)');
    final Set<String> thread = storedNotifications.putIfAbsent(threadId, () => <String>{});
    return thread.toList();
  }

  Set<String> eventNotifications = <String>{};

  @override
  Future<void> addEventNotification(String eventId) async {
    eventNotifications.add(eventId);
  }

  @override
  Future<bool> didShowEventNotification(String eventId) async {
    return eventNotifications.contains(eventId);
  }


  int storedFreshnessToken;

  @override
  Future<void> updateFreshnessToken(FreshnessCallback callback) async {
    log.add('LoggingDataStore.updateFreshnessToken');
    storedFreshnessToken = await callback(storedFreshnessToken);
  }

  @override
  Future<void> heardAboutUserPhoto(String id, DateTime updateTime) async { }

  @override
  Future<Uint8List> putImageIfAbsent(String serverKey, String cacheName, String photoId, ImageFetcher callback) async {
    return await callback();
  }

  @override
  Future<File> putImageFileIfAbsent(String serverKey, String cacheName, String photoId, ImageFetcher callback) {
    return Completer<File>().future;
  }

  @override
  Future<void> removeImage(String serverKey, String cacheName, String photoId) async { }

  @override
  Future<Map<String, DateTime>> restoreUserPhotoList() async {
    return <String, DateTime>{};
  }
}
