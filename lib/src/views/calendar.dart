import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dynamic.dart';
import '../models/calendar.dart';
import '../network/network.dart';

class CalendarView extends DynamicView<Calendar> {
  const CalendarView({
    Key key,
    @required Twitarr twitarr,
  }) : super(key: key, twitarr: twitarr);

  @override
  _CalendarViewState createState() => new _CalendarViewState();
}

class _CalendarViewState extends DynamicViewState<Calendar, CalendarView> {
  @override
  ValueListenable<Calendar> getDataSource(Twitarr twitarr) => twitarr.calendar;

  @override
  Widget buildView(BuildContext context, Calendar data) {
    return new ListView.builder(
      itemBuilder: (BuildContext context, int index) {
        DateTime lastTime;
        if (index > 0)
          lastTime = data.events[index - 1].startTime;
        return new TimeSlice(
          event: data.events[index],
          lastStartTime: lastTime,
          favorited: false,
          onFavorite: (bool newValue) { /* TODO */ },
        );
      },
      itemCount: data.events.length,
    );
  }
}

class TimeSlice extends StatelessWidget {
  TimeSlice({
    Key key,
    @required this.event,
    this.lastStartTime,
    @required this.favorited,
    @required this.onFavorite,
  }) : assert(event != null),
       assert(favorited != null),
       assert(onFavorite != null),
       super(key: key ?? new Key(event.id));

  final Event event;
  final DateTime lastStartTime;
  final bool favorited;
  final ValueSetter<bool> onFavorite;

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
      new Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      new Text(event.location, style: const TextStyle(fontStyle: FontStyle.italic)),
    ];
    if (event.description != null) {
      eventDetails.add(new Text(event.description));
    }
    final DateTime lastTime = lastStartTime?.toLocal();
    final DateTime lastDay = lastTime != null ? new DateTime(lastTime.year, lastTime.month, lastTime.day) : null;
    final DateTime startTime = event.startTime.toLocal();
    final DateTime startDay = new DateTime(startTime.year, startTime.month, startTime.day);
    final DateTime endTime = event.endTime.toLocal();
    final bool allDay = endTime.difference(startTime) >= const Duration(days: 1);
    final List<Widget> times = <Widget>[];
    if (allDay) {
      times.add(const Text('all day'));
    } else {
      times
        ..add(new Text(_getHours(startTime)))
        ..add(new Text('-${_getHours(endTime)}'));
    }
    times.add(const Opacity(opacity: 0.0, child: const Text('-88:88pm')));
    final Widget day = new Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        new Container(
          padding: const EdgeInsets.all(8.0),
          alignment: AlignmentDirectional.topStart,
          child: new Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: times,
          ),
        ),
        new Expanded(
          child: new Container(
            padding: const EdgeInsets.all(8.0),
            child: new ListBody(
              children: eventDetails,
            ),
          ),
        ),
        new Semantics(
          checked: favorited,
          child: new IconButton(
            icon: new Icon(favorited ? Icons.favorite : Icons.favorite_border),
            tooltip: 'Mark this event as interesting.',
            onPressed: () {
              onFavorite(!favorited);
            },
          ),
        ),
      ],
    );
    if (startDay != lastDay) {
      String dayOfWeek;
      switch (startDay.weekday) {
        case 1: dayOfWeek = 'Monday'; break;
        case 2: dayOfWeek = 'Tuesday'; break;
        case 3: dayOfWeek = 'Wednesday'; break;
        case 4: dayOfWeek = 'Thursday'; break;
        case 5: dayOfWeek = 'Friday'; break;
        case 6: dayOfWeek = 'Saturday'; break;
        case 7: dayOfWeek = 'Sunday'; break;
      }
      String monthName;
      switch (startDay.month) {
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
      final int dayNumber = startDay.day;
      return new ListBody(
        children: <Widget>[
          new Material(
            color: Theme.of(context).accentColor,
            textStyle: Theme.of(context).accentTextTheme.subhead,
            child: new Container(
              padding: const EdgeInsets.all(12.0),
              child: new Text('$dayOfWeek $monthName $dayNumber'),
            ),
          ),
          day,
        ],
      );
    }
    return day;
  }
}
