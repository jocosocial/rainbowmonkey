import 'package:flutter/foundation.dart';

class User {
  const User({ this.name, this.email });

  final String name;
  final String email;
}

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
}

class Calendar {
  Calendar({
    @required List<Event> events,
  }) : assert(events != null) {
    _events = events.toList()
      ..sort((Event a, Event b) {
        if (a.startTime.isBefore(b.startTime))
          return -1;
        if (a.startTime.isAfter(b.startTime))
          return 1;
        if (a.endTime.isBefore(b.endTime))
          return 1;
        if (a.endTime.isAfter(b.endTime))
          return -1;
        if (a.official && !b.official)
          return -1;
        if (b.official && !a.official)
          return 1;
        if (a.location != b.location)
          return a.location.compareTo(b.location);
        return a.title.compareTo(b.title);
      });
  }

  List<Event> _events;
  List<Event> get events => _events;
}
