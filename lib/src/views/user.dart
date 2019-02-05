import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../graphics.dart';
import '../models/announcements.dart';
import '../models/user.dart';
import '../progress.dart';
import '../widgets.dart';
import 'login.dart';

class UserView extends StatefulWidget implements View {
  const UserView({
    Key key,
  }) : super(key: key);

  @override
  Widget buildTabIcon(BuildContext context) {
    return ValueListenableBuilder<ProgressValue<AuthenticatedUser>>(
      valueListenable: Cruise.of(context).user.best,
      builder: (BuildContext context, ProgressValue<AuthenticatedUser> value, Widget child) {
        return Badge(
          enabled: value is FailedProgress,
          child: const Icon(Icons.account_circle),
        );
      },
    );
  }

  @override
  Widget buildTabLabel(BuildContext context) => const Text('Account');

  @override
  Widget buildFab(BuildContext context) {
    return null;
  }

  @override
  _UserViewState createState() => _UserViewState();
}

class _UserViewState extends State<UserView> {
  ContinuousProgress<AuthenticatedUser> _user;
  Progress<AuthenticatedUser> _bestUser;
  ProgressValue<AuthenticatedUser> _bestUserValue;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ContinuousProgress<AuthenticatedUser> oldUser = _user;
    final ContinuousProgress<AuthenticatedUser> newUser = Cruise.of(context).user;
    if (oldUser != newUser) {
      _user?.removeListener(_handleNewUser);
      _user = newUser;
      _user?.addListener(_handleNewUser);
      _handleNewUser();
    }
  }

  void _handleNewUser() {
    final Progress<AuthenticatedUser> oldBestUser = _bestUser;
    final Progress<AuthenticatedUser> newBestUser = _user?.best;
    if (oldBestUser != newBestUser) {
      _bestUser?.removeListener(_handleUserUpdate);
      _bestUser = newBestUser;
      _bestUser?.addListener(_handleUserUpdate);
      _handleUserUpdate();
    }
  }

  void _handleUserUpdate() {
    setState(() {
      _bestUserValue = _bestUser?.value;
    });
  }

  @override
  void dispose() {
    _bestUserValue = null;
    _bestUser?.removeListener(_handleUserUpdate);
    _bestUser = null;
    _user?.removeListener(_handleNewUser);
    _user = null;
    super.dispose();
  }

  static final Key _progressHeader = UniqueKey();
  static final Key _errorHeader = UniqueKey();
  static final Key _userHeader = UniqueKey();
  static final Key _idleHeader = UniqueKey();

  void _login() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => const LoginDialog(),
    );
  }
            
  @override
  Widget build(BuildContext context) {
    final ProgressValue<AuthenticatedUser> _bestUserValue = this._bestUserValue; // https://github.com/dart-lang/sdk/issues/34480
    final TextTheme textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewportConstraints) {
        Widget header;
        bool loggedIn;
        if (_bestUserValue is StartingProgress) {
          header = Center(
            key: _progressHeader,
            child: const CircularProgressIndicator(),
          );
          loggedIn = false;
        } else if (_bestUserValue is ActiveProgress) {
          final ActiveProgress activeProgress = _bestUserValue;
          header = Center(
            key: _progressHeader,
            child: CircularProgressIndicator(value: activeProgress.progress / activeProgress.target),
          );
          loggedIn = false;
        } else if (_bestUserValue is FailedProgress) {
          header = Center(
            key: _errorHeader,
            child: Text('Last error while logging in:\n${wrapError(_bestUserValue.error)}'),
          );
          loggedIn = false;
        } else {
          AuthenticatedUser user;
          if (_bestUserValue is SuccessfulProgress<AuthenticatedUser>)
            user = _bestUserValue.value;
          if (user != null) {
            header = Center(
              key: _userHeader,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: FittedBox(
                        child: Cruise.of(context).avatarFor(user),
                      ),
                    ),
                  ),
                  Text(user.toString(), style: textTheme.display1),
                ],
              ),
            );
            loggedIn = true;
          } else {
            header = Column(
              key: _idleHeader,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 12.0),
                    child: FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20.0),
                        child: SizedBox.fromSize(
                          size: shipSize,
                          child: CustomPaint(
                            painter: ShipPainter(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Text('Welcome to', style: textTheme.headline),
                Text('Cruisemonkey', style: textTheme.headline),
              ],
            );
            loggedIn = false;
          }
        }
        assert(loggedIn != null);

        final List<Widget> tiles = <Widget>[
          DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            child: SizedBox(
              height: viewportConstraints.maxHeight * 0.3,
              child: AnimatedSwitcher(
                duration: animationDuration,
                switchInCurve: animationCurve,
                switchOutCurve: animationCurve,
                child: header,
              ),
            ),
          ),
          const SizedBox(height: 24.0),
          IntrinsicHeight(
            child: AnimatedSwitcher(
              duration: animationDuration,
              switchInCurve: animationCurve,
              switchOutCurve: animationCurve,
              child: Row(
                key: ValueKey<bool>(loggedIn),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: loggedIn ?
                  <Widget>[
                    Expanded(
                      child: Center(
                        child: FlatButton(
                          onPressed: loggedIn ? () { Cruise.of(context).logout(); } : null,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: const <Widget>[
                                Icon(Icons.clear),
                                Text('Log out'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: FlatButton(
                          onPressed: loggedIn ? () { Navigator.pushNamed(context, '/profile'); } : null,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: const <Widget>[
                                Icon(Icons.edit),
                                Text('Edit Profile'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] : <Widget>[
                    Expanded(
                      child: Center(
                        child: FlatButton(
                          onPressed: loggedIn ? null : _login,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: const <Widget>[
                                Icon(Icons.person),
                                Text('Log in'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: FlatButton(
                          onPressed: loggedIn ? null : () { Navigator.pushNamed(context, '/create_account'); },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: const <Widget>[
                                Icon(Icons.person_add),
                                Text('Create Account'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
              ),
            ),
          ),
          Divider(),
          ContinuousProgressBuilder<List<Announcement>>(
            progress: Cruise.of(context).announcements,
            nullChild: const SizedBox.shrink(),
            idleChild: const SizedBox.shrink(),
            builder: (BuildContext context, List<Announcement> announcements) {
              if (announcements.isEmpty)
                return const Text('Enjoy the cruise!', textAlign: TextAlign.center);
              return ListBody(
                children: announcements.map<Widget>((Announcement announcement) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: ChatLine(
                      user: announcement.user,
                      messages: <String>[ announcement.message ],
                      timestamp: announcement.timestamp,
                    ),
                  );
                }).toList(),
              );
            },
          ),
          Divider(),
          Center(
            child: FlatButton(
              child: const Text('ABOUT'),
              onPressed: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'CruiseMonkey',
                  applicationVersion: 'JoCo 2019',
                  children: <Widget>[
                    const Text('A project of the Seamonkey Social group.'),
                  ],
                );
              },
            ),
          ),
        ];
/*        

        assert(() {
          // Settings screen only shows up in debug builds,
          // because it's really just debug settings.
          tiles.add(ValueListenableBuilder<bool>(
            valueListenable: Cruise.of(context).restoringSettings,
            builder: (BuildContext context, bool busy, Widget child) {
              return ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                enabled: !busy,
                onTap: busy ? null : () {
                  Navigator.pushNamed(context, '/settings');
                },
              );
            },
          ));
          return true;
        }());

        tiles.add(const AboutListTile(
        ));
        assert(_bestUserValue == this._bestUserValue); // https://github.com/dart-lang/sdk/issues/34480
*/
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: viewportConstraints.maxHeight,
            ),
            child: SafeArea(
              child: IntrinsicHeight(
                child: Column(
                  children: tiles,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ShipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    assert(size == shipSize);
    final Path path = ship();
    final Paint paint = Paint()
      ..color = Colors.grey[300];
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ShipPainter oldPainter) => false;
}