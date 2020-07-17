import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/errors.dart';
import '../models/user.dart';

import '../progress.dart';
import '../widgets.dart';

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    Key key,
  }) : super(key: key);

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

abstract class _PendingTasks {
  void cancel();
}

class _Pending {
  _Pending(this.setState);

  final StateSetter setState;

  final Set<_PendingTasks> _tasks = <_PendingTasks>{};

  void add(_PendingTasks object) {
    setState(() {
      _tasks.add(object);
    });
  }

  void remove(_PendingTasks object) {
    setState(() {
      _tasks.remove(object);
    });
  }

  void cancelAll() {
    setState(() {
      for (_PendingTasks task in _tasks)
        task.cancel();
      _tasks.clear();
    });
  }

  bool get isEmpty => _tasks.isEmpty;

  bool get isNotEmpty => _tasks.isNotEmpty;
}

class _ProfileEditorState extends State<ProfileEditor> {
  final FocusNode _displayNameFocus = FocusNode();
  final FocusNode _realNameFocus = FocusNode();
  final FocusNode _pronounsFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _roomNumberFocus = FocusNode();
  final FocusNode _homeLocationFocus = FocusNode();

  _Pending _pending;

  @override
  void initState() {
    super.initState();
    _pending = _Pending(setState);
  }

