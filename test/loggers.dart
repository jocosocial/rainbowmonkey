import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:cruisemonkey/src/logic/photo_manager.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/calendar.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/progress.dart';

class LoggingDataStore implements DataStore {
  LoggingDataStore(this.log);

  final List<String> log;

  @override
  Progress<void> saveCredentials(Credentials value) {
    log.add('LoggingDataStore.saveCredentials $value');
    return Progress<void>.completed(null);
  }
  @override
  Progress<Credentials> restoreCredentials() {
    log.add('LoggingDataStore.restoreCredentials');
    return Progress<Credentials>.completed(null);
  }

  @override
  Progress<void> saveSetting(Setting id, dynamic value) {
    log.add('LoggingDataStore.saveSetting $id $value');
    return Progress<void>.completed(null);
  }

  @override
  Progress<Map<Setting, dynamic>> restoreSettings() {
    log.add('LoggingDataStore.restoreSettings');
    return Progress<Map<Setting, dynamic>>.completed(null);
  }

  @override
  Progress<dynamic> restoreSetting(Setting id) {
    log.add('LoggingDataStore.restoreSetting $id');
    return Progress<dynamic>.completed(null);
  }

  @override
  Future<void> addNotification(String threadId, String messageId) async {
    log.add('LoggingDataStore.addNotification($threadId, $messageId)');
  }

  @override
  Future<void> removeNotification(String threadId, String messageId) async {
    log.add('LoggingDataStore.removeNotification($threadId, $messageId)');
  }

  @override
  Future<List<String>> getNotifications(String threadId) async {
    log.add('LoggingDataStore.getNotifications($threadId)');
    return <String>[];
  }

  @override
  Future<void> updateFreshnessToken(FreshnessCallback callback) async {
    log.add('LoggingDataStore.updateFreshnessToken');
    await callback(null);
  }
}

@immutable
class LoggingTwitarrConfiguration extends TwitarrConfiguration {
  const LoggingTwitarrConfiguration(this.id, this.log);

  final int id;

  final List<String> log;

  @override
  Twitarr createTwitarr() => LoggingTwitarr(this, log);

  @override
  String toString() => 'LoggingTwitarrConfiguration($id)';
}

class LoggingTwitarr extends Twitarr {
  LoggingTwitarr(this._configuration, this.log);

  final LoggingTwitarrConfiguration _configuration;

  final List<String> log;

  String overrideCurrentLocation;

  @override
  double debugLatency = 0.0;

  @override
  double debugReliability = 1.0;

  @override
  TwitarrConfiguration get configuration => _configuration;

  int _stamp = 0;

  @override
  Progress<AuthenticatedUser> createAccount({
    @required String username,
    @required String password,
    @required String registrationCode,
    String displayName,
  }) {
    log.add('LoggingTwitarr(${_configuration.id}).createAccount $username / $password / $registrationCode / $displayName');
    return Progress<AuthenticatedUser>.completed(AuthenticatedUser(
      username: username,
      displayName: displayName,
      currentLocation: overrideCurrentLocation,
      credentials: Credentials(
        username: username,
        password: password,
        key: '<key for $username>',
        loginTimestamp: DateTime.fromMillisecondsSinceEpoch(_stamp += 1),
      ),
    ));
  }

  @override
  Progress<AuthenticatedUser> login({
    @required String username,
    @required String password,
    @required PhotoManager photoManager,
  }) {
    log.add('LoggingTwitarr(${_configuration.id}).login $username / $password');
    return Progress<AuthenticatedUser>.completed(AuthenticatedUser(
      username: username,
      email: '<email for $username>',
      currentLocation: overrideCurrentLocation,
      credentials: Credentials(
        username: username,
        password: password,
        key: '<key for $username>',
        loginTimestamp: DateTime.fromMillisecondsSinceEpoch(_stamp += 1),
      ),
    ));
  }

  @override
  Progress<AuthenticatedUser> getAuthenticatedUser(Credentials credentials, PhotoManager photoManager) {
    log.add('LoggingTwitarr(${_configuration.id}).getAuthenticatedUser $credentials');
    return Progress<AuthenticatedUser>.completed(AuthenticatedUser(
      username: credentials.username,
      email: '<email for ${credentials.username}>',
      currentLocation: overrideCurrentLocation,
      credentials: credentials,
    ));
  }

