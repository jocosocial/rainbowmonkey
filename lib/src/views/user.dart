import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../graphics.dart';
import '../models/server_status.dart';
import '../models/string.dart';
import '../models/user.dart';
import '../progress.dart';
import '../widgets.dart';
import 'clock.dart';
import 'login.dart';

class UserView extends StatefulWidget implements View {
  const UserView({
    @required PageStorageKey<UniqueObject> key,
  }) : super(key: key);

  @override
  bool isEnabled(ServerStatus status) => true;

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
    final ContinuousProgress<ServerStatus> serverStatusProgress = Cruise.of(context).serverStatus;
    final ProgressValue<AuthenticatedUser> _bestUserValue = this._bestUserValue; // https://github.com/dart-lang/sdk/issues/34480
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: serverStatusProgress.best,
      builder: (BuildContext context, Widget child) {
        final ServerStatus status = serverStatusProgress.currentValue ?? const ServerStatus();
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    iconAndLabel(icon: Icons.warning, message: 'Could not log in:\n${wrapError(_bestUserValue.error)}'),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FlatButton(
                        child: const Text('RETRY'),
                        onPressed: () {
                          Cruise.of(context).retryUserLogin();
                        },
                      ),
                    ),
                  ],
                ),
              );
              loggedIn = false;
            } else {
              AuthenticatedUser user;
              if (_bestUserValue is SuccessfulProgress<AuthenticatedUser>)
                user = _bestUserValue.value;
              if (user != null) {
                final List<Widget> children = <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: FittedBox(
                        child: Cruise.of(context).avatarFor(<User>[user]),
                      ),
                    ),
                  ),
                  Text(user.toString(), style: textTheme.headline4),
                ];
                switch (user.role) {
                  case Role.admin:
                    children.add(Text('ADMINISTRATOR', style: textTheme.caption));
                    break;
                  case Role.tho:
                    children.add(Text('THO', style: textTheme.caption));
                    break;
                  case Role.moderator:
                    children.add(Text('MODERATOR', style: textTheme.caption));
                    break;
                  case Role.user:
                    break;
                  case Role.muted:
                    children.add(Text('ACCOUNT MUTED', style: textTheme.caption));
                    break;
                  case Role.banned:
                    children.add(Text('ACCOUNT BANNED', style: textTheme.caption));
                    break;
                  case Role.none:
                    break;
                }
                header = Column(
                  key: _userHeader,
                  children: children,
                );
                loggedIn = true;
              } else {
                header = Column(
                  key: _idleHeader,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text('Welcome to', style: textTheme.headline5),
                    Text('Rainbow Monkey', style: textTheme.headline5),
                  ],
                );
                loggedIn = false;
              }
            }
            assert(loggedIn != null);

            final List<Widget> accountButtons = <Widget>[];
            if (loggedIn) {
              accountButtons.add(Expanded(
                child: LabeledIconButton(
                  onPressed: loggedIn ? () { Cruise.of(context).logout(); } : null,
                  icon: const Icon(Icons.clear),
                  label: const Text('LOG OUT'),
                ),
              ));
              if (status.userProfileEnabled) {
                accountButtons.add(Expanded(
                  child: LabeledIconButton(
                    onPressed: loggedIn ? () { Navigator.pushNamed(context, '/profile-editor'); } : null,
                    icon: const Icon(Icons.edit),
                    label: const Text('EDIT PROFILE'),
                  ),
                ));
              }
            } else {
              accountButtons.add(Expanded(
                child: LabeledIconButton(
                  onPressed: loggedIn ? null : _login,
                  icon: const Icon(Icons.person),
                  label: const Text('LOG IN'),
                ),
              ));
              if (status.registrationEnabled) {
                accountButtons.add(Expanded(
                  child: LabeledIconButton(
                    onPressed: loggedIn ? null : () { Navigator.pushNamed(context, '/create-account'); },
                    icon: const Icon(Icons.person_add),
                    label: const Text('CREATE ACCOUNT'),
                  ),
                ));
              }
            }

            final List<Widget> tiles = <Widget>[
              DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                child: SizedBox(
                  height: math.max(viewportConstraints.maxHeight * 0.3, textTheme.headline4.fontSize * 4 + textTheme.headline5.fontSize * 2),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: AnimatedSwitcher(
                            duration: animationDuration,
                            switchInCurve: animationCurve,
                            switchOutCurve: animationCurve,
                            child: header,
                          ),
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
                    children: accountButtons,
                  ),
                ),
              ),
              const SizedBox(height: 8.0),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
                child: ContinuousProgressBuilder<ServerStatus>(
                  progress: Cruise.of(context).serverStatus,
                  onRetry: () { Cruise.of(context).forceUpdate(); },
                  failureMessage: const Padding(
                    padding: EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
                    child: Text(
                      'If you are unable to connect to the Twitarr server, consider turning on Airplane mode and then turning on WiFi. '
                      'Twitarr is only available on the ship network.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  nullChild: const Text('Delight in the cruise!', textAlign: TextAlign.center),
                  idleChild: const Text('Please enjoy the cruise!', textAlign: TextAlign.center),
                  builder: (BuildContext context, ServerStatus status) {
                    final List<Announcement> announcements = status.announcements;
                    if (announcements.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(0.0, 10.0, 0.0, 10.0),
                        child: Text('Enjoy the cruise!', textAlign: TextAlign.center),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(0.0, 4.0, 0.0, 0.0),
                      child: ListBody(
                        children: announcements.map<Widget>((Announcement announcement) {
                          return ChatLine(
                            user: announcement.user,
                            messages: <TwitarrString>[ announcement.message ],
                            timestamp: announcement.timestamp,
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              const SizedBox(height: 8.0),
              IntrinsicHeight(
                child: Row(
                  key: ValueKey<bool>(loggedIn),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    Expanded(
                      child: ValueListenableBuilder<bool>(
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
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    Expanded(
                      child: LabeledIconButton(
                        icon: const Icon(Icons.schedule),
                        label: const Text('CHECK TIME ZONE AND CLOCK'),
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (BuildContext context) => const CheckClockDialog(),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: LabeledIconButton(
                        icon: const Icon(Icons.help_outline),
                        label: const Text('ABOUT RAINBOW MONKEY'),
                        onPressed: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'Rainbow Monkey',
                            applicationVersion: 'v2.0 (JoCo 2020)',
                            applicationIcon: Image.asset('images/cruise_monkey.png', width: 96.0),
                            children: <Widget>[
                            const Text('A project of the Seamonkey Social group.'),
                              GestureDetector(
                                onTap: () {
                                  launch('http://seamonkeysocial.cruises/');
                                },
                                child: Text(
                                  'http://seamonkeysocial.cruises/',
                                  style: Theme.of(context).textTheme.bodyText2.copyWith(
                                    decoration: TextDecoration.underline,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ];

            assert(_bestUserValue == this._bestUserValue); // https://github.com/dart-lang/sdk/issues/34480

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewportConstraints.maxHeight,
                ),
                child: SafeArea(
                  child: ListBody(
                    children: tiles,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
