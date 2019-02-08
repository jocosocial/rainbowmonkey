import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/calendar.dart';
import '../widgets.dart';

class CalendarView extends StatefulWidget implements View {
  const CalendarView({
    Key key,
  }) : super(key: key);

  @override
  Widget buildTabIcon(BuildContext context) => const Icon(Icons.event);

  @override
  Widget buildTabLabel(BuildContext context) => const Text('Calendar');

  @override
  Widget buildFab(BuildContext context) {
    return null;
  }

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

typedef FavoriteCallback = void Function(Event event, bool favorite);

class _PendingFavoriteUpdate {
  _PendingFavoriteUpdate();
  bool state;
}

class _CalendarViewState extends State<CalendarView> {
  static final Key _beforeKey = UniqueKey();
  static final Key _afterKey = UniqueKey();

  final Map<String, _PendingFavoriteUpdate> _pendingUpdates = <String, _PendingFavoriteUpdate>{};
  int _activePendingUpdates = 0;

  void _handleFavorite(Event event, bool favorite) async {
    _activePendingUpdates += 1;
    final _PendingFavoriteUpdate update = _pendingUpdates.putIfAbsent(event.id, () => _PendingFavoriteUpdate());
    setState(() {
      update.state = favorite;
    });
    try {
      await Cruise.of(context).setEventFavorite(eventId: event.id, favorite: favorite).asFuture();
    } finally {
      _activePendingUpdates -= 1;
      if (_activePendingUpdates == 0) {
        setState(_pendingUpdates.clear);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO(ianh): button to jump to "now"
    // TODO(ianh): setState when the time changes sufficiently
    // TODO(ianh): show event overlaps somehow
    // TODO(ianh): filter to favorite events only
    return ContinuousProgressBuilder<Calendar>(
      progress: Cruise.of(context).calendar,
      onRetry: () { Cruise.of(context).forceUpdate(); },
      builder: (BuildContext context, Calendar calendar) {
        if (calendar.events.isEmpty)
          return iconAndLabel(icon: Icons.sentiment_neutral, message: 'Calendar is empty');
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final DateTime now = Now.of(context);
            final bool isLoggedIn = Cruise.of(context).isLoggedIn;
            final List<Event> beforeEvents = calendar.events.where((Event event) => !event.endTime.isAfter(now)).toList().reversed.toList();
            final List<Event> afterEvents = calendar.events.where((Event event) => event.endTime.isAfter(now)).toList();
            return CustomScrollView(
              center: _afterKey,
              anchor: MediaQuery.of(context).padding.top / constraints.maxHeight,
              slivers: <Widget>[
                SliverSafeArea(
                  key: _beforeKey,
                  top: false,
                  bottom: false,
                  sliver: EventList(
                    events: beforeEvents,
                    now: now,
                    isLoggedIn: isLoggedIn,
                    onSetFavorite: _handleFavorite,
                    direction: GrowthDirection.reverse,
                    pendingUpdates: _pendingUpdates,
                  ),
                ),
                SliverSafeArea(
                  key: _afterKey,
                  top: false,
                  sliver: EventList(
                    events: afterEvents,
                    now: now,
                    isLoggedIn: isLoggedIn,
                    onSetFavorite: _handleFavorite,
                    direction: GrowthDirection.forward,
                    pendingUpdates: _pendingUpdates,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class EventList extends StatelessWidget {
  const EventList({
    Key key,
    @required this.events,
    @required this.now,
    @required this.isLoggedIn,
    @required this.onSetFavorite,
    @required this.direction,
    @required this.pendingUpdates,
  }) : assert(events != null),
       assert(now != null),
       assert(isLoggedIn != null),
       assert(onSetFavorite != null),
       assert(direction != null),
       assert(pendingUpdates != null),
       super(key: key);

  final List<Event> events;
  final DateTime now;
  final bool isLoggedIn;
  final FavoriteCallback onSetFavorite;
  final GrowthDirection direction;
  final Map<String, _PendingFavoriteUpdate> pendingUpdates;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          DateTime lastTime;
          if (index > 0)
            lastTime = events[index - 1].startTime;
          final Event event = events[index];
          return TimeSlice(
            event: event,
            now: now,
            isLoggedIn: isLoggedIn,
            direction: direction,
            isLast: index == events.length - 1,
            lastStartTime: lastTime,
            onFavorite: (bool value) { onSetFavorite(event, value); },
            favoriteOverride: pendingUpdates[event.id]?.state,
          );
        },
        childCount: events.length,
      ),
    );
  }
}

class TimeSlice extends StatelessWidget {
  TimeSlice({
    Key key,
    @required this.event,
    @required this.now,
    @required this.isLoggedIn,
    @required this.direction,
    @required this.isLast,
    this.lastStartTime,
    @required this.onFavorite,
    @required this.favoriteOverride,
  }) : assert(event != null),
       assert(now != null),
       assert(isLoggedIn != null),
       assert(direction != null),
       assert(isLast != null),
       assert(onFavorite != null),
       super(key: key ?? Key(event.id));

  final Event event;
  final DateTime now;
  final bool isLoggedIn;
  final GrowthDirection direction;
  final bool isLast;
  final DateTime lastStartTime;
  final ValueSetter<bool> onFavorite;
  final bool favoriteOverride;

  String _getHours(DateTime time) {
    if (time.hour == 12 && time.minute == 00)
      return '12:00nn';
    final String minute = time.minute.toString().padLeft(2, '0');
    final String suffix = time.hour < 12 ? 'am' : 'pm';
    if (time.hour == 00 || time.hour == 12)
      return '12:$minute$suffix';
    return '${(time.hour % 12).toString()}:$minute$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> eventDetails = <Widget>[
      Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(event.location, style: const TextStyle(fontStyle: FontStyle.italic)),
    ];
    if (event.description != null)
      eventDetails.add(Text(event.description));
    final DateTime lastTime = lastStartTime?.toLocal();
    final DateTime lastDay = lastTime != null ? DateTime(lastTime.year, lastTime.month, lastTime.day) : null;
    final DateTime startTime = event.startTime.toLocal();
    final DateTime startDay = DateTime(startTime.year, startTime.month, startTime.day);
    final DateTime endTime = event.endTime.toLocal();
    final bool allDay = endTime.difference(startTime) >= const Duration(days: 1);
    final List<Widget> times = <Widget>[];
    if (allDay) {
      times.add(const Text('all day'));
    } else {
      times
        ..add(Text(_getHours(startTime)))
        ..add(Text('-${_getHours(endTime)}'));
    }
    times.add(const Opacity(opacity: 0.0, child: Text('-88:88pm'))); // forces the column to the right width
    final bool isFavorite = favoriteOverride ?? event.following;
    Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: AlignmentDirectional.topStart,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: times,
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8.0),
            child: ListBody(
              children: eventDetails,
            ),
          ),
        ),
        Semantics(
          checked: isFavorite,
          child: IconButton(
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
            color: favoriteOverride == null ? null : Theme.of(context).accentColor,
            tooltip: isFavorite ? 'Unmark this event.' : 'Mark this event as interesting.',
            onPressed: isLoggedIn ? () {
              onFavorite(!isFavorite);
            } : null,
          ),
        ),
      ],
    );
    if (endTime.isBefore(now)) {
      // finished
      row = Opacity(
        opacity: 0.5,
        child: row,
      );
    } else if (!startTime.isAfter(now)) {
      // active
      row = Container(
        color: Colors.yellow.shade100,
        child: row,
      );
    }
    final List<Widget> children = <Widget>[row];
    DateTime dayAbove, dayBelow;
    switch (direction) {
      case GrowthDirection.forward:
        dayAbove = lastDay;
        dayBelow = startDay;
        if (dayAbove != dayBelow)
          children.insert(0, DayHeaderRow(headerDay: dayBelow));
        break;
      case GrowthDirection.reverse:
        dayAbove = startDay;
        dayBelow = lastDay;
        if (dayAbove != dayBelow && dayBelow != null)
          children.add(DayHeaderRow(headerDay: dayBelow));
        if (isLast)
          children.insert(0, DayHeaderRow(headerDay: dayAbove));
        break;
    }
    if (children.length == 1)
      return children.single;
    return ListBody(children: children);
  }
}

class DayHeaderRow extends StatelessWidget {
  const DayHeaderRow({
    Key key,
    this.headerDay,
  }) : super(key: key);