  @override
  Progress<Calendar> getCalendar() {
    log.add('LoggingTwitarr(${_configuration.id}).getCalendar');
    return const Progress<Calendar>.idle();
  }

  @override
  Progress<Uint8List> fetchProfilePicture(String username) {
    log.add('fetchProfilePicture');
    return Progress<Uint8List>.completed(Uint8List.fromList(<int>[0]));
  }

  @override
  Progress<void> updateProfile({
    @required Credentials credentials,
    String currentLocation,
    String displayName,
    String realName,
    String pronouns,
    String email,
    bool emailPublic,
    String homeLocation,
    String roomNumber,
    bool vcardPublic,
  }) {
    log.add('updateProfile $currentLocation/$displayName/$realName/$pronouns/$email/$emailPublic/$homeLocation/$roomNumber/$vcardPublic');
    return Progress<void>.completed(null);
  }

  @override
  Progress<void> uploadAvatar({
    @required Credentials credentials,
    @required Uint8List bytes,
  }) {
    log.add('uploadAvatar ${bytes.length} bytes');
    return null;
  }

  @override
  Progress<void> resetAvatar({
    @required Credentials credentials,
  }) {
    log.add('resetAvatar');
    return null;
  }

  @override
  Progress<Uint8List> fetchImage(String photoId) {
    log.add('fetchImage $photoId');
    return null;
  }

  @override
  Progress<String> uploadImage({
    @required Credentials credentials,
    @required Uint8List bytes,
  }) {
    log.add('uploadImage');
    return null;
  }

  @override
  Progress<void> updatePassword({
    @required Credentials credentials,
    @required String oldPassword,
    @required String newPassword,
  }) {
    log.add('updatePassword');
    return null;
  }

  @override
  Progress<List<User>> getUserList(String searchTerm) {
    log.add('getUserList');
    return null;
  }

  @override
  Progress<SeamailSummary> getSeamailThreads({
    @required Credentials credentials,
    int freshnessToken,
  }) {
    log.add('getSeamailThreads');
    return null;
  }

  @override
  Progress<SeamailSummary> getUnreadSeamailMessages({
    @required Credentials credentials,
    int freshnessToken,
  }) {
    log.add('getUnreadSeamailMessages');
    return null;
  }

  @override
  Progress<SeamailThreadSummary> getSeamailMessages({
    @required Credentials credentials,
    @required String threadId,
    bool markRead = true,
  }) {
    log.add('getSeamailMessages');
    return null;
  }

  @override
  Progress<SeamailMessageSummary> postSeamailMessage({
    @required Credentials credentials,
    @required String threadId,
    @required String text,
  }) {
    log.add('postSeamailMessage');
    return null;
  }

  @override
  Progress<SeamailThreadSummary> createSeamailThread({
    @required Credentials credentials,
    @required Set<User> users,
    @required String subject,
    @required String text,
  }) {
    log.add('createSeamailThread');
    return null;
  }

  @override
  Progress<StreamSliceSummary> getStream({
    Credentials credentials,
    @required StreamDirection direction,
    int boundaryToken,
    int limit = 100,
  }) {
    log.add('getStream');
    return null;
  }

  @override
  Progress<void> postTweet({
    @required Credentials credentials,
    @required String text,
    String parentId,
    @required Uint8List photo,
  }) {
    log.add('postTweet');
    return null;
  }

  @override
  Progress<Set<ForumSummary>> getForumThreads({
    Credentials credentials,
  }) {
    log.add('getForumThreads');
    return null;
  }

  @override
  Progress<List<ForumMessageSummary>> getForumMessages({
    Credentials credentials,
    @required String threadId,
  }) {
    log.add('getForumMessages $threadId');
    return null;
  }

  @override
  Progress<ForumSummary> createForumThread({
    Credentials credentials,
    @required String subject,
    @required String text,
    @required List<Uint8List> photos,
  }) {
    log.add('createForumThread "$subject" "$text"');
    return null;
  }

  @override
  Progress<void> postForumMessage({
    Credentials credentials,
    @required String threadId,
    @required String text,
    @required List<Uint8List> photos,
  }) {
    log.add('postForumMessage $threadId "$text"');
    return null;
  }

  @override
  void dispose() {
    log.add('LoggingTwitarr(${_configuration.id}).dispose');
  }
}
