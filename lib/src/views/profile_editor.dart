import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user.dart';
import '../network/twitarr.dart';

import '../progress.dart';
import '../widgets.dart';

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    Key key,
  }) : super(key: key);

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final FocusNode _displayNameFocus = FocusNode();
  final FocusNode _realNameFocus = FocusNode();
  final FocusNode _pronounsFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _roomNumberFocus = FocusNode();
  final FocusNode _homeLocationFocus = FocusNode();

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
                title: Text('Edit Profile (@${user.username})'),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 26.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      AvatarEditor(user: user),
                      ProfileField(
                        title: 'Display name',
                        autofocus: true,
                        focusNode: _displayNameFocus,
                        nextNode: _realNameFocus,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 40,
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
                        focusNode: _realNameFocus,
                        nextNode: _pronounsFocus,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 100,
                        value: user.realName,
                        onUpdate: (String value) {
                          return Cruise.of(context).updateProfile(
                            realName: value,
                          );
                        },
                      ),
                      ProfileField(
                        title: 'Pronouns',
                        focusNode: _pronounsFocus,
                        nextNode: _roomNumberFocus,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 100,
                        value: user.pronouns,
                        onUpdate: (String value) {
                          return Cruise.of(context).updateProfile(
                            pronouns: value,
                          );
                        },
                      ),
                      ProfileField(
                        title: 'Room number',
                        focusNode: _roomNumberFocus,
                        nextNode: _homeLocationFocus,
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        value: user.roomNumber,
                        onUpdate: (String value) {
                          if (!AuthenticatedUser.isValidRoomNumber(value))
                            throw const LocalError('Room number must be between 1000 and 99999 and must be numeric.');
                          return Cruise.of(context).updateProfile(
                            roomNumber: value,
                          );
                        },
                      ),
                      ProfileField(
                        title: 'Home location',
                        focusNode: _homeLocationFocus,
                        nextNode: _emailFocus,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 100,
                        value: user.homeLocation,
                        onUpdate: (String value) {
                          return Cruise.of(context).updateProfile(
                            homeLocation: value,
                          );
                        },
                      ),
                      ProfileField(
                        title: 'E-mail address',
                        focusNode: _emailFocus,
                        nextNode: _displayNameFocus,
                        keyboardType: TextInputType.emailAddress,
                        value: user.email,
                        onUpdate: (String value) {
                          if (!AuthenticatedUser.isValidEmail(value))
                            throw const LocalError('E-mail is not valid.');
                          return Cruise.of(context).updateProfile(
                            email: value,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AvatarEditor extends StatefulWidget {
  const AvatarEditor({
    Key key,
    this.user,
  }) : super(key: key);

  final AuthenticatedUser user;

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> with AutomaticKeepAliveClientMixin<AvatarEditor> {
  bool _busy = false;
  String _error = '';

  @override
  bool get wantKeepAlive => _busy || _error != '';

  void _updateImage(ImageSource source) async {
    assert(!_busy);
    try {
      setState(() { _busy = true; _error = ''; });
      final File file = await ImagePicker.pickImage(source: source);
      if (file != null) {
        final Uint8List bytes = await file.readAsBytes() as Uint8List;
        try {
          await Cruise.of(context).uploadAvatar(image: bytes).asFuture();
        } on UserFriendlyError catch (error) {
          if (mounted)
            setState(() { _error = error.toString(); });
        }
      }
    } finally {
      if (mounted)
        setState(() { _busy = false; });
    }
  }

  void _deleteImage() async {
    assert(!_busy);
    try {
      setState(() { _busy = true; _error = ''; });
      try {
        await Cruise.of(context).uploadAvatar().asFuture();
      } on UserFriendlyError catch (error) {
        if (mounted)
          setState(() { _error = error.toString(); });
      }
    } finally {
      if (mounted)
        setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ThemeData themeData = Theme.of(context);
    return Column(
      children: <Widget>[
        Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Center(
                child: SizedBox(
                  height: 160.0,
                  width: 160.0,
                  child: Cruise.of(context).avatarFor(<User>[widget.user], size: 160.0),
                ),
              ),
            ),
            PositionedDirectional(
              end: 0.0,
              bottom: 0.0,
              child: Column(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.camera_alt),
                    tooltip: 'Take photograph to use as new avatar.',
                    onPressed: _busy ? null : () { _updateImage(ImageSource.camera); },
                  ),
                  IconButton(
                    icon: const Icon(Icons.image),
                    tooltip: 'Select new image for avatar from gallery.',
                    onPressed: _busy ? null : () { _updateImage(ImageSource.gallery); },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Revert to the default image.',
                    onPressed: _busy ? null : _deleteImage,
                  ),
                ],
              ),
            ),
            Visibility(
              visible: _busy,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
        Text(_error, style: themeData.textTheme.subhead.copyWith(color: themeData.errorColor), textAlign: TextAlign.center),
      ],
    );
  }
}

typedef ProgressValueSetter<T> = Progress<void> Function(T value);

class ProfileField extends StatefulWidget {
  const ProfileField({
    Key key,
    this.title,
    this.autofocus = false,
    this.focusNode,
    this.nextNode,
    this.value,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.maxLength,
    @required this.onUpdate,
  }) : assert(onUpdate != null),
       assert(autofocus != null),
       super(key: key);

  final String title;

  final bool autofocus;

  final FocusNode focusNode;

  final FocusNode nextNode;

  final String value;

  final TextCapitalization textCapitalization;

  final TextInputType keyboardType;

  final int maxLength;

  final ProgressValueSetter<String> onUpdate;

  @override
  State<ProfileField> createState() => _ProfileFieldState();
}

class _ProfileFieldState extends State<ProfileField> with AutomaticKeepAliveClientMixin<ProfileField>, TickerProviderStateMixin {
  final TextEditingController _field = TextEditingController();

  String _error;

  bool _updating = false;
  Progress<void> _progress; // TODO(ianh): use this in the build method for the progress meter

  bool _saved = false;

  @override
  bool get wantKeepAlive => _updating || _error != null;

  void _update() async {
    setState(() { _updating = true; _saved = false; });
    try {
      _error = null;
      _progress = widget.onUpdate(_field.text);
      await _progress.asFuture();
      if (mounted)
        setState(() { _saved = true; });
    } on UserFriendlyError catch (message) {
      if (mounted)
        setState(() { _error = message.toString(); });
    }
    if (mounted)
      setState(() { _updating = false; });
  }

  @override
  void initState() {
    super.initState();
    _field.text = widget.value;
    widget.focusNode.addListener(_focusChange);
  }

  @override
  void didUpdateWidget(ProfileField oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.focusNode.removeListener(_focusChange);
    widget.focusNode.addListener(_focusChange);
    if (oldWidget.value != widget.value && !widget.focusNode.hasFocus && !_updating)
      _field.text = widget.value;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusChange);
    super.dispose();
  }

  void _focusChange() {
    setState(() { _saved = false; });
    if (!widget.focusNode.hasFocus)
      _update();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Stack(
        children: <Widget>[
          TextField(
            controller: _field,
            focusNode: widget.focusNode,
            onSubmitted: (String value) {
              if (widget.nextNode != null)
                FocusScope.of(context).requestFocus(widget.nextNode);
            },
            onChanged: (String value) {
              setState(() { _saved = false; });
            },
            textInputAction: widget.nextNode != null ? TextInputAction.next : TextInputAction.done,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            maxLength: widget.maxLength,
            enabled: !_updating,
            decoration: InputDecoration(
              labelText: widget.title,
              errorText: _error,
              errorMaxLines: 5,
              suffixIcon: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                curve: Curves.fastOutSlowIn,
                opacity: _saved ? 1.0 : 0.0,
                child: const Tooltip(
                  message: 'Saved automatically.',
                  child: Icon(Icons.check),
                ),
              ),
            ),
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
