import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../progress.dart';
import '../widgets.dart';

class Profile extends StatefulWidget {
  const Profile({
    Key key,
    @required this.user,
  }) : assert(user != null),
       super(key: key);

  final User user;

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  Progress<User> _user;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  void _start() {
    _user = Cruise.of(context).fetchProfile(widget.user.username);
  }

  static bool _missing(String value) => value == null || value == '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user}'),
      ),
      body: ProgressBuilder<User>(
        progress: _user,
        onRetry: () {
          setState(_start);
        },
        builder: (BuildContext context, User user) {
          final TextStyle italic = DefaultTextStyle.of(context).style.copyWith(fontStyle: FontStyle.italic);
          final Widget none = Text('none', style: italic);
          final Widget notSpecified = Text('not specified', style: italic);
          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return Cruise.of(context).avatarFor(<User>[user], size: math.min(256.0, constraints.maxWidth), enabled: false);
                },
              ),
              const SizedBox(height: 24.0),
              Table(
                columnWidths: const <int, TableColumnWidth>{
                  0: IntrinsicColumnWidth(flex: 1.0),
                  1: FixedColumnWidth(24.0),
                },
                children: <TableRow>[
                  TableRow(
                    children: <Widget>[
                      const Text('Username: ', textAlign: TextAlign.end),
                      const SizedBox(width: 24.0, height: 24.0),
                      Text(user.username),
                    ],
                  ),
                  TableRow(
                    children: <Widget>[
                      const Text('Display name: ', textAlign: TextAlign.end),
                      const SizedBox(width: 24.0, height: 24.0),
                      user.displayName == user.username ? none : Text(user.displayName),
                    ],
                  ),
                  TableRow(
                    children: <Widget>[
                      const Text('Real name: ', textAlign: TextAlign.end),
                      const SizedBox(width: 24.0, height: 24.0),
                      _missing(user.realName) ? none : Text(user.realName),
                    ],
                  ),
                  TableRow(
                    children: <Widget>[
                      const Text('Pronouns: ', textAlign: TextAlign.end),
                      const SizedBox(width: 24.0, height: 24.0),
                      _missing(user.pronouns) ? notSpecified : Text(user.pronouns),
                    ],
                  ),
                  TableRow(
                    children: <Widget>[
                      const Text('Room number: ', textAlign: TextAlign.end),
                      const SizedBox(width: 24.0, height: 24.0),
                      _missing(user.roomNumber) ? notSpecified : Text(user.roomNumber),
                    ],
                  ),
                  TableRow(
                    children: <Widget>[
                      const Text('Home location: ', textAlign: TextAlign.end),
                      const SizedBox(width: 24.0, height: 24.0),
                      _missing(user.homeLocation) ? notSpecified : Text(user.homeLocation),
                    ],
                  ),
                  TableRow(
                    children: <Widget>[
                      const Text('E-mail: ', textAlign: TextAlign.end),
                      const SizedBox(width: 24.0, height: 24.0),
                      _missing(user.email) ? notSpecified : Text(user.email),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
