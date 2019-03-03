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
