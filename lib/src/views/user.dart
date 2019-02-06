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
          header = Column(
            key: _progressHeader,
            children: const <Widget>[
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              Text('Logging in...\n'),
            ],
          );
          loggedIn = false;
        } else if (_bestUserValue is ActiveProgress) {
          final ActiveProgress activeProgress = _bestUserValue;
          header = Column(
            key: _progressHeader,
            children: <Widget>[
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(value: activeProgress.progress / activeProgress.target),
                ),
              ),
              const Text('Logging in...\n'),
            ],
          );
          loggedIn = false;
        } else if (_bestUserValue is FailedProgress) {
          header = Align(
            key: _errorHeader,
            alignment: Alignment.bottomCenter,
            child: Text('Last error while logging in:\n${wrapError(_bestUserValue.error)}'),
          );
          loggedIn = false;
        } else {
          AuthenticatedUser user;
          if (_bestUserValue is SuccessfulProgress<AuthenticatedUser>)
            user = _bestUserValue.value;
          if (user != null) {
            header = Column(
              key: _userHeader,
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
            );
            loggedIn = true;
          } else {
            header = Column(
              key: _idleHeader,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
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
              child: Stack(
                children: <Widget>[
                  const Positioned(
                    top: 40.0,
                    left: 40.0,
                    right: 40.0,
                    bottom: 0,
                    child: Ship(
                      alignment: Alignment.topCenter,
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: animationDuration,
                      switchInCurve: animationCurve,
                      switchOutCurve: animationCurve,
                      child: header,
                    ),
                  ),
                ],
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
                      child: LabeledIconButton(
                        onPressed: loggedIn ? () { Cruise.of(context).logout(); } : null,
                        icon: const Icon(Icons.clear),
                        label: const Text('LOG OUT'),
                      ),
                    ),
                    Expanded(
                      child: LabeledIconButton(
                        onPressed: loggedIn ? () { Navigator.pushNamed(context, '/profile'); } : null,
                        icon: const Icon(Icons.edit),
                        label: const Text('EDIT PROFILE'),
                      ),
                    ),
                  ] : <Widget>[
                    Expanded(
                      child: LabeledIconButton(
                        onPressed: loggedIn ? null : _login,
                        icon: const Icon(Icons.person),
                        label: const Text('LOG IN'),
                      ),
                    ),
                    Expanded(
                      child: LabeledIconButton(
                        onPressed: loggedIn ? null : () { Navigator.pushNamed(context, '/create_account'); },
                        icon: const Icon(Icons.person_add),
                        label: const Text('CREATE ACCOUNT'),
                      ),
                    ),
                  ],
              ),
            ),
          ),
          const Divider(),
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
          const Divider(),
          IntrinsicHeight(
            child: Row(
              key: ValueKey<bool>(loggedIn),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Expanded(
                  child: LabeledIconButton(
                    icon: const Icon(Icons.help_outline),
                    label: const Text('ABOUT CRUISEMONKEY'),
                    onPressed: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Cruise Monkey',
                        applicationVersion: 'JoCo 2019',
                        applicationIcon: Image.asset('images/cruise_monkey.png', width: 96.0),
                        children: <Widget>[
                          const Text('A project of the Seamonkey Social group.'),
                          // TODO(ianh): include a link to https://github.com/seamonkeysocial/
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: LabeledIconButton(
                    icon: const Icon(Icons.gavel),
                    label: const Text('CODE OF CONDUCT'),
                    onPressed: () {
                      Navigator.pushNamed(context, '/code-of-conduct');
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48.0),
          ValueListenableBuilder<bool>(
            valueListenable: Cruise.of(context).restoringSettings,
            builder: (BuildContext context, bool busy, Widget child) {
              return LabeledIconButton(
                icon: const Icon(Icons.settings),
                label: const Text('SETTINGS'),
                onPressed: busy ? null : () {
                  Navigator.pushNamed(context, '/settings');
                },
              );
            },
          ),
        ];

        assert(_bestUserValue == this._bestUserValue); // https://github.com/dart-lang/sdk/issues/34480

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