  @override
  Widget build(BuildContext context) {
    final ContinuousProgress<AuthenticatedUser> userSource = Cruise.of(context).user;
    return Scaffold(
      body: AnimatedBuilder(
        animation: userSource,
        builder: (BuildContext context, Widget child) {
          final AuthenticatedUser user = userSource.currentValue;
            final List<Widget> children = <Widget>[
            AvatarEditor(
              user: user,
              pending: _pending,
            ),
            ProfileField(
              title: 'Display name',
              autofocus: true,
              focusNode: _displayNameFocus,
              nextNode: _realNameFocus,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              value: user.displayName,
              pending: _pending,
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
              pending: _pending,
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
              pending: _pending,
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
              pending: _pending,
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
              pending: _pending,
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
              pending: _pending,
              onUpdate: (String value) {
                if (!AuthenticatedUser.isValidEmail(value))
                  throw const LocalError('E-mail is not valid.');
                return Cruise.of(context).updateProfile(
                  email: value,
                );
              },
            ),
            const SizedBox(height: 24.0),
            LabeledIconButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (BuildContext context) => ChangePasswordDialog(password: user.credentials.password),
                );
              },
              icon: const Icon(Icons.vpn_key),
              label: const Text('CHANGE PASSWORD'),
            ),
          ];
          final FocusScopeNode focus = FocusScope.of(context);
          final bool noFieldHasFocus = focus.focusedChild == null || !focus.focusedChild.hasPrimaryFocus;
          return StatusBarBackground(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  floating: true,
                  title: Text('Edit Profile (@${user.username})'),
                  leading: IconButton(
                    icon: noFieldHasFocus ? const BackButtonIcon() : const Icon(Icons.done),
                    tooltip: noFieldHasFocus ? 'Back' : 'Save changes',
                    onPressed: noFieldHasFocus ? _pending.isNotEmpty ? null : () {
                      Navigator.maybePop(context);
                    } : () {
                      // TODO(ianh): remove setState once https://github.com/flutter/flutter/issues/43497 is fixed
                      setState(() { focus.focusedChild.unfocus(); });
                    }
                  ),
                  actions: <Widget>[
                    if (_pending.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.cancel),
                        tooltip: 'Cancel current edit',
                        onPressed: () {
                          _pending.cancelAll();
                        },
                      ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 26.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      children,
                    ),
                  ),
                ),
              ],
            ),
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
    this.pending,
  }) : super(key: key);

  final AuthenticatedUser user;

  final _Pending pending;

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> with AutomaticKeepAliveClientMixin<AvatarEditor> implements _PendingTasks {
  bool _busy = false;
  String _error = '';

  @override
  bool get wantKeepAlive => _busy || _error != '';

  @override
  void cancel() {
    setState(() { _busy = false; });
    Scaffold.of(context).showSnackBar(const SnackBar(content: Text('Avatar may have changed on the server already.')));
  }

  void _saveImage(ImageSource source) async {
    assert(!_busy);
    try {
      setState(() { _busy = true; _error = ''; });
      widget.pending?.add(this);
      final File file = await ImagePicker.pickImage(source: source);
      if (file != null) {
        final Uint8List bytes = await file.readAsBytes();
        try {
          await Cruise.of(context).uploadAvatar(image: bytes).asFuture();
        } on UserFriendlyError catch (error) {
          if (mounted)
            setState(() { _error = error.toString(); });
        }
      }
    } finally {
      if (mounted) {
        setState(() { _busy = false; });
        widget.pending?.remove(this);
      }
    }
  }

  void _deleteImage() async {
    assert(!_busy);
    try {
      setState(() { _busy = true; _error = ''; });
      widget.pending?.add(this);
      try {
        await Cruise.of(context).uploadAvatar().asFuture();
      } on UserFriendlyError catch (error) {
        if (mounted)
          setState(() { _error = error.toString(); });
      }
    } finally {
      if (mounted) {
        setState(() { _busy = false; });
        widget.pending?.remove(this);
      }
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
                    onPressed: _busy ? null : () { _saveImage(ImageSource.camera); },
                  ),
                  IconButton(
                    icon: const Icon(Icons.image),
                    tooltip: 'Select new image for avatar from gallery.',
                    onPressed: _busy ? null : () { _saveImage(ImageSource.gallery); },
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
        Text(_error, style: themeData.textTheme.subtitle1.copyWith(color: themeData.errorColor), textAlign: TextAlign.center),
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
    this.pending,
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

  final _Pending pending;

  final ProgressValueSetter<String> onUpdate;

  @override
  State<ProfileField> createState() => _ProfileFieldState();
}

class _ProfileFieldState extends State<ProfileField> with AutomaticKeepAliveClientMixin<ProfileField>, TickerProviderStateMixin implements _PendingTasks {
  final TextEditingController _field = TextEditingController();
  String _probableServerContents;
  String _currentlyUploadingValue;

  String _error;

  Progress<void> _progress; // TODO(ianh): use this in the build method for the progress meter

  bool _saved = false;

  bool get _updating => _currentlyUploadingValue != null;

  @override
  bool get wantKeepAlive => _updating || _error != null;

  @override
  void cancel() {
    if (_updating)
      Scaffold.of(context).showSnackBar(SnackBar(content: Text('${widget.title} may have changed on the server already.')));
    _field.text = _probableServerContents;
    setState(() { _currentlyUploadingValue = null; _saved = false; _error = null; });
  }

  void _save() async {
    if (_field.text == _currentlyUploadingValue)
      return;
    final String ourValue = _currentlyUploadingValue = _field.text;
    widget.pending?.add(this); // may be redundant
    setState(() { _saved = false; _error = null; });
    try {
      _progress = widget.onUpdate(ourValue);
      await _progress.asFuture();
      if (mounted && ourValue == _currentlyUploadingValue) {
        _probableServerContents = _field.text;
        setState(() { _saved = true; });
      }
    } on UserFriendlyError catch (message) {
      if (mounted && ourValue == _currentlyUploadingValue)
        setState(() { _error = message.toString(); });
    }
    if (mounted && ourValue == _currentlyUploadingValue) {
      setState(() { _currentlyUploadingValue = null; });
      widget.pending?.remove(this);
    }
  }

  @override
  void initState() {
    super.initState();
    _field.text = _probableServerContents = widget.value;
    widget.focusNode.addListener(_focusChange);
  }

  @override
  void didUpdateWidget(ProfileField oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.focusNode.removeListener(_focusChange);
    widget.focusNode.addListener(_focusChange);
    if (oldWidget.value != widget.value && !widget.focusNode.hasFocus && !_updating)
      _field.text = _probableServerContents = widget.value;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusChange);
    super.dispose();
  }

  void _focusChange() {
    // TODO(ianh): This gets called more often than it should when tapping away.
    setState(() { _saved = false; });
    if (!widget.focusNode.hasFocus) {
      if (_updating) {
        if (_field.text != _currentlyUploadingValue)
          _save();
      } else {
        if (_field.text != _probableServerContents) {
          _save();
        } else {
          widget.pending?.remove(this);
        }
      }
    }
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
              widget.pending?.add(this);
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
              disabledBorder: OutlineInputBorder(borderSide: BorderSide(width: 1.0, color: Theme.of(context).disabledColor)),
              suffixIcon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.fastOutSlowIn,
                switchOutCurve: Curves.fastOutSlowIn,
                child:
                  _updating ? const CircularProgressIndicator() :
                  _saved ? const Tooltip(
                    message: 'Saved automatically.',
                    child: Icon(Icons.check),
                  ) :
                  const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({
    Key key,
    @required this.password,
  }) : super(key: key);

  final String password;

  @override
  _ChangePasswordDialogState createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final TextEditingController _passwordOld = TextEditingController();
  final TextEditingController _passwordNew1 = TextEditingController();
  final TextEditingController _passwordNew2 = TextEditingController();

  final FocusNode _passwordOldFocus = FocusNode();
  final FocusNode _passwordNew1Focus = FocusNode();
  final FocusNode _passwordNew2Focus = FocusNode();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool get _valid {
    return (_passwordOld.text == widget.password) &&
           AuthenticatedUser.isValidPassword(_passwordNew1.text) &&
           (_passwordNew1.text == _passwordNew2.text);
  }

  void _submit() async {
    await ProgressDialog.show<void>(context, Cruise.of(context).changePassword(_passwordNew1.text));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[
      SizedBox(
        height: 96.0,
        child: TextFormField(
          controller: _passwordOld,
          focusNode: _passwordOldFocus,
          autofocus: true,
          onFieldSubmitted: (String value) {
            FocusScope.of(context).requestFocus(_passwordNew1Focus);
          },
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Old password',
            errorMaxLines: null,
          ),
          obscureText: true,
          validator: (String password) {
            if (password.isNotEmpty) {
              if (password != widget.password)
                return 'Old password incorrect.';
            }
            return null;
          },
        ),
      ),
      SizedBox(
        height: 96.0,
        child: TextFormField(
          controller: _passwordNew1,
          focusNode: _passwordNew1Focus,
          autofocus: true,
          onFieldSubmitted: (String value) {
            FocusScope.of(context).requestFocus(_passwordNew2Focus);
          },
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'New password',
            errorMaxLines: null,
          ),
          obscureText: true,
          validator: (String password) {
            if (password.isNotEmpty) {
              if (!AuthenticatedUser.isValidPassword(password))
                return 'New password must be at least six characters long.';
            }
            return null;
          },
        ),
      ),
      SizedBox(
        height: 96.0,
        child: TextFormField(
          controller: _passwordNew2,
          focusNode: _passwordNew2Focus,
          autofocus: true,
          onFieldSubmitted: (String value) {
            if (_valid)
              _submit();
          },
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Confirm new password',
            errorMaxLines: null,
          ),
          obscureText: true,
          validator: (String password) {
            if (password.isNotEmpty) {
              if (password != _passwordNew1.text)
                return 'Passwords don\'t match.';
            }
            return null;
          },
        ),
      ),
    ];

    return AlertDialog(
      title: const Text('Change Password'),
      contentPadding: const EdgeInsets.fromLTRB(0.0, 20.0, 0.0, 0.0),
      content: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: Divider.createBorderSide(context),
            bottom: Divider.createBorderSide(context),
          ),
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.always,
          onChanged: () {
            setState(() {
              /* need to recheck whether the submit button should be enabled */
            });
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 8.0),
            child: ListBody(
              children: children,
            ),
          ),
        ),
      ),
      actions: <Widget>[
        FlatButton(
          onPressed: _valid ? _submit : null,
          child: const Text('CHANGE PASSWORD'),
        ),
      ],
    );
  }
}
