import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'network.dart';

void main() {
  runApp(new CruiseMonkey(
    // TODO(ianh): replace with configurable option
    twitarr: new RestTwitarr(baseUrl: 'http://drang.prosedev.com:3000/'),
  ));
}

class CruiseMonkey extends StatefulWidget {
  const CruiseMonkey({
    Key key,
    @required this.twitarr,
  }) : assert(twitarr != null),
       super(key: key);

  final Twitarr twitarr;

  @override
  _CruiseMonkeyState createState() => new _CruiseMonkeyState();
}

class _CruiseMonkeyState extends State<CruiseMonkey> {
  User _currentUser;

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'CruiseMonkey',
      theme: new ThemeData(
        primarySwatch: Colors.teal,
        accentColor: Colors.greenAccent,
      ),
      home: new DefaultTabController(
        length: 2,
        child: new Scaffold(
          appBar: new AppBar(
            title: const Text('CruiseMonkey'),
            bottom: new TabBar(
              tabs: <Widget>[
                new Tab(
                  text: 'Calendar',
                  icon: new Icon(Icons.event),
                ),
                new Tab(
                  text: 'Deck Plans',
                  icon: new Icon(Icons.directions_boat),
                ),
              ],
            ),
          ),
          drawer: new CruiseMonkeyDrawer(currentUser: _currentUser),
          body: new TabBarView(
            children: <Widget>[
              new CalendarView(twitarr: widget.twitarr),
              const InformationView(),
            ],
          ),
        ),
      ),
    );
  }
}

class CruiseMonkeyDrawer extends StatelessWidget {
  const CruiseMonkeyDrawer({
    Key key,
    this.currentUser,
  }) : super(key: key);

  final User currentUser;

  @override
  Widget build(BuildContext context) {
    return new Drawer(
      child: new ListView(
        children: <Widget>[
          new UserAccountsDrawerHeader(
            accountName: new Text(currentUser?.name ?? 'Not logged in'),
            accountEmail: new Text(currentUser?.email ?? ''),
          ),
          const AboutListTile(
            aboutBoxChildren: const <Widget>[
              const Text('A project of the Seamonkey Social group.'),
            ],
          ),
        ],
      ),
    );
  }
}

abstract class DynamicView<T> extends StatefulWidget {
  const DynamicView({
    Key key,
    @required this.twitarr,
  }) : assert(twitarr != null),
       super(key: key);

  final Twitarr twitarr;
}

abstract class DynamicViewState<T, W extends DynamicView<T>> extends State<W> {
  T _data;

  ValueListenable<T> getDataSource(Twitarr twitarr);
  Widget buildView(BuildContext context, T data);

  @override
  void initState() {
    super.initState();
    final ValueListenable<T> source = getDataSource(widget.twitarr)
      ..addListener(_updateData);
    _data = source.value;
  }

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.twitarr != oldWidget.twitarr) {
      getDataSource(oldWidget.twitarr).removeListener(_updateData);
      getDataSource(widget.twitarr).addListener(_updateData);
    }
  }

  @override
  void dispose() {
    getDataSource(widget.twitarr).removeListener(_updateData);
    super.dispose();
  }

  void _updateData() {
    setState(() {
      _data = getDataSource(widget.twitarr).value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return new AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      firstChild: const Center(
        child: const CircularProgressIndicator(),
      ),
      secondChild: _data == null ? new Container() : buildView(context, _data),
      crossFadeState: _data == null ? CrossFadeState.showFirst : CrossFadeState.showSecond,
    );
  }
}

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

class InformationView extends StatefulWidget {
  const InformationView({
    Key key,
  }) : super(key: key);

  @override
  _InformationViewState createState() => new _InformationViewState();
}

class _InformationViewState extends State<InformationView> with SingleTickerProviderStateMixin {
  static const int kMinDeck = 1;
  static const int kMaxDeck = 10;

  AnimationController _currentLevel;
  List<Widget> _decks, _buttons;

  @override
  void initState() {
    super.initState();
    _currentLevel = new AnimationController(
      value: kMinDeck.toDouble(),
      lowerBound: kMinDeck.toDouble(),
      upperBound: kMaxDeck.toDouble(),
      vsync: this,
    );
    _decks = new List<Widget>.generate(kMaxDeck - kMinDeck + 1,
      (int index) => new Deck(
        level: index + kMinDeck,
        opacity: new _DeckAnimation(_currentLevel, (index + kMinDeck).toDouble()),
      ),
      growable: false,
    );
    _buttons = new List<Widget>.generate(kMaxDeck - kMinDeck + 1,
      (int index) => new Expanded(
        child: new AspectRatio(
          aspectRatio: 1.0,
          child: new InkResponse(
            onTap: () {
              _goToDeck(index + kMinDeck);
            },
            child: new FractionallySizedBox(
              widthFactor: 0.75,
              heightFactor: 0.75,
              child: new FittedBox(
                fit: BoxFit.contain,
                child: new Text('${index + kMinDeck}'),
              ),
            ),
          ),
        ),
      ),
      growable: false,
    );
  }

  @override
  void dispose() {
    _currentLevel.dispose();
    super.dispose();
  }

  void _goToDeck(int target) {
    _currentLevel.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeIn,
    );
  }

  double _scale = 2.0;
  double _dynamicScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return new Row(
      children: <Widget>[
        new Expanded(
          child: new GestureDetector(
            onScaleUpdate: (ScaleUpdateDetails details) {
              setState(() { _dynamicScale = details.scale; });
            },
            onScaleEnd: (ScaleEndDetails details) {
              setState(() { _scale = math.max(1.0, _scale * _dynamicScale); _dynamicScale = 1.0; });
            },
            child: new LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return new SingleChildScrollView(
                  child: new ConstrainedBox(
                    constraints: new BoxConstraints(
                      minWidth: 0.0,
                      maxWidth: constraints.maxWidth,
                      minHeight: constraints.maxHeight,
                      maxHeight: constraints.maxHeight * math.max(1.0, _scale * _dynamicScale),
                    ),
                    child: new Stack(
                      alignment: Alignment.center,
                      children: _decks,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        new CustomPaint(
          painter: new Elevator(
            min: kMinDeck.toDouble(),
            max: kMaxDeck.toDouble(),
            level: _currentLevel,
            color: Theme.of(context).accentColor,
          ),
          child: new DefaultTextStyle(
            style: Theme.of(context).textTheme.button,
            child: new GestureDetector(
              onVerticalDragStart: (DragStartDetails details) {
                _currentLevel.stop();
              },
              onVerticalDragUpdate: (DragUpdateDetails details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                _currentLevel.value -= (details.primaryDelta / box.size.height) * (kMaxDeck - kMinDeck + 1);
              },
              onVerticalDragEnd: (DragEndDetails details) {
                if (details.primaryVelocity > 0.0) {
                  _goToDeck(_currentLevel.value.floor());
                } else if (details.primaryVelocity < 0.0) {
                  _goToDeck(_currentLevel.value.ceil());
                } else {
                  _goToDeck(_currentLevel.value.round());
                }
              },
              child: new Column(
                verticalDirection: VerticalDirection.up,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: _buttons,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class Elevator extends CustomPainter {
  Elevator({
    @required this.min,
    @required this.max,
    @required this.level,
    @required this.color,
  }) : assert(min != null),
       assert(max != null),
       assert(level != null),
       assert(color != null),
       super(repaint: level);

  final double min;
  final double max;
  final ValueListenable<double> level;
  final Color color;

  static const double inset = 0.1;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = new Paint()
      ..color = Colors.black
      ..strokeWidth = size.width * inset
      ..style = PaintingStyle.stroke;
    final Rect rect = new Rect.fromLTWH(
      size.width * inset,
      size.width * inset + (size.height - size.width) * (1.0 - (level.value - min) / (max - min)),
      size.width * (1 - inset * 2.0),
      size.width * (1 - inset * 2.0),
    );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(Elevator oldDelegate) {
    return level != oldDelegate.level
        || color != color;
  }
}

class Deck extends StatelessWidget {
  const Deck({
    Key key,
    @required this.level,
    @required this.opacity,
  }) : assert(level != null),
       assert(opacity != null),
       super(key: key);

  final int level;

  final Animation<double> opacity;

  @override
  Widget build(BuildContext context) {
    return new FadeTransition(
      opacity: opacity,
      child: new Padding(
        padding: const EdgeInsets.all(8.0),
        child: new Image.asset('images/deck_$level.png'),
      ),
    );
  }
}

class _DeckAnimation extends Animation<double> with AnimationWithParentMixin<double> {
  _DeckAnimation(this.parent, this.deck);

  @override
  final Animation<double> parent;

  final double deck;

  @override
  double get value {
    if (parent.value == deck)
      return 1.0;
    if (parent.value < deck - 1.0 ||
        parent.value > deck + 1.0)
      return 0.0;
    return 1.0 - (parent.value - deck).abs();
  }
}