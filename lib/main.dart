import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting show ImageCache;
import 'package:flutter/painting.dart' hide ImageCache;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'src/graphics.dart';
import 'src/image_cache.dart' as cruise_monkey;
import 'src/logic/background_polling.dart';
import 'src/logic/cruise.dart';
import 'src/logic/disk_store.dart';
import 'src/logic/notifications.dart';
import 'src/logic/store.dart';
import 'src/models/errors.dart';
import 'src/models/server_status.dart';
import 'src/models/user.dart';
import 'src/network/rest.dart';
import 'src/views/calendar.dart';
import 'src/views/code_of_conduct.dart';
import 'src/views/comms.dart';
import 'src/views/create_account.dart';
import 'src/views/deck_plans.dart';
import 'src/views/games.dart';
import 'src/views/karaoke.dart';
import 'src/views/mentions.dart';
import 'src/views/profile.dart';
import 'src/views/profile_editor.dart';
import 'src/views/search.dart';
import 'src/views/settings.dart';
import 'src/views/stream.dart';
import 'src/views/user.dart';
import 'src/widgets.dart';

class CruiseMonkeyBinding extends BindingBase with GestureBinding, ServicesBinding, SchedulerBinding, PaintingBinding, SemanticsBinding, RendererBinding, WidgetsBinding {
  @override
  painting.ImageCache createImageCache() => cruise_monkey.ImageCache();
}

final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
CruiseModel model;

void main() {
  WidgetsFlutterBinding();
  assert(() {
    print('Rainbow Monkey has started');
    return true;
  }());
  AutoTwitarrConfiguration.register();
  RestTwitarrConfiguration.register();
  final DataStore store = DiskDataStore();
  model = CruiseModel(
    initialTwitarrConfiguration: const AutoTwitarrConfiguration(),
    store: store,
    onError: _handleError,
    onCheckForMessages: checkForMessages,
  );
  runApp(LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      // if (constraints.maxWidth == 0)
      //   return const SizedBox.shrink();
      return CruiseMonkeyApp(cruiseModel: model, store: store, scaffoldKey: scaffoldKey);
    },
  ));
  if (Platform.isAndroid)
    runBackground(store);
  Notifications.instance.then((Notifications notifications) {
    notifications.onTap = (String payload) {
      assert(() {
        print('Main thread handled user tapping notification with payload "$payload".');
        return true;
      }());
      showThread(payload);
    };
  });
  final ReceivePort port = ReceivePort()
    ..forEach((dynamic event) {
      if (event is String)
        showThread(event);
    });
  IsolateNameServer.registerPortWithName(port.sendPort, 'main');
}

void showThread(String threadId) async {
  assert(() {
    print('Received tap to view: $threadId');
    return true;
  }());
  await model.loggedIn;
  Navigator.popUntil(scaffoldKey.currentContext, ModalRoute.withName('/'));
  PrivateCommsView.showSeamailThread(scaffoldKey.currentContext, model.seamail.threadById(threadId));
}

void _handleError(UserFriendlyError error) {
  final String message = '$error';
  final AnimationController controller = AnimationController(
    duration: const Duration(seconds: 4),
    vsync: const PermanentTickerProvider(),
  );
  final Animation<double> opacity = controller.drive(TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.ease)),
        weight: 500,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(1.0),
        weight: 2500,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.ease)),
        weight: 2000,
      ),
    ],
  ));
  final Animation<double> position = controller.drive(
    Tween<double>(begin: 228.0, end: 136.0).chain(CurveTween(curve: Curves.easeOutBack)),
  );
  final OverlayEntry entry = OverlayEntry(
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return Positioned(
        left: 24.0,
        right: 24.0,
        bottom: position.value,
        child: IgnorePointer(
          child: FadeTransition(
            opacity: opacity,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: ShapeDecoration(
                color: Colors.grey[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                shadows: kElevationToShadow[4],
              ),
              child: Text(message, style: theme.textTheme.caption.copyWith(color: Colors.white)),
            ),
          ),
        ),
      );
    },
  );
  final OverlayState overlay = Overlay.of(scaffoldKey.currentContext);
  controller.addListener(() {
    if (overlay.mounted)
      entry.markNeedsBuild();
  });
  controller.addStatusListener((AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (overlay.mounted)
        entry.remove();
      controller.dispose();
    }
  });
  overlay.insert(entry);
  controller.forward();
}

class PermanentTickerProvider extends TickerProvider {
  const PermanentTickerProvider();

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

class CruiseMonkeyApp extends StatelessWidget {
  const CruiseMonkeyApp({
    Key key,
    this.cruiseModel,
    this.store,
    this.scaffoldKey,
  }) : super(key: key);

  final CruiseModel cruiseModel;

