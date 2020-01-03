import 'package:flutter/foundation.dart';

import 'search.dart';

@immutable
class Event extends SearchResult implements Comparable<Event> {
  const Event({
    @required this.id,
    @required this.title,
    @required this.official,
    this.following = false,
    this.description,
    @required this.location,
    @required this.startTime,
    @required this.endTime,
  }) : assert(id != null),
       assert(title != null),
       assert(official != null),
       assert(following != null),
       assert(location != null),
       assert(startTime != null),
       assert(endTime != null);

  final String id; // 16 bytes in hex
  final String title;
  final bool official;
  final bool following;
  final String description;
  final String location;
  final DateTime startTime;
  final DateTime endTime;

  @override
  int compareTo(Event other) {
    if (startTime.isBefore(other.startTime))
      return -1;
    if (startTime.isAfter(other.startTime))
      return 1;
    if (endTime.isBefore(other.endTime))
      return -1;
    if (endTime.isAfter(other.endTime))
      return 1;
    if (official && !other.official)
      return -1;
    if (other.official && !official)
      return 1;
    if (location != other.location)
      return location.compareTo(other.location);
    if (title != other.title)
      return title.compareTo(other.title);
    return id.compareTo(other.id);
  }

  @override
  String toString() => 'Event("$title")';
}

@immutable
class Calendar {
  factory Calendar({
    @required List<Event> events,
  }) {
    assert(events != null);
    return Calendar._(events.toList()..sort());
  }

  const Calendar._(this._events);

  final List<Event> _events;
  List<Event> get events => _events;

  @override
  String toString() => 'Calendar($events)';
}
