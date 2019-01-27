import 'package:flutter/foundation.dart';

@immutable
class Event {
  Event({
    @required this.id,
    @required this.title,
    @required this.official,
    this.description,
    @required this.location,
    @required this.startTime,
    @required this.endTime,
  }) : assert(id != null),
       assert(title != null),
       assert(official != null),
       assert(location != null),
       assert(startTime != null),
       assert(endTime != null),
       assert(startTime.isBefore(endTime));

  final String id; // 16 bytes in hex
  final String title;
  final bool official;
  final String description;
  final String location;
  final DateTime startTime;
  final DateTime endTime;

  @override
  String toString() => 'Event("$title")';
}

@immutable
class Calendar {
  factory Calendar({
    @required List<Event> events,
  }) {
    assert(events != null);
    return Calendar._(
      events.toList()
      ..sort((Event a, Event b) {
        if (a.startTime.isBefore(b.startTime))
          return -1;
        if (a.startTime.isAfter(b.startTime))
          return 1;
        if (a.endTime.isBefore(b.endTime))
          return -1;
        if (a.endTime.isAfter(b.endTime))
          return 1;
        if (a.official && !b.official)
          return -1;
        if (b.official && !a.official)
          return 1;
        if (a.location != b.location)
          return a.location.compareTo(b.location);
        if (a.title != b.title)
          return a.title.compareTo(b.title);
        return a.id.compareTo(b.id);
      })
    );
  }

  const Calendar._(this._events);

  final List<Event> _events;
  List<Event> get events => _events;

  @override
  String toString() => 'Calendar($events)';
}
