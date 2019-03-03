import 'package:flutter/foundation.dart';

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

  final String message;

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
class ServerStatus {
  const ServerStatus({
    this.announcements = const <Announcement>[],
    this.forumsEnabled = true,
    this.streamEnabled = true,
    this.seamailEnabled = true,
    this.calendarEnabled = true,
    this.deckPlansEnabled = true,
    this.gamesEnabled = true,
    this.karaokeEnabled = true,
    this.registrationEnabled = true,
    this.userProfileEnabled = true,
  });

  final List<Announcement> announcements;

  final bool forumsEnabled;

  final bool streamEnabled;

  final bool seamailEnabled;

  final bool calendarEnabled;

  final bool deckPlansEnabled;

  final bool gamesEnabled;

  final bool karaokeEnabled;

  final bool registrationEnabled;

  final bool userProfileEnabled;
}