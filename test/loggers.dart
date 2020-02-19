import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:cruisemonkey/src/logic/photo_manager.dart';
import 'package:cruisemonkey/src/models/calendar.dart';
import 'package:cruisemonkey/src/models/server_status.dart';
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
  Twitarr createTwitarr() => LoggingTwitarr(this, log);

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

  @protected
  void addLog(String message) => log.add(message);

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
  void enable(ServerStatus status) { }

  @override
  void disable() { }

  @override
  Progress<AuthenticatedUser> createAccount({
    @required String username,
    @required String password,
    @required String registrationCode,
    String displayName,
  }) {
    addLog('LoggingTwitarr(${_configuration.id}).createAccount $username / $password / $registrationCode / $displayName');
    return Progress<AuthenticatedUser>.completed(AuthenticatedUser(
      username: username,
      displayName: displayName,
      homeLocation: overrideHomeLocation,
      role: Role.user,
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
    addLog('LoggingTwitarr(${_configuration.id}).login $username / $password');
    return Progress<AuthenticatedUser>.completed(AuthenticatedUser(
      username: username,
      email: '<email for $username>',
      homeLocation: overrideHomeLocation,
      role: Role.user,
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
    addLog('LoggingTwitarr(${_configuration.id}).getAuthenticatedUser $credentials');
    return Progress<AuthenticatedUser>.completed(AuthenticatedUser(
      username: credentials.username,
      email: '<email for ${credentials.username}>',
      homeLocation: overrideHomeLocation,
      credentials: credentials,
      role: Role.user,
    ));
  }

  @override
  Progress<User> getUser(Credentials credentials, String username, PhotoManager photoManager) {
    addLog('LoggingTwitarr(${_configuration.id}).getAuthenticatedUser $username, $credentials');
    return Progress<User>.completed(User(
      username: username,
      role: Role.user,
    ));
  }

  @override
  Progress<Calendar> getCalendar({
    Credentials credentials,
  }) {
    addLog('LoggingTwitarr(${_configuration.id}).getCalendar($credentials)');
    return const Progress<Calendar>.idle();
  }

  @override
  Progress<void> setEventFavorite({
    @required Credentials credentials,
    @required String eventId,
    @required bool favorite,
  }) {
    addLog('LoggingTwitarr(${_configuration.id}).setEventFavorite($credentials, $eventId, $favorite)');
    return const Progress<void>.idle();
  }

  @override
  Progress<List<AnnouncementSummary>> getAnnouncements() {
    addLog('LoggingTwitarr(${_configuration.id}).getAnnouncements()');
    return Progress<List<AnnouncementSummary>>.completed(const <AnnouncementSummary>[]);
  }

  @override
  Progress<Map<String, bool>> getSectionStatus() {
    addLog('LoggingTwitarr(${_configuration.id}).getSectionStatus()');
    return Progress<Map<String, bool>>.completed(const <String, bool>{});
  }

  @override
  Progress<UpdateIntervals> getUpdateIntervals() {
    addLog('$this.getUpdateIntervals()');
    return Progress<UpdateIntervals>.completed(
      const UpdateIntervals(
        seamail: Duration(hours: 1),
        events: Duration(hours: 1),
        updateIntervals: Duration(hours: 1),
      ),
    );
  }

  @override
  Progress<ServerText> fetchServerText(String filename) {
    addLog('LoggingTwitarr(${_configuration.id}).fetchServerText($filename)');
    return const Progress<ServerText>.idle();
  }

  @override
  Progress<Uint8List> fetchProfilePicture(String username) {
    addLog('fetchProfilePicture');
    return Progress<Uint8List>.completed(Uint8List.fromList(<int>[
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00,
      0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01,
      0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1f,
      0x15, 0xc4, 0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00,
      0x01,
    ]));
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
    addLog('updateProfile $displayName/$realName/$pronouns/$email/$homeLocation/$roomNumber');
    return Progress<void>.completed(null);
  }

  @override
  Progress<void> uploadAvatar({
    @required Credentials credentials,
    @required Uint8List bytes,
  }) {
    addLog('uploadAvatar ${bytes.length} bytes');
    return null;
  }

  @override
  Progress<void> resetAvatar({
    @required Credentials credentials,
  }) {
    addLog('resetAvatar');
    return null;
  }

  @override
  Progress<Uint8List> fetchImage(String photoId, { bool thumbnail = false }) {
    addLog('fetchImage $photoId (thumbnail=$thumbnail)');
    return null;
  }

  @override
  Progress<String> uploadImage({
    @required Credentials credentials,
    @required Uint8List bytes,
  }) {
    addLog('uploadImage');
    return null;
  }

  @override
  Progress<void> updatePassword({
    @required Credentials credentials,
    @required String oldPassword,
    @required String newPassword,
  }) {
    addLog('updatePassword');
    return null;
  }

  @override
  Progress<List<User>> getUserList(String searchTerm) {
    addLog('getUserList');
    return null;
  }

  @override
  Progress<SeamailSummary> getSeamailThreads({
    @required Credentials credentials,
    int freshnessToken,
  }) {
    addLog('getSeamailThreads for $credentials from $freshnessToken');
    return const Progress<SeamailSummary>.idle();
  }

  @override
  Progress<SeamailSummary> getUnreadSeamailMessages({
    @required Credentials credentials,
    int freshnessToken,
  }) {
    addLog('getUnreadSeamailMessages');
    return null;
  }

  @override
  Progress<SeamailThreadSummary> getSeamailMessages({
    @required Credentials credentials,
    @required String threadId,
    bool markRead = true,
  }) {
    addLog('getSeamailMessages');
    return null;
  }

  @override
  Progress<SeamailMessageSummary> postSeamailMessage({
    @required Credentials credentials,
    @required String threadId,
    @required String text,
  }) {
    addLog('postSeamailMessage');
    return null;
  }

  @override
  Progress<SeamailThreadSummary> createSeamailThread({
    @required Credentials credentials,
    @required Set<User> users,
    @required String subject,
    @required String text,
  }) {
    addLog('createSeamailThread');
    return null;
  }

  @override
  Progress<StreamSliceSummary> getStream({
    Credentials credentials,
    @required StreamDirection direction,
    int boundaryToken,
    int limit = 100,
  }) {
    addLog('getStream');
    return const Progress<StreamSliceSummary>.idle();
  }

  @override
  Progress<StreamMessageSummary> getTweet({
    Credentials credentials,
    String threadId,
  }) {
    addLog('getTweet');
    return const Progress<StreamMessageSummary>.idle();
  }

  @override
  Progress<void> postTweet({
    @required Credentials credentials,
    @required String text,
    String parentId,
    @required Uint8List photo,
  }) {
    addLog('postTweet');
    return null;
  }

  @override
  Progress<void> deleteTweet({
    @required Credentials credentials,
    @required String postId,
  }) {
    addLog('deleteTweet');
    return null;
  }

  @override
  Progress<Map<String, ReactionSummary>> reactTweet({
    @required Credentials credentials,
    @required String postId,
    @required String reaction,
    @required bool selected,
  }) {
    addLog('reactTweet');
    return null;
  }

  @override
  Progress<Map<String, Set<UserSummary>>> getTweetReactions({
    @required Credentials credentials,
    @required String postId,
  }) {
    addLog('getTweetReactions');
    return null;
  }

  @override
  Progress<ForumListSummary> getForumThreads({
    Credentials credentials,
    @required int fetchCount,
  }) {
    addLog('getForumThreads');
    return const Progress<ForumListSummary>.idle();
  }

  @override
  Progress<ForumSummary> getForumThread({
    Credentials credentials,
    @required String threadId,
  }) {
    addLog('getForumThread $threadId');
    return null;
  }

  @override
  Progress<ForumSummary> createForumThread({
    Credentials credentials,
    @required String subject,
    @required String text,
    @required List<Uint8List> photos,
  }) {
    addLog('createForumThread "$subject" "$text"');
    return null;
  }

  @override
  Progress<void> postForumMessage({
    Credentials credentials,
    @required String threadId,
    @required String text,
    @required List<Uint8List> photos,
  }) {
    addLog('postForumMessage $threadId "$text"');
    return null;
  }

  @override
  Progress<bool> deleteForumMessage({
    Credentials credentials,
    @required String threadId,
    @required String messageId,
  }) {
    addLog('deleteForumMessage $threadId $messageId');
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
    addLog('reactForumMessage');
    return null;
  }

  @override
  Progress<Map<String, Set<UserSummary>>> getForumMessageReactions({
    @required Credentials credentials,
    @required String threadId,
    @required String messageId,
  }) {
    addLog('getForumMessageReactions');
    return null;
  }

  @override
  Progress<MentionsSummary> getMentions({
    Credentials credentials,
  }) {
    addLog('getMentions');
    return const Progress<MentionsSummary>.idle();
  }

  @override
  Progress<void> clearMentions({
    Credentials credentials,
    int freshnessToken,
  }) {
    addLog('clearMentions $freshnessToken');
    return null;
  }

  @override
  void noSuchMethod(Invocation invocation) {
    addLog('$this.${_describeInvocation(invocation)}');
  }

  @override
  String toString() => '$runtimeType(${_configuration.id})';
}

String _valueName(Object value) {
  if (value is double)
    return value.toStringAsFixed(1);
  return value.toString();
}

// Workaround for https://github.com/dart-lang/sdk/issues/28372
String _symbolName(Symbol symbol) {
  // WARNING: Assumes a fixed format for Symbol.toString which is *not*
  // guaranteed anywhere.
  final String s = '$symbol';
  return s.substring(8, s.length - 2);
}

// Workaround for https://github.com/dart-lang/sdk/issues/28373
String _describeInvocation(Invocation call) {
  final StringBuffer buffer = StringBuffer();
  buffer.write(_symbolName(call.memberName));
  if (call.isSetter) {
    buffer.write(call.positionalArguments[0].toString());
  } else if (call.isMethod) {
    buffer.write('(');
    buffer.writeAll(call.positionalArguments.map<String>(_valueName), ', ');
    String separator = call.positionalArguments.isEmpty ? '' : ', ';
    call.namedArguments.forEach((Symbol name, Object value) {
      buffer.write(separator);
      buffer.write(_symbolName(name));
      buffer.write(': ');
      buffer.write(_valueName(value));
      separator = ', ';
    });
    buffer.write(')');
  }
  return buffer.toString();
}
