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
                    ProfileField(
                      title: 'Current location',
                      value: user.currentLocation,
                      onUpdate: (String value) {
                        return Cruise.of(context).updateProfile(
                          currentLocation: value,
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
  void didUpdateWidget(ProfileField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus && !_updating)
      _field.text = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        height: 96.0,
        child: new Align(
          alignment: AlignmentDirectional.topStart,
          child: TextField(
            controller: _field,
            focusNode: _focusNode,
            enabled: !_updating,
            decoration: InputDecoration(
              labelText: widget.title,
              errorText: _error,
              suffix: _updating ? const CircularProgressIndicator() : null,
            ),
            onSubmitted: _update,
          ),
        ),
      ),
    );
  }
}