  final DataStore store;

  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return Cruise(
      cruiseModel: cruiseModel,
      child: Now(
        period: const Duration(seconds: 15),
        child: CruiseMonkeyHome(scaffoldKey: scaffoldKey, store: store),
      ),
    );
  }
}

class CruiseMonkeyHome extends StatelessWidget {
  const CruiseMonkeyHome({
    Key key,
    this.scaffoldKey,
    this.store,
  }) : super(key: key);

  final GlobalKey<ScaffoldState> scaffoldKey;

  final DataStore store;

  static final List<View> allPages = <View>[
    UserView(key: PageStorageKey<UniqueObject>(UniqueObject())),
    CalendarView(key: PageStorageKey<UniqueObject>(UniqueObject())),
    PrivateCommsView(key: PageStorageKey<UniqueObject>(UniqueObject())),
    PublicCommsView(key: PageStorageKey<UniqueObject>(UniqueObject())),
    DeckPlanView(key: PageStorageKey<UniqueObject>(UniqueObject())),
    gamesView,
    karaokeView,
    searchView,
  ];

  Widget buildTab(BuildContext context, View page, { EdgeInsets iconPadding = EdgeInsets.zero }) {
    return Tab(
      icon: Padding(padding: iconPadding, child: page.buildTabIcon(context)),
      text: (page.buildTabLabel(context) as Text).data,
    );
  }

  @protected
  ThemeData makeTheme(Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      primarySwatch: Colors.blue,
      primaryColor: Colors.blue[900],
      accentColor: Colors.cyanAccent,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: OpenUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ServerStatusBuilder(
      builder: (BuildContext context, ServerStatus status, Widget child) {
        final List<View> pages = allPages.where((View view) => view.isEnabled(status)).toList();
        return MaterialApp(
          title: 'Rainbow Monkey',
          theme: makeTheme(Brightness.light),
          darkTheme: makeTheme(Brightness.dark),
          home: DefaultTabController(
            key: ValueKey<int>(pages.length),
            length: pages.length,
            child: Builder(
              builder: (BuildContext context) {
                final TabController tabController = DefaultTabController.of(context);
                final ThemeData theme = Theme.of(context);
                return AnimatedBuilder(
                  animation: tabController,
                  builder: (BuildContext context, Widget child) {
                    final Widget fab = pages[tabController.index].buildFab(context);
                    return Scaffold(
                      key: scaffoldKey,
                      floatingActionButton: fab == null ? null : KeyedSubtree(
                        key: ObjectKey(pages[tabController.index]),
                        child: fab,
                      ),
                      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
                      resizeToAvoidBottomInset: false,
                      body: AnnotatedRegion<SystemUiOverlayStyle>(
                        value: SystemUiOverlayStyle.dark,
                        child: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints constraints) {
                            const double bottomPadding = 50.0;
                            final double height = constraints.maxHeight + bottomPadding;
                            final MediaQueryData metrics = MediaQuery.of(context);
                            return OverflowBox(
                              minWidth: constraints.maxWidth,
                              maxWidth: constraints.maxWidth,
                              minHeight: height,
                              maxHeight: height,
                              alignment: Alignment.topCenter,
                              child: MediaQuery(
                                data: metrics.copyWith(padding: metrics.padding.copyWith(bottom: bottomPadding)),
                                child: AnimatedBuilder(
                                  animation: tabController,
                                  builder: (BuildContext context, Widget child) {
                                    return AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      switchInCurve: Curves.fastOutSlowIn,
                                      switchOutCurve: Curves.fastOutSlowIn,
                                      child: pages[tabController.index],
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomNavigationBar: BottomAppBar(
                        color: theme.primaryColor,
                        shape: const WaveShape(),
                        elevation: 4.0, // TODO(ianh): figure out why this has no effect
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Center(
                            heightFactor: 1.0,
                            child: TabBar(
                              key: ValueKey<int>(pages.length),
                              isScrollable: true,
                              indicator: BoxDecoration(
                                color: const Color(0x10FFFFFF),
                                border: Border(
                                  top: BorderSide(
                                    color: theme.accentColor,
                                    width: 10.0,
                                  ),
                                ),
                              ),
                              tabs: pages.map<Widget>((View page) => buildTab(context, page, iconPadding: const EdgeInsets.only(top: 8.0))).toList(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          routes: <String, WidgetBuilder>{
            '/profile-editor': (BuildContext context) => const ProfileEditor(),
            '/create-account': (BuildContext context) => const CreateAccount(),
            '/settings': (BuildContext context) => Settings(store: store),
            '/code-of-conduct': (BuildContext context) => const CodeOfConduct(),
            '/twitarr': (BuildContext context) => const TweetStreamView(),
            '/mentions': (BuildContext context) => const MentionsView(),
            '/profile': (BuildContext context) => Profile(user: ModalRoute.of(context).settings.arguments as User),
          },
        );
      },
    );
  }
}