  final DateTime headerDay;

  @override
  Widget build(BuildContext context) {
    String dayOfWeek;
    switch (headerDay.weekday) {
      case 1: dayOfWeek = 'Monday'; break;
      case 2: dayOfWeek = 'Tuesday'; break;
      case 3: dayOfWeek = 'Wednesday'; break;
      case 4: dayOfWeek = 'Thursday'; break;
      case 5: dayOfWeek = 'Friday'; break;
      case 6: dayOfWeek = 'Saturday'; break;
      case 7: dayOfWeek = 'Sunday'; break;
    }
    String monthName;
    switch (headerDay.month) {
      case 1: monthName = 'January'; break;
      case 2: monthName = 'February'; break;
      case 3: monthName = 'March'; break;
      case 4: monthName = 'April'; break;
      case 5: monthName = 'May'; break;
      case 6: monthName = 'June'; break;
      case 7: monthName = 'July'; break;
      case 8: monthName = 'August'; break;
      case 9: monthName = 'September'; break;
      case 10: monthName = 'October'; break;
      case 11: monthName = 'November'; break;
      case 12: monthName = 'December'; break;
    }
    final int dayNumber = headerDay.day;
    return Material(
      color: Theme.of(context).accentColor,
      textStyle: Theme.of(context).accentTextTheme.subhead,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        child: Text('$dayOfWeek $monthName $dayNumber'),
      ),
    );
  }
}