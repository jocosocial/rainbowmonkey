import 'package:flutter/foundation.dart';

import 'user.dart';

@immutable
class Announcement {
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
  String toString() => '$runtimeType($user: "$message")';
}
