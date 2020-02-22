import 'package:flutter/foundation.dart';

import 'string.dart';
import 'user.dart';

@immutable
class Announcement implements Comparable<Announcement> {
  const Announcement({
    this.id,
    this.user,
    this.message,
    this.timestamp,
  });

  final String id;

  final User user;

  final TwitarrString message;

  final DateTime timestamp;

  @override
  int compareTo(Announcement other) {
    if (other.timestamp != timestamp)
      return -timestamp.compareTo(other.timestamp);
    return -id.compareTo(other.id);
  }

  @override
  String toString() => '$runtimeType($user: "$message")';
}

@immutable
class UpdateIntervals {
  const UpdateIntervals({
    @required this.seamail,
    @required this.events,
    @required this.updateIntervals,
  });

  final Duration seamail;

  final Duration events;

  final Duration updateIntervals;
}

@immutable
class ServerStatus {
  const ServerStatus({
    this.announcements = const <Announcement>[],
    this.updateIntervals = const UpdateIntervals(
      seamail: Duration(minutes: 1),
      events: Duration(minutes: 5),
      updateIntervals: Duration(seconds: 30),
    ),
    this.userRole = Role.none,
    bool forumsEnabled = true,
    bool streamEnabled = true,
    bool seamailEnabled = true,
    bool calendarEnabled = true,
    bool deckPlansEnabled = true,
    bool gamesEnabled = true,
    bool karaokeEnabled = true,
    bool searchEnabled = true,
    bool registrationEnabled = true,
    bool userProfileEnabled = true,
  }) : assert(userRole != null),
       _forumsEnabled = forumsEnabled,
       _streamEnabled = streamEnabled,
       _seamailEnabled = seamailEnabled,
       _calendarEnabled = calendarEnabled,
       _deckPlansEnabled = deckPlansEnabled,
       _gamesEnabled = gamesEnabled,
       _karaokeEnabled = karaokeEnabled,
       _searchEnabled = searchEnabled,
       _registrationEnabled = registrationEnabled,
       _userProfileEnabled = userProfileEnabled;

  ServerStatus copyWith({
    List<Announcement> announcements,
    UpdateIntervals updateIntervals,
    Role userRole,
    bool forumsEnabled,
    bool streamEnabled,
    bool seamailEnabled,
    bool calendarEnabled,
    bool deckPlansEnabled,
    bool gamesEnabled,
    bool karaokeEnabled,
    bool searchEnabled,
    bool registrationEnabled,
    bool userProfileEnabled,
  }) {
    return ServerStatus(
      announcements: announcements ?? this.announcements,
      updateIntervals: updateIntervals ?? this.updateIntervals,
      userRole: userRole ?? this.userRole,
      forumsEnabled: forumsEnabled ?? _forumsEnabled,
      streamEnabled: streamEnabled ?? _streamEnabled,
      seamailEnabled: seamailEnabled ?? _seamailEnabled,
      calendarEnabled: calendarEnabled ?? _calendarEnabled,
      deckPlansEnabled: deckPlansEnabled ?? _deckPlansEnabled,
      gamesEnabled: gamesEnabled ?? _gamesEnabled,
      karaokeEnabled: karaokeEnabled ?? _karaokeEnabled,
      searchEnabled: searchEnabled ?? _searchEnabled,
      registrationEnabled: registrationEnabled ?? _registrationEnabled,
      userProfileEnabled: userProfileEnabled ?? _userProfileEnabled,
    );
  }

  final List<Announcement> announcements;

  final UpdateIntervals updateIntervals;

  final Role userRole;

  // TODO(ianh): make this use user.canModerate instead
  bool get _override {
    assert(userRole != null);
    switch (userRole) {
      case Role.admin:
      case Role.tho:
      case Role.moderator:
        return true;
      case Role.user:
      case Role.muted:
      case Role.banned:
      case Role.none:
        return false;
    }
    return null;
  }

  bool get forumsEnabled => _forumsEnabled || _override;
  final bool _forumsEnabled;

  bool get streamEnabled => _streamEnabled || _override;
  final bool _streamEnabled;

  bool get seamailEnabled => _seamailEnabled || _override;
  final bool _seamailEnabled;

  bool get calendarEnabled => _calendarEnabled || _override;
  final bool _calendarEnabled;

  bool get deckPlansEnabled => _deckPlansEnabled || _override;
  final bool _deckPlansEnabled;

  bool get gamesEnabled => _gamesEnabled || _override;
  final bool _gamesEnabled;

  bool get karaokeEnabled => _karaokeEnabled || _override;
  final bool _karaokeEnabled;

  bool get searchEnabled => _searchEnabled || _override;
  final bool _searchEnabled;

  bool get registrationEnabled => _registrationEnabled || _override;
  final bool _registrationEnabled;

  bool get userProfileEnabled => _userProfileEnabled || _override;
  final bool _userProfileEnabled;
}
