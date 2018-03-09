import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/logic/cruise.dart';
import 'src/logic/disk_store.dart';
import 'src/models/user.dart';
import 'src/progress.dart';
import 'src/views/calendar.dart';
import 'src/views/deck_plans.dart';
import 'src/views/drawer.dart';
import 'src/views/karaoke.dart';
import 'src/widgets.dart';

void main() {
  runApp(new CruiseMonkeyApp(
    cruiseModel: new CruiseModel(
      store: new DiskDataStore(),
    ),
  ));
}

class CruiseMonkeyApp extends StatelessWidget {
  const CruiseMonkeyApp({
    Key key,
    this.cruiseModel,
  }) : super(key: key);

  final CruiseModel cruiseModel;

  @override
  Widget build(BuildContext context) {
    return new Cruise(
      cruiseModel: cruiseModel,
      child: const CruiseMonkeyHome(),
    );
  }
}

class CruiseMonkeyHome extends StatelessWidget {
  const CruiseMonkeyHome({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'CruiseMonkey',
      theme: new ThemeData(
        primarySwatch: Colors.teal,
        accentColor: Colors.greenAccent,
        inputDecorationTheme: const InputDecorationTheme(
          border: const OutlineInputBorder(),
        ),
      ),
      home: new DefaultTabController(
        length: 3,
        child: new Scaffold(
          appBar: new AppBar(
            leading: ValueListenableBuilder<ProgressValue<User>>(
              valueListenable: Cruise.of(context).user.best,
              builder: (BuildContext context, ProgressValue<User> value, Widget child) {
                return new Badge(
                  enabled: value is FailedProgress,
                  child: new Builder(
                    builder: (BuildContext context) {
                      return new IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () { Scaffold.of(context).openDrawer(); },
                        tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                      );
                    },
                  ),
                );
              },
            ),
            title: const Text('CruiseMonkey'),
            bottom: const TabBar(
              tabs: const <Widget>[
                const Tab(
                  text: 'Calendar',
                  icon: const Icon(Icons.event),
                ),
                const Tab(
                  text: 'Deck Plans',
                  icon: const Icon(Icons.directions_boat),
                ),
                const Tab(
                  text: 'Karaoke Song List',
                  icon: const Icon(Icons.library_music),
                ),
              ],
            ),
          ),
          drawer: const CruiseMonkeyDrawer(),
          body: const TabBarView(
            children: const <Widget>[
              const CalendarView(),
              const DeckPlanView(),
              const KaraokeView(),
            ],
          ),
        ),
      ),
    );
  }
}
