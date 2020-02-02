import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../logic/photo_manager.dart';
import '../models/calendar.dart';
import '../models/reactions.dart';
import '../models/server_status.dart';
import '../models/server_text.dart';
import '../models/string.dart';
import '../models/user.dart';
import '../progress.dart';

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
    _configurationClasses[prefix] = factory;
  }
  static TwitarrConfiguration from(String serialization, TwitarrConfiguration defaultConfig) {
    if (serialization == null)
      return defaultConfig;
    final int colon = serialization.indexOf(':');
    final String prefix = serialization.substring(0, colon);
    final String settings = serialization.substring(colon + 1);
    if (!_configurationClasses.containsKey(prefix))
      throw Exception('unknown Twitarr configuration class "$prefix"');
    return _configurationClasses[prefix](settings);
  }
}

/// An interface for communicating with the server.
abstract class Twitarr {
  const Twitarr();

  void enable(ServerStatus status);
  void disable();

  double get debugLatency;
  set debugLatency(double value);

  double get debugReliability;
  set debugReliability(double value);

  TwitarrConfiguration get configuration;

  String get photoCacheKey; // a key that's unique to the current source of photos

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

  Progress<AuthenticatedUser> resetPassword({
    @required String username,
    @required String registrationCode,
    @required String password,
    @required PhotoManager photoManager,
  });

  Progress<AuthenticatedUser> changePassword({
    @required Credentials credentials,
    @required String newPassword,
    @required PhotoManager photoManager,
  });

  Progress<AuthenticatedUser> getAuthenticatedUser(Credentials credentials, PhotoManager photoManager);

  Progress<User> getUser(Credentials credentials, String username, PhotoManager photoManager);

  Progress<Calendar> getCalendar({
    Credentials credentials,
  });

  Progress<UpcomingCalendar> getUpcomingEvents({
    Credentials credentials,
    Duration window,
  });

  Progress<void> setEventFavorite({
    @required Credentials credentials,
    @required String eventId,
    @required bool favorite,
  });

  Progress<List<AnnouncementSummary>> getAnnouncements();

  Progress<ServerTime> getServerTime();

  Progress<Map<String, bool>> getSectionStatus();

  Progress<ServerText> fetchServerText(String filename);

  Progress<Uint8List> fetchProfilePicture(String username);

  Progress<void> updateProfile({
    @required Credentials credentials,
    String displayName,
    String realName,
    String pronouns,
    String email,
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

  Progress<Uint8List> fetchImage(String photoId, { bool thumbnail = false });

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

  Progress<StreamMessageSummary> getTweet({
    Credentials credentials,
    String threadId,
  });

  Progress<void> postTweet({
    @required Credentials credentials,
    @required String text,
    String parentId,
    @required Uint8List photo,
  });

  Progress<void> lockTweet({
    Credentials credentials,
    @required String postId,
    @required bool locked,
  });

  Progress<void> editTweet({
    Credentials credentials,
    @required String postId,
    @required String text,
    @required List<String> keptPhotos,
    @required List<Uint8List> newPhotos,
  });

  Progress<void> deleteTweet({
    @required Credentials credentials,
    @required String postId,
  });

  Progress<Map<String, ReactionSummary>> reactTweet({
    @required Credentials credentials,
    @required String postId,
    @required String reaction,
    @required bool selected,
  });

  Progress<Map<String, Set<UserSummary>>> getTweetReactions({
    @required String postId,
  });

  Progress<ForumListSummary> getForumThreads({
    Credentials credentials,
    @required int fetchCount,
  });

  Progress<ForumSummary> getForumThread({
    Credentials credentials,
    @required String threadId,
  });

  Progress<ForumSummary> createForumThread({
    Credentials credentials,
    @required String subject,
    @required String text,
    @required List<Uint8List> photos,
  });

  Progress<void> stickyForumThread({
    Credentials credentials,
    @required String threadId,
    @required bool sticky,
  });

  Progress<void> lockForumThread({
    Credentials credentials,
    @required String threadId,
    @required bool locked,
  });

  Progress<void> deleteForumThread({
    Credentials credentials,
    @required String threadId,
  });

  Progress<void> postForumMessage({
    Credentials credentials,
    @required String threadId,
    @required String text,
    @required List<Uint8List> photos,
  });

  Progress<void> editForumMessage({
    Credentials credentials,
    @required String threadId,
    @required String messageId,
    @required String text,
    @required List<String> keptPhotos,
    @required List<Uint8List> newPhotos,
  });

  Progress<bool> deleteForumMessage({
    Credentials credentials,
    @required String threadId,
    @required String messageId,
  });

  Progress<Map<String, ReactionSummary>> reactForumMessage({
    @required Credentials credentials,
    @required String threadId,
    @required String messageId,
    @required String reaction,
    @required bool selected,
  });

  Progress<Map<String, Set<UserSummary>>> getForumMessageReactions({
    @required String threadId,
    @required String messageId,
  });

  Progress<MentionsSummary> getMentions({
    Credentials credentials,
  });

  Progress<void> clearMentions({
    Credentials credentials,
    @required int freshnessToken,
  });

  Progress<Set<SearchResultSummary>> search({
    Credentials credentials,
    String searchTerm,
  });

  void dispose();
}

abstract class SearchResultSummary { }

class SeamailSummary {
  const SeamailSummary({
    this.threads,
    this.freshnessToken,
  });

  final Set<SeamailThreadSummary> threads;

  final int freshnessToken;
}

class SeamailThreadSummary implements SearchResultSummary {
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

  final TwitarrString text;

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

class StreamMessageSummary implements SearchResultSummary {
  const StreamMessageSummary({
    this.id,
    this.user,
    this.text,
    this.photo,
    @required this.timestamp,
    this.boundaryToken,
    this.locked,
    this.reactions,
    this.parents,
    this.children,
  }) : assert(timestamp != null);

  final String id;

  final UserSummary user;

  final TwitarrString text;

  final Photo photo;

  final DateTime timestamp;

  final int boundaryToken;

  final bool locked;

  final Map<String, ReactionSummary> reactions;

  final List<String> parents;

  final List<StreamMessageSummary> children;
}

class ForumListSummary {
  const ForumListSummary({
    this.forums,
    this.totalCount,
  });

  final Set<ForumSummary> forums;

  final int totalCount;
}

class ForumSummary implements SearchResultSummary {
  const ForumSummary({
    this.id,
    this.subject,
    this.sticky,
    this.locked,
    this.totalCount,
    this.unreadCount,
    this.lastMessageUser,
    this.lastMessageTimestamp,
    this.messages,
  });

  final String id;

  final String subject;

  final bool sticky;

  final bool locked;

  final int totalCount;

  final int unreadCount;

  final UserSummary lastMessageUser;

  final DateTime lastMessageTimestamp;

  final List<ForumMessageSummary> messages;
}

class ForumMessageSummary {
  const ForumMessageSummary({
    this.id,
    this.user,
    this.text,
    this.photos,
    this.timestamp,
    this.read,
    this.reactions,
  });

  final String id;

  final UserSummary user;

  final TwitarrString text;

  final List<Photo> photos;

  final DateTime timestamp;

  final bool read;

  final Map<String, ReactionSummary> reactions;
}

class AnnouncementSummary {
  const AnnouncementSummary({
    this.id,
    this.user,
    this.message,
    this.timestamp,
  });

  final String id;

  final UserSummary user;

  final TwitarrString message;

  final DateTime timestamp;

  Announcement toAnnouncement(PhotoManager photoManager) {
    return Announcement(
      id: id,
      user: user.toUser(photoManager),
      message: message,
      timestamp: timestamp,
    );
  }
}

class UserSummary implements SearchResultSummary {
  const UserSummary({
    @required this.username,
    this.displayName,
    @required this.photoTimestamp,
  }) : assert(username != null),
       assert(photoTimestamp != null);

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
      role: Role.none,
    );
  }
}

class MentionsSummary {
  const MentionsSummary({
    this.streamPosts,
    this.forums,
    this.freshnessToken,
  });

  final List<StreamMessageSummary> streamPosts;

  final List<ForumSummary> forums;

  final int freshnessToken;
}

class EventSummary extends Event implements SearchResultSummary {
  const EventSummary({
    String id,
    String title,
    bool official,
    bool following,
    TwitarrString description,
    String location,
    DateTime startTime,
    DateTime endTime,
  }) : super(
    id: id,
    title: title,
    official: official,
    following: following,
    description: description,
    location: location,
    startTime: startTime,
    endTime: endTime,
  );
}

class ServerTime {
  const ServerTime({
    @required DateTime serverNow,
    @required this.clientNow,
    @required this.serverTimeZoneOffset,
    @required this.clientTimeZoneOffset,
  }) : now = serverNow;

  // The time on the server.
  final DateTime now;

  // The time on the client at roughly the same instant as [now].
  final DateTime clientNow;

  // The difference between the device time and the server time.
  //
  // Positive numbers mean that the server time is ahead of the device time.
  // Negative numbers mean that the server time is behind the device time.
  Duration get skew => now.difference(clientNow);

  // Server time zone.
  //
  // Negative numbers are west of the meridian.
  // Positive numbers are east of the meridian.
  //
  // For example, -480 is -8 hours which is PDT (California in winter).
  final Duration serverTimeZoneOffset;

  // Device time zone.
  //
  // Negative numbers are west of the meridian.
  // Positive numbers are east of the meridian.
  //
  // For example, -480 is -8 hours which is PDT (California in winter).
  final Duration clientTimeZoneOffset;
}
