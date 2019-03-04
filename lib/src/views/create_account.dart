import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/errors.dart';
import '../models/user.dart';
import '../progress.dart';
import '../widgets.dart';

class CreateAccount extends StatefulWidget {
  const CreateAccount({
    Key key,
  }) : super(key: key);

  @override
  _CreateAccountState createState() => _CreateAccountState();
}

enum _AccountCreationField { username, password, registrationCode, displayName }

class _AccountCreationServerResponse {
  _AccountCreationServerResponse(this.fields, { @required this.close });
  final Map<_AccountCreationField, String> fields;
  bool close;
}

class _CreateAccountState extends State<CreateAccount> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password1 = TextEditingController();
  final TextEditingController _password2 = TextEditingController();
  final TextEditingController _registrationCode = TextEditingController();
  final TextEditingController _displayName = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _password1Focus = FocusNode();
  final FocusNode _password2Focus = FocusNode();
  final FocusNode _registrationCodeFocus = FocusNode();
  final FocusNode _displayNameFocus = FocusNode();

  _AccountCreationServerResponse _latestServerResponse = _AccountCreationServerResponse(const <_AccountCreationField, String>{}, close: false);

  bool get _valid {
    return AuthenticatedUser.isValidUsername(_username.text) &&
           AuthenticatedUser.isValidDisplayName(_username.text) &&
           AuthenticatedUser.isValidPassword(_password1.text) &&
           (_password1.text == _password2.text) &&
           AuthenticatedUser.isValidRegistrationCode(_registrationCode.text) &&
           (_displayName.text == '' || AuthenticatedUser.isValidDisplayName(_displayName.text));
  }

  void _createAccount() async {
    assert(_valid);
    final Progress<String> progress = Cruise.of(context).createAccount(
      username: _username.text,
      password: _password1.text,
      registrationCode: _registrationCode.text,
      displayName: _displayName.text == '' ? null : _displayName.text,
    );
    final _AccountCreationServerResponse serverResponse = await showDialog<_AccountCreationServerResponse>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _AccountCreationStatus(
        username: _username.text,
        progress: progress,
      ),
    );
    if (serverResponse?.close == true) {
      Navigator.pop(context);
    } else {
      setState(() { _latestServerResponse = serverResponse; });
      if (_latestServerResponse.fields.length == 1) {
        switch (_latestServerResponse.fields.keys.single) {
          case _AccountCreationField.username: FocusScope.of(context).requestFocus(_usernameFocus); break;
          case _AccountCreationField.password: FocusScope.of(context).requestFocus(_password1Focus); break;
          case _AccountCreationField.registrationCode: FocusScope.of(context).requestFocus(_registrationCodeFocus); break;
          case _AccountCreationField.displayName: FocusScope.of(context).requestFocus(_displayNameFocus); break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Twitarr account'),
      ),
      body: Form(
        key: _formKey,
        autovalidate: true,
        onChanged: () {
          setState(() {
            /* need to recheck whether the submit button should be enabled */
          });
        },
        onWillPop: () => confirmDialog(context, 'Cancel account creation?'),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 8.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    const ServerTextView('welcome'),
                    const SizedBox(height: 24.0),
                    SizedBox(
                      height: 96.0,
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: TextFormField(
                          controller: _username,
                          focusNode: _usernameFocus,
                          autofocus: true,
                          onFieldSubmitted: (String value) {
                            FocusScope.of(context).requestFocus(_password1Focus);
                          },
                          textInputAction: TextInputAction.next,
                          maxLength: 40,
                          decoration: const InputDecoration(
                            labelText: 'User name',
                            errorMaxLines: null,
                          ),
                          validator: (String name) {
                            if (name.isNotEmpty) {
                              if (!AuthenticatedUser.isValidUsername(name))
                                return 'User names must be alphabetic and between three and forty characters long.';
                              if (!AuthenticatedUser.isValidDisplayName(name))
                                return 'User names are also used as display names.';
                            }
                            return _latestServerResponse.fields[_AccountCreationField.username];
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 96.0,
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: TextFormField(
                          controller: _password1,
                          focusNode: _password1Focus,
                          onFieldSubmitted: (String value) {
                            FocusScope.of(context).requestFocus(_password2Focus);
                          },
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            errorMaxLines: null,
                          ),
                          validator: (String password) {
                            if (password.isNotEmpty) {
                              if (!AuthenticatedUser.isValidPassword(password))
                                return 'Passwords must be at least six characters long.';
                            }
                            return _latestServerResponse.fields[_AccountCreationField.password];
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 96.0,
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: TextFormField(
                          controller: _password2,
                          focusNode: _password2Focus,
                          onFieldSubmitted: (String value) {
                            FocusScope.of(context).requestFocus(_registrationCodeFocus);
                          },
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                            helperText: 'To make sure you know it.',
                            errorMaxLines: null,
                          ),
                          validator: (String password) {
                            if (password.isEmpty)
                              return null;
                            if (password != _password1.text)
                              return 'Passwords don\'t match.';
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 96.0,
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: TextFormField(
                          controller: _registrationCode,
                          focusNode: _registrationCodeFocus,
                          onFieldSubmitted: (String value) {
                            FocusScope.of(context).requestFocus(_displayNameFocus);
                          },
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Registration code',
                            helperText: 'Provided to you by e-mail before the cruise.',
                            errorMaxLines: null,
                          ),
                          validator: (String registrationCode) {
                            if (registrationCode.isNotEmpty) {
                              if (!AuthenticatedUser.isValidRegistrationCode(registrationCode))
                                return 'Ask the JoCo Cruise Info Desk for advice.';
                            }
                            return _latestServerResponse.fields[_AccountCreationField.registrationCode];
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 96.0,
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: TextFormField(
                          controller: _displayName,
                          focusNode: _displayNameFocus,
                          onFieldSubmitted: (String value) {
                            if (_valid)
                              _createAccount();
                          },
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          maxLength: 40,
                          decoration: const InputDecoration(
                            labelText: 'Display name (optional)',
                            helperText: 'Defaults to the username if not specified.',
                            errorMaxLines: null,
                          ),
                          validator: (String displayName) {
                            if (displayName.isNotEmpty) {
                              if (_displayName.text != '' && !AuthenticatedUser.isValidDisplayName(displayName))
                                return 'Display name is not valid.';
                            }
                            return _latestServerResponse.fields[_AccountCreationField.displayName];
                          },
                        ),
                      ),
                    ),
                    ButtonBar(
                      children: <Widget>[
                        FlatButton(
                          onPressed: () { Navigator.maybePop(context); },
                          child: const Text('CANCEL'),
                        ),
                        FlatButton(
                          onPressed: _valid ? _createAccount : null,
                          child: const Text('CREATE ACCOUNT'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCreationStatus extends StatelessWidget {
  const _AccountCreationStatus({
    Key key,
    @required this.progress,
    @required this.username,
  }) : assert(progress != null),
       assert(username != null),
       super(key: key);

  static final _AccountCreationServerResponse close = _AccountCreationServerResponse(null, close: true);

  final Progress<String> progress;
  final String username;

  @override
  Widget build(BuildContext context) {
    final Widget idleStatus = AlertDialog(
      title: const Text('Creating account...'),
      content: const Center(
        heightFactor: 1.5,
        child: CircularProgressIndicator(),
      ),
      actions: <Widget>[
        FlatButton(
          onPressed: () { Navigator.of(context).pop(close); },
          child: const Text('CANCEL'),
        ),
      ],
    );
    return ProgressBuilder<String>(
      progress: progress,
      idleChild: idleStatus,
      startingChild: idleStatus,
      activeBuilder: (BuildContext context, double progress, double target) {
        return AlertDialog(
          title: const Text('Creating account...'),
          content: Center(
            heightFactor: 1.5,
            child: CircularProgressIndicator(
              value: progress / target,
            ),
          ),
          actions: <Widget>[
            FlatButton(
              onPressed: () { Navigator.of(context).pop(close); },
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
      failedBuilder: (BuildContext context, Exception error, StackTrace stackTrace) {
        final List<String> messages = <String>[];
        final Map<_AccountCreationField, String> fields = <_AccountCreationField, String>{};
        if (error is FieldErrors) {
          for (String field in error.fields.keys) {
            _AccountCreationField fieldIdentifier;
            switch (field) {
              case 'username': fieldIdentifier = _AccountCreationField.username; break;
              case 'password': fieldIdentifier = _AccountCreationField.password; break;
              case 'registration_code': fieldIdentifier = _AccountCreationField.registrationCode; break;
              case 'display_name': fieldIdentifier = _AccountCreationField.displayName; break;
            }
            if (fieldIdentifier != null)
              fields[fieldIdentifier] = error.fields[field].join(' ');
            messages.addAll(error.fields[field]);
          }
        } else if (error is ServerError) {
          for (String message in error.messages) {
            message = message.trim();
            // The server doesn't always send back fully punctuated messages, so
            // we fix them up here.
            if (message.endsWith('.') || message.endsWith('?') || message.endsWith('!')) {
              messages.add(message);
            } else {
              messages.add('$message.');
            }
          }
        } else if (error is UserFriendlyError) {
          messages.add('$error');
        } else if (error != null && error.toString().isNotEmpty) {
          messages.add('An unexpected error occurred:\n$error');
        }
        if (messages.isEmpty)
          messages.add('The server unfortunately did not send back a reason why the account creation failed.');
        return AlertDialog(
          title: const Text('Account creation failed'),
          content: SingleChildScrollView(
            child: ListBody(
              children: messages.map<Widget>((String message) => Text(message)).toList(),
            ),
          ),
          actions: <Widget>[
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop(_AccountCreationServerResponse(fields, close: false));
              },
              child: const Text('BACK'),
            ),
          ],
        );
      },
      builder: (BuildContext context, String value) {
        return AlertDialog(
          title: const Text('Account created!'),
          content: Text('Your account username is "$value".'),
          actions: <Widget>[
            FlatButton(
              onPressed: () { Navigator.of(context).pop(close); },
              child: const Text('YAY!'),
            ),
          ],
        );
      }
    );
  }
}