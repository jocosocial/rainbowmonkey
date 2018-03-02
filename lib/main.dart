import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/models/user.dart';
import 'src/network/network.dart';
import 'src/views/calendar.dart';
import 'src/views/deck_plans.dart';
import 'src/views/karaoke.dart';

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
        length: 3,
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
                new Tab(
                  text: 'Karaoke Song List',
                  icon: new Icon(Icons.library_music),
                ),
              ],
            ),
          ),
          drawer: new CruiseMonkeyDrawer(currentUser: _currentUser),
          body: new TabBarView(
            children: <Widget>[
              new CalendarView(twitarr: widget.twitarr),
              const DeckPlanView(),
              const KaraokeView(),
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
