import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:cruisemonkey/src/logic/photo_manager.dart';
import 'package:cruisemonkey/src/models/calendar.dart';
import 'package:cruisemonkey/src/models/server_text.dart';
import 'package:cruisemonkey/src/models/reactions.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/progress.dart';

@immutable
class LoggingTwitarrConfiguration extends TwitarrConfiguration {
  const LoggingTwitarrConfiguration(this.id);

  final int id;

  static List<String> get log => _log;
  static List<String> _log;

  @override
  Twitarr createTwitarr() => LoggingTwitarr(this, _log);

  static void register(List<String> log) {
    assert(_log == null);
    assert(log != null);
    _log = log;
    TwitarrConfiguration.register(_prefix, _factory);
  }

  static const String _prefix = 'logger';

  static LoggingTwitarrConfiguration _factory(String settings) {
    return LoggingTwitarrConfiguration(int.parse(settings));
  }

  @override
  String get prefix => _prefix;

  @override
  String get settings => '$id';
}

class LoggingTwitarr extends Twitarr {
  LoggingTwitarr(this._configuration, this.log);

  final LoggingTwitarrConfiguration _configuration;

  final List<String> log;

  String overrideHomeLocation;

  @override
  double debugLatency = 0.0;

  @override
  double debugReliability = 1.0;

  @override
  TwitarrConfiguration get configuration => _configuration;

  @override
  String get photoCacheKey => '$runtimeType';

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
      homeLocation: overrideHomeLocation,
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
      homeLocation: overrideHomeLocation,
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
      homeLocation: overrideHomeLocation,
      credentials: credentials,
    ));
  }

  @override
  Progress<User> getUser(Credentials credentials, String username, PhotoManager photoManager) {
    log.add('LoggingTwitarr(${_configuration.id}).getAuthenticatedUser $username, $credentials');
    return Progress<User>.completed(User(
      username: username,
    ));
  }

  @override
  Progress<Calendar> getCalendar({
    Credentials credentials,
  }) {
    log.add('LoggingTwitarr(${_configuration.id}).getCalendar($credentials)');
    return const Progress<Calendar>.idle();
  }

  @override
  Progress<void> setEventFavorite({
    @required Credentials credentials,
    @required String eventId,
    @required bool favorite,
  }) {
    log.add('LoggingTwitarr(${_configuration.id}).setEventFavorite($credentials, $eventId, $favorite)');
    return const Progress<void>.idle();
  }

  @override
  Progress<List<AnnouncementSummary>> getAnnouncements() {
    log.add('LoggingTwitarr(${_configuration.id}).getAnnouncements()');
    return Progress<List<AnnouncementSummary>>.completed(const <AnnouncementSummary>[]);
  }

  @override
  Progress<ServerText> fetchServerText(String filename) {
    log.add('LoggingTwitarr(${_configuration.id}).fetchServerText($filename)');
    return const Progress<ServerText>.idle();
  }

  @override
  Progress<Uint8List> fetchProfilePicture(String username) {
    log.add('fetchProfilePicture');
    return Progress<Uint8List>.completed(Uint8List.fromList(<int>[0]));
  }

  @override
  Progress<void> updateProfile({
    @required Credentials credentials,
    String displayName,
    String realName,
    String pronouns,
    String email,
    String homeLocation,
    String roomNumber,
  }) {
    log.add('updateProfile $displayName/$realName/$pronouns/$email/$homeLocation/$roomNumber');
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
  Progress<Uint8List> fetchImage(String photoId, { bool thumbnail = false }) {
    log.add('fetchImage $photoId (thumbnail=$thumbnail)');
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
    log.add('getSeamailThreads for $credentials from $freshnessToken');
    return const Progress<SeamailSummary>.idle();
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
    return const Progress<StreamSliceSummary>.idle();
  }

  @override
  Progress<StreamMessageSummary> getTweet({
    Credentials credentials,
    String threadId,
  }) {
    log.add('getTweet');
    return const Progress<StreamMessageSummary>.idle();
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
  Progress<void> deleteTweet({
    @required Credentials credentials,
    @required String postId,
  }) {
    log.add('deleteTweet');
    return null;
  }

  @override
  Progress<Map<String, ReactionSummary>> reactTweet({
    @required Credentials credentials,
    @required String postId,
    @required String reaction,
    @required bool selected,
  }) {
    log.add('reactTweet');
    return null;
  }

  @override
  Progress<Map<String, Set<UserSummary>>> getTweetReactions({
    @required Credentials credentials,
    @required String postId,
  }) {
    log.add('getTweetReactions');
    return null;
  }

  @override
  Progress<Set<ForumSummary>> getForumThreads({
    Credentials credentials,
  }) {
    log.add('getForumThreads');
    return const Progress<Set<ForumSummary>>.idle();
  }

  @override
  Progress<ForumSummary> getForumThread({
    Credentials credentials,
    @required String threadId,
  }) {
    log.add('getForumThread $threadId');
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
  Progress<bool> deleteForumMessage({
    Credentials credentials,
    @required String threadId,
    @required String messageId,
  }) {
    log.add('deleteForumMessage $threadId $messageId');
    return null;
  }

  @override
  Progress<Map<String, ReactionSummary>> reactForumMessage({
    @required Credentials credentials,
    @required String threadId,
    @required String messageId,
    @required String reaction,
    @required bool selected,
  }) {
    log.add('reactForumMessage');
    return null;
  }

  @override
  Progress<Map<String, Set<UserSummary>>> getForumMessageReactions({
    @required Credentials credentials,
    @required String threadId,
    @required String messageId,
  }) {
    log.add('getForumMessageReactions');
    return null;
  }

  @override
  Progress<MentionsSummary> getMentions({
    Credentials credentials,
  }) {
    log.add('getMentions');
    return null;
  }

  @override
  Progress<void> clearMentions({
    Credentials credentials,
    int freshnessToken,
  }) {
    log.add('clearMentions $freshnessToken');
    return null;
  }

  @override
  void dispose() {
    log.add('LoggingTwitarr(${_configuration.id}).dispose');
  }
}
