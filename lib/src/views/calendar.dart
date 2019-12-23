import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/calendar.dart';
import '../models/server_status.dart';
import '../widgets.dart';

final ValueNotifier<bool> _filter = ValueNotifier<bool>(false);

class CalendarView extends StatefulWidget implements View {
  const CalendarView({
    @required PageStorageKey<UniqueObject> key,
  }) : super(key: key);

  @override
  bool isEnabled(ServerStatus status) => status.calendarEnabled;

  @override
  Widget buildTabIcon(BuildContext context) => const Icon(Icons.event);

  @override
  Widget buildTabLabel(BuildContext context) => const Text('Calendar');

  @override
  Widget buildFab(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _filter,
      builder: (BuildContext context, bool value, Widget child) {
        return FloatingActionButton(
          child: Icon(value ? Icons.favorite : Icons.favorite_border),
          onPressed: () async {
            _filter.value = !value;
          },
        );
      },
    );
  }

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

typedef FavoriteCallback = void Function(Event event, bool favorite);

class _PendingFavoriteUpdate {
  _PendingFavoriteUpdate();
  bool state;
}

class _CalendarViewState extends State<CalendarView> with SingleTickerProviderStateMixin {
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
    // TODO(ianh): show event overlaps somehow
    return ContinuousProgressBuilder<Calendar>(
      progress: Cruise.of(context).calendar,
      onRetry: () { Cruise.of(context).forceUpdate(); },
      idleChild: Center(
        child: FlatButton(
          child: const Text('LOAD CALENDAR'),
          onPressed: () {
            Cruise.of(context).forceUpdate();
          },
        ),
      ),
      builder: (BuildContext context, Calendar calendar) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return ValueListenableBuilder<bool>(
              valueListenable: _filter,
              builder: (BuildContext context, bool filtered, Widget child) {
                List<Event> filteredEvents = calendar.events;
                Widget excuse;
                if (filteredEvents.isEmpty) {
                  excuse = iconAndLabel(icon: Icons.sentiment_neutral, message: 'Calendar is empty');
                } else if (filtered) {
                  filteredEvents = filteredEvents.where((Event event) => _pendingUpdates.containsKey(event.id) || event.following).toList();
                  if (filteredEvents.isEmpty)
                    excuse = iconAndLabel(icon: Icons.sentiment_neutral, message: 'You have not marked any events');
                }
                final DateTime now = Now.of(context);
                final bool isLoggedIn = Cruise.of(context).isLoggedIn;
                final List<Event> beforeEvents = filteredEvents.where((Event event) => !event.endTime.isAfter(now)).toList().reversed.toList();
                final List<Event> afterEvents = filteredEvents.where((Event event) => event.endTime.isAfter(now)).toList();
                return _CalendarViewInternals(
                  excuse: excuse,
                  isLoggedIn: isLoggedIn,
                  beforeEvents: beforeEvents,
                  afterEvents: afterEvents,
                  constraints: constraints,
                  pendingUpdates: _pendingUpdates,
                  onFavorite: _handleFavorite,
                  now: now,
                  filtered: filtered,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CalendarViewInternals extends StatefulWidget {
  const _CalendarViewInternals({
    @required this.excuse,
    @required this.isLoggedIn,
    @required this.beforeEvents,
    @required this.afterEvents,
    @required this.constraints,
    @required this.pendingUpdates,
    @required this.onFavorite,
    @required this.now,
    @required this.filtered,
  });

  final Widget excuse;
  final bool isLoggedIn;
  final List<Event> beforeEvents;
  final List<Event> afterEvents;
  final BoxConstraints constraints;
  final Map<String, _PendingFavoriteUpdate> pendingUpdates;
  final FavoriteCallback onFavorite;
  final DateTime now;
  final bool filtered;

  @override
  State<_CalendarViewInternals> createState() => _CalendarViewInternalsState();
}

class _CalendarViewInternalsState extends State<_CalendarViewInternals> {
  static final Key _beforeKey = UniqueKey();
  static final Key _afterKey = UniqueKey();

  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _filter.addListener(_recenter);
  }

  void _recenter() {
    _controller.animateTo(0.0, duration: const Duration(milliseconds: 350), curve: Curves.fastOutSlowIn);
  }

  @override
  void dispose() {
    _filter.removeListener(_recenter);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[
      CustomScrollView(
        controller: _controller,
        center: _afterKey,
        anchor: MediaQuery.of(context).padding.top / widget.constraints.maxHeight,
        slivers: <Widget>[
          SliverSafeArea(
            key: _beforeKey,
            bottom: false,
            sliver: EventList(
              events: widget.beforeEvents,
              fallback: widget.excuse == null ? iconAndLabel(icon: Icons.sentiment_satisfied, message: widget.filtered ? 'No earlier marked events' : 'The cruise has not yet begun') : null,
              now: widget.now,
              isLoggedIn: widget.isLoggedIn,
              onSetFavorite: widget.onFavorite,
              direction: GrowthDirection.reverse,
              pendingUpdates: widget.pendingUpdates,
            ),
          ),
          SliverSafeArea(
            key: _afterKey,
            top: false,
            sliver: EventList(
              events: widget.afterEvents,
              fallback: widget.excuse == null ? iconAndLabel(icon: Icons.sentiment_dissatisfied, message: widget.filtered ? 'No more marked events' : 'The cruise is over until next year') : null,
              now: widget.now,
              isLoggedIn: widget.isLoggedIn,
              onSetFavorite: widget.onFavorite,
              direction: GrowthDirection.forward,
              pendingUpdates: widget.pendingUpdates,
            ),
          ),
        ],
      ),
      AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget child) {
          final double position = _controller.position.pixels;
          final EdgeInsets padding = MediaQuery.of(context).padding;
          final bool showIt = position < -widget.constraints.maxHeight || position > widget.constraints.maxHeight / 3.0;
          return PositionedDirectional(
            end: 24.0,
            top: position > 0.0 ? padding.top + 16.0 : null,
            bottom: position < 0.0 ? padding.bottom + 48.0 : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              curve: Curves.fastOutSlowIn,
              opacity: showIt ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !showIt,
                child: RaisedButton(
                  shape: const StadiumBorder(),
                  child: Text('${ (position < 0.0) ? "▼" : "▲" } Jump to now'),
                  onPressed: _recenter,
                ),
              ),
            ),
          );
        },
      ),
    ];
    if (widget.excuse != null)
      children.add(widget.excuse);
    return Stack(
      alignment: Alignment.center,
      children: children,
    );
  }
}


class EventList extends StatelessWidget {
  const EventList({
    Key key,
    @required this.events,
    @required this.fallback,
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
  final Widget fallback;
  final DateTime now;
  final bool isLoggedIn;
  final FavoriteCallback onSetFavorite;
  final GrowthDirection direction;
  final Map<String, _PendingFavoriteUpdate> pendingUpdates;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty && fallback != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: fallback,
        ),
      );
    }
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
            isFavorite: pendingUpdates[event.id]?.state ?? event.following,
            favoriteOverride: pendingUpdates.containsKey(event.id),
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
    @required this.isFavorite,
    @required this.favoriteOverride,
  }) : assert(event != null),
       assert(now != null),
       assert(isLoggedIn != null),
       assert(direction != null),
       assert(isLast != null),
       assert(onFavorite != null),
       assert(isFavorite != null),
       assert(favoriteOverride != null),
       super(key: key ?? Key(event.id));

  final Event event;
  final DateTime now;
  final bool isLoggedIn;
  final GrowthDirection direction;
  final bool isLast;
  final DateTime lastStartTime;
  final ValueSetter<bool> onFavorite;
  final bool isFavorite;
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
            color: favoriteOverride ? Theme.of(context).accentColor : null,
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