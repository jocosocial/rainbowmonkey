import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../network/twitarr.dart';

import '../progress.dart';
import '../widgets.dart';

class Profile extends StatelessWidget {
  const Profile({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ContinuousProgress<AuthenticatedUser> userSource = Cruise.of(context).user;
    return Scaffold(
      body: AnimatedBuilder(
        animation: userSource,
        builder: (BuildContext context, Widget child) {
          final AuthenticatedUser user = userSource.currentValue;
          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                title: new Text('Edit Profile (@${user.username})'),
              ),
              SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Stack(
                        children: <Widget>[
                          Center(
                            child: SizedBox(
                              height: 120.0,
                              width: 120.0,
                              child: Cruise.of(context).avatarFor(user),
                            ),
                          ),
                          PositionedDirectional(
                            end: 0.0,
                            bottom: 0.0,
                            child: IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Select new image for avatar.',
                              onPressed: () {
                                // TODO(ianh): allow image to be changed.
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    ProfileField(
                      title: 'Display name',
                      value: user.displayName,
                      onUpdate: (String value) {
                        if (!AuthenticatedUser.isValidDisplayName(value))
                          throw const LocalError('Your display name must be at least three characters long but shorter than 40 characters, and may only consist of letters and some minimal punctuation.');
                        return Cruise.of(context).updateProfile(
                          displayName: value,
                        );
                      },
                    ),
                    ProfileField(
                      title: 'Real name',
                      value: user.realName,
                      onUpdate: (String value) {
                        return Cruise.of(context).updateProfile(
                          realName: value,
                        );
                      },
                    ),
                    ProfileField(
                      title: 'E-mail address',
                      value: user.email,
                      onUpdate: (String value) {
                        if (!AuthenticatedUser.isValidEmail(value))
                          throw const LocalError('E-mail is not valid.');
                        return Cruise.of(context).updateProfile(
                          email: value,
                        );
                      },
                    ),
                    ProfileField(
                      title: 'Current location',
                      value: user.currentLocation,
                      onUpdate: (String value) {
                        return Cruise.of(context).updateProfile(
                          currentLocation: value,
                        );
                      },
                    ),
                    ProfileField(
                      title: 'Room number',
                      value: user.roomNumber,
                      onUpdate: (String value) {
                        if (!AuthenticatedUser.isValidRoomNumber(value))
                          throw const LocalError('Room number must be numeric.');
                        return Cruise.of(context).updateProfile(
                          roomNumber: value,
                        );
                      },
                    ),
                    ProfileField(
                      title: 'Home location',
                      value: user.homeLocation,
                      onUpdate: (String value) {
                        return Cruise.of(context).updateProfile(
                          homeLocation: value,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

typedef ProgressValueSetter<T> = Progress<void> Function(T value);

class ProfileField extends StatefulWidget {
  const ProfileField({
    Key key,
    this.title,
    this.value,
    @required this.onUpdate,
  }) : assert(onUpdate != null),
       super(key: key);

  final String title;

  final String value;

  final ProgressValueSetter<String> onUpdate;

  @override
  State<ProfileField> createState() => _ProfileFieldState();
}

class _ProfileFieldState extends State<ProfileField> {
  final TextEditingController _field = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _error;

  bool _updating = false;
  Progress<void> _progress;

  void _update(String value) async {
    setState(() { _updating = true; });
    try {
      _error = null;
      _progress = widget.onUpdate(value);
      await _progress.asFuture();
    } on UserFriendlyError catch (message) {
      setState(() { _error = message.toString(); });
    }
    setState(() { _updating = false; });
  }

  @override
  void initState() {
    super.initState();
    _field.text = widget.value;
  }

  @override
  void didUpdateWidget(ProfileField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus && !_updating)
      _field.text = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Stack(
        children: <Widget>[
          TextField(
            controller: _field,
            focusNode: _focusNode,
            enabled: !_updating,
            decoration: InputDecoration(
              labelText: widget.title,
              errorText: _error,
              errorMaxLines: 5,
            ),
            onSubmitted: _update,
          ),
          Visibility(
            visible: _updating,
            child: const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
