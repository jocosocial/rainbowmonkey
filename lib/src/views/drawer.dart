import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../progress.dart';
import '../widgets.dart';
import 'create_account.dart';
import 'login.dart';

class CruiseMonkeyDrawer extends StatefulWidget {
  const CruiseMonkeyDrawer({
    Key key,
  }) : super(key: key);

  @override
  State<CruiseMonkeyDrawer> createState() => new _CruiseMonkeyDrawerState();
}

class _CruiseMonkeyDrawerState extends State<CruiseMonkeyDrawer> {
  ContinuousProgress<User> _user;
  Progress<User> _bestUser;
  ProgressValue<User> _bestUserValue;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ContinuousProgress<User> oldUser = _user;
    final ContinuousProgress<User> newUser = Cruise.of(context).user;
    if (oldUser != newUser) {
      _user?.removeListener(_handleNewUser);
      _user = newUser;
      _user?.addListener(_handleNewUser);
      _handleNewUser();
    }
  }

  void _handleNewUser() {
    final Progress<User> oldBestUser = _bestUser;
    final Progress<User> newBestUser = _user?.best;
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

  static final Key _progressHeader = new UniqueKey();
  static final Key _errorHeader = new UniqueKey();
  static final Key _userHeader = new UniqueKey();
  static final Key _idleHeader = new UniqueKey();

  @override
  Widget build(BuildContext context) {
    final ProgressValue<User> _bestUserValue = this._bestUserValue; // https://github.com/dart-lang/sdk/issues/34480

    Widget header;
    bool loggedIn;
    if (_bestUserValue is StartingProgress) {
      header = new DrawerHeader(
        key: _progressHeader,
        child: const Center(
          child: const CircularProgressIndicator(),
        ),
      );
      loggedIn = false;
    } else if (_bestUserValue is ActiveProgress) {
      final ActiveProgress activeProgress = _bestUserValue;
      header = new DrawerHeader(
        key: _progressHeader,
        child: new Center(
          child: new CircularProgressIndicator(value: activeProgress.progress / activeProgress.target),
        ),
      );
      loggedIn = false;
    } else if (_bestUserValue is FailedProgress) {
      header = new DrawerHeader(
        key: _errorHeader,
        child: new Align(
          alignment: Alignment.bottomCenter,
          child: new Text('Last error: ${_bestUserValue.error}'),
        ),
      );
      loggedIn = false;
    } else {
      User user;
      if (_bestUserValue is SuccessfulProgress<User>)
        user = _bestUserValue.value;
      if (user != null) {
        header = new UserAccountsDrawerHeader(
          key: _userHeader,
          accountName: new Text(user.username ?? '<unknown username>'),
          accountEmail: new Text(user.email ?? ''),
        );
        loggedIn = true;
      } else {
        header = new DrawerHeader(
          key: _idleHeader,
          child: const Align(
            alignment: Alignment.bottomCenter,
            child: const Text('Not logged in'),
          ),
        );
        loggedIn = false;
      }
    }
    assert(loggedIn != null);

    final List<Widget> tiles = <Widget>[];
    tiles.add(new AnimatedSwitcher(
      child: header,
      duration: animationDuration,
      switchInCurve: animationCurve,
      switchOutCurve: animationCurve,
    ));

    tiles.add(AnimatedCrossFade(
      duration: animationDuration,
      firstCurve: animationCurve,
      secondCurve: animationCurve,
      firstChild: const SizedBox.shrink(),
      secondChild: new ListTile(
        leading: const Icon(Icons.person_add),
        title: const Text('Create account'),
        onTap: loggedIn ? null : () {
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) => const CreateAccountDialog(),
          );
        },
      ),
      crossFadeState: loggedIn ? CrossFadeState.showFirst : CrossFadeState.showSecond,
    ));
    tiles.add(AnimatedCrossFade(
      duration: animationDuration,
      firstCurve: animationCurve,
      secondCurve: animationCurve,
      firstChild: const SizedBox.shrink(),
      secondChild: new ListTile(
        leading: const Icon(Icons.account_circle),
        title: const Text('Log in'),
        onTap: loggedIn ? null : () {
          showDialog<void>(
            context: context,
            builder: (BuildContext context) => const LoginDialog(),
          );
        }
      ),
      crossFadeState: loggedIn ? CrossFadeState.showFirst : CrossFadeState.showSecond,
    ));

    tiles.add(AnimatedCrossFade(
      duration: animationDuration,
      firstCurve: animationCurve,
      secondCurve: animationCurve,
      firstChild: new ListTile(
        leading: const Icon(Icons.clear),
        title: const Text('Log out'),
        onTap: loggedIn ? () { Cruise.of(context).logout(); } : null,
      ),
      secondChild: const SizedBox.shrink(),
      crossFadeState: loggedIn ? CrossFadeState.showFirst : CrossFadeState.showSecond,
    ));

    tiles.add(const Divider());
    tiles.add(ListTile(
      leading: const Icon(Icons.settings),
      title: const Text('Settings'),
      onTap: () {
        Navigator.pop(context); // drawer
        Navigator.pushNamed(context, '/settings');
      },
    ));
    tiles.add(const AboutListTile(
      aboutBoxChildren: const <Widget>[
        const Text('A project of the Seamonkey Social group.'),
      ],
    ));
    assert(_bestUserValue == this._bestUserValue); // https://github.com/dart-lang/sdk/issues/34480
    return new Drawer(
      child: new ListView(
        children: tiles,
      ),
    );
  }
}
