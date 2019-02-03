import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../logic/photo_manager.dart';
import '../models/calendar.dart';
import '../models/user.dart';
import '../progress.dart';

abstract class UserFriendlyError { }

class LocalError implements Exception, UserFriendlyError {
  const LocalError(this.message);

  final String message;

  @override
  String toString() => message;
}

class ServerError implements Exception, UserFriendlyError {
  const ServerError(this.messages);

  final List<String> messages;

  @override
  String toString() => messages.join('\n');
}

class InvalidUsernameOrPasswordError implements Exception, UserFriendlyError {
  const InvalidUsernameOrPasswordError();

  @override
  String toString() => 'Server did not recognize the username or password.';
}

class FieldErrors implements Exception {
  const FieldErrors(this.fields);

  final Map<String, List<String>> fields;

  @override
  String toString() => 'Account creation failed:\n$fields';
}

class HttpServerError implements Exception, UserFriendlyError {
  const HttpServerError(this.statusCode, this.reasonPhrase, this.url);

  final int statusCode;
  final String reasonPhrase;
  final Uri url;

  @override
  String toString() {
    switch (statusCode) {
      case 500:
      case 501:
      case 502:
      case 503:
      case 504: return 'Server is having problems (it said "$reasonPhrase"). Try again later.';
      case 401:
      case 403: return 'There was an authentication problem (server said "$reasonPhrase"). Try logging in again.';
      case 400:
      case 405: return 'There is probably a bug (server said "$reasonPhrase"). Try again, maybe?';
      default: return 'There was an unexpected error. The server said "$statusCode $reasonPhrase" in response to a request to: $url';
    }
  }
}

typedef TwitarrConfigurationFactory = TwitarrConfiguration Function(String settings);

@immutable
abstract class TwitarrConfiguration {
  const TwitarrConfiguration();
  Twitarr createTwitarr();

  @override
  String toString() => '$prefix:$settings';

  @protected
  String get prefix;

  @protected
  String get settings;

  static final Map<String, TwitarrConfigurationFactory> _configurationClasses = <String, TwitarrConfigurationFactory>{};
  static void register(String prefix, TwitarrConfigurationFactory factory) {
    assert(!_configurationClasses.containsKey(prefix));
    _configurationClasses[prefix] = factory;
  }
  static TwitarrConfiguration from(String prefix, String settings) {
    if (!_configurationClasses.containsKey(prefix))
      throw Exception('unknown Twitarr configuration class "$prefix"');
    return _configurationClasses[prefix](settings);
  }
}

/// An interface for communicating with the server.
abstract class Twitarr {
  const Twitarr();

  double get debugLatency;
  set debugLatency(double value);

  double get debugReliability;
  set debugReliability(double value);

  TwitarrConfiguration get configuration;

  Progress<AuthenticatedUser> createAccount({
    @required String username,
    @required String password,
    @required String registrationCode,
    String displayName,
  });

  Progress<AuthenticatedUser> login({
    @required String username,
    @required String password,
    @required PhotoManager photoManager,
  });

  Progress<AuthenticatedUser> getAuthenticatedUser(Credentials credentials, PhotoManager photoManager);

  Progress<Calendar> getCalendar({
    Credentials credentials,
  });

  Progress<void> setEventFavorite({
    @required Credentials credentials,
    @required String eventId,
    @required bool favorite,
  });

  Progress<Uint8List> fetchProfilePicture(String username);

  Progress<void> updateProfile({
    @required Credentials credentials,
    String displayName,
    String realName,
    String pronouns,
    String email,
    String currentLocation,
    String homeLocation,
    String roomNumber,
  });

  Progress<void> uploadAvatar({
    @required Credentials credentials,
    @required Uint8List bytes,
  });

  Progress<void> resetAvatar({
    @required Credentials credentials,
  });

  Progress<Uint8List> fetchImage(String photoId);

  Progress<String> uploadImage({
    @required Credentials credentials,
    @required Uint8List bytes,
  });

  Progress<void> updatePassword({
    @required Credentials credentials,
    @required String oldPassword,
    @required String newPassword,
  });

  Progress<List<User>> getUserList(String searchTerm);

  Progress<SeamailSummary> getSeamailThreads({
    @required Credentials credentials,
    int freshnessToken,
  });

  Progress<SeamailSummary> getUnreadSeamailMessages({
    @required Credentials credentials,
    int freshnessToken,
  });

  Progress<SeamailThreadSummary> getSeamailMessages({
    @required Credentials credentials,
    @required String threadId,
    bool markRead = true,
  });

  Progress<SeamailMessageSummary> postSeamailMessage({
    @required Credentials credentials,
    @required String threadId,
    @required String text,
  });

  Progress<SeamailThreadSummary> createSeamailThread({
    @required Credentials credentials,
    @required Set<User> users,
    @required String subject,
    @required String text,
  });

  Progress<StreamSliceSummary> getStream({
    Credentials credentials,
    @required StreamDirection direction,
    int boundaryToken,
    int limit = 100,
  });

  Progress<void> postTweet({
    @required Credentials credentials,
    @required String text,
    String parentId,
    @required Uint8List photo,
  });

  Progress<Set<ForumSummary>> getForumThreads({
    Credentials credentials,
  });

  Progress<List<ForumMessageSummary>> getForumMessages({
    Credentials credentials,
    @required String threadId,
  });

  Progress<ForumSummary> createForumThread({
    Credentials credentials,
    @required String subject,
    @required String text,
    @required List<Uint8List> photos,
  });

  Progress<void> postForumMessage({
    Credentials credentials,
    @required String threadId,
    @required String text,
    @required List<Uint8List> photos,
  });

  void dispose();
}

class SeamailSummary {
  const SeamailSummary({
    this.threads,
    this.freshnessToken,
  });

  final Set<SeamailThreadSummary> threads;

  final int freshnessToken;
}

class SeamailThreadSummary {
  const SeamailThreadSummary({
    this.id,
    this.subject,
    this.users,
    this.messages,
    this.lastMessageTimestamp,
    this.unreadMessages,
    this.totalMessages,
    this.unread,
  });

  final String id;

  final String subject;

  final Set<UserSummary> users;

  final List<SeamailMessageSummary> messages;

  final DateTime lastMessageTimestamp;

  final int unreadMessages;

  final int totalMessages;

  final bool unread;
}

class SeamailMessageSummary {
  const SeamailMessageSummary({
    this.id,
    this.user,
    this.text,
    this.timestamp,
    this.readReceipts,
  });

  final String id;

  final UserSummary user;

  final String text;

  final DateTime timestamp;

  final Set<UserSummary> readReceipts;
}

enum StreamDirection { backwards, forwards }

class StreamSliceSummary {
  const StreamSliceSummary({
    this.direction,
    this.posts,
    this.boundaryToken,
  });

  final StreamDirection direction;

  final List<StreamMessageSummary> posts;

  final int boundaryToken;
}

class StreamMessageSummary {
  const StreamMessageSummary({
    this.id,
    this.user,
    this.text,
    this.photoId,
    @required this.timestamp,
    this.boundaryToken,
    this.reactions,
    this.parents,
  }) : assert(timestamp != null),
       deleted = false;

  const StreamMessageSummary.deleted({
    this.id,
    @required this.timestamp,
    this.boundaryToken,
  }) : assert(timestamp != null),
       user = null,
       text = null,
       photoId = null,
       reactions = null,
       parents = null,
       deleted = true;

  final String id;

  final UserSummary user;

  final String text;

  final String photoId;

  final DateTime timestamp;

  final int boundaryToken;

  final Map<String, Set<UserSummary>> reactions; // String=null is "likes"

  final List<String> parents;

  final bool deleted;
}

class ForumSummary {
  const ForumSummary({
    this.id,
    this.subject,
    this.totalCount,
    this.unreadCount,
    this.lastMessageUser,
    this.lastMessageTimestamp,
  });

  final String id;

  final String subject;

  final int totalCount;

  final int unreadCount;

  final UserSummary lastMessageUser;

  final DateTime lastMessageTimestamp;
}

class ForumMessageSummary {
  const ForumMessageSummary({
    this.id,
    this.user,
    this.text,
    this.photoIds,
    this.timestamp,
    this.read,
  });

  final String id;

  final UserSummary user;

  final String text;

  final List<String> photoIds;

  final DateTime timestamp;

  final bool read;
}

class UserSummary {
  const UserSummary({
    this.username,
    this.displayName,
    this.photoTimestamp,
  });

  final String username;

  final String displayName;

  final DateTime photoTimestamp;

  User toUser(PhotoManager photoManager) {
    if (photoManager != null) {
      photoManager.heardAboutUserPhoto(
        username,
        photoTimestamp,
      );
    }
    return User(
      username: username,
      displayName: displayName,
    );
  }
}
