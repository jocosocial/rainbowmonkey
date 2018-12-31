import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/logic/cruise.dart';
import 'src/logic/disk_store.dart';
import 'src/models/user.dart';
import 'src/network/rest.dart';
import 'src/progress.dart';
import 'src/views/calendar.dart';
import 'src/views/deck_plans.dart';
import 'src/views/drawer.dart';
import 'src/views/karaoke.dart';
import 'src/views/profile.dart';
import 'src/views/seamail.dart';
import 'src/views/settings.dart';
import 'src/widgets.dart';

void main() {
  runApp(new CruiseMonkeyApp(
    cruiseModel: new CruiseModel(
      twitarrConfiguration: const RestTwitarrConfiguration(baseUrl: 'http://69.62.137.54:42111/'),
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

  static const List<View> pages = <View>[
    const CalendarView(),
    const DeckPlanView(),
    const KaraokeView(),
    const SeamailView(),
  ];

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
        length: 4,
        child: new Builder(
          builder: (BuildContext context) {
            final TabController tabController = DefaultTabController.of(context);
            return new AnimatedBuilder(
              animation: tabController,
              builder: (BuildContext context, Widget child) {
                return new Scaffold(
                  appBar: new AppBar(
                    leading: ValueListenableBuilder<ProgressValue<AuthenticatedUser>>(
                      valueListenable: Cruise.of(context).user.best,
                      builder: (BuildContext context, ProgressValue<AuthenticatedUser> value, Widget child) {
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
                    bottom: new TabBar(
                      isScrollable: true,
                      tabs: pages.map((View page) => page.buildTab(context)).toList(),
                    ),
                  ),
                  drawer: const CruiseMonkeyDrawer(),
                  floatingActionButton: pages[tabController.index].buildFab(context),
                  body: const TabBarView(
                    children: pages,
                  ),
                );
              },
            );
          },
        ),
      ),
      routes: <String, WidgetBuilder>{
        '/profile': (BuildContext context) => const Profile(),
        '/settings': (BuildContext context) => const Settings(),
      },
    );
  }
}
