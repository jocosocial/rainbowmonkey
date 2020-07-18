import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../widgets.dart';

class LoginDialog extends StatefulWidget {
  const LoginDialog({
    Key key,
  }) : super(key: key);

  @override
  _LoginDialogState createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _password1 = TextEditingController();
  final TextEditingController _password2 = TextEditingController();
  final TextEditingController _registrationCode = TextEditingController();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _password1Focus = FocusNode();
  final FocusNode _password2Focus = FocusNode();
  final FocusNode _registrationCodeFocus = FocusNode();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool get _valid {
    if (_forgot) {
      return AuthenticatedUser.isValidUsername(_username.text) &&
             AuthenticatedUser.isValidPassword(_password1.text) &&
             (_password1.text == _password2.text) &&
             AuthenticatedUser.isValidRegistrationCode(_registrationCode.text);
    }
    return AuthenticatedUser.isValidUsername(_username.text) &&
           AuthenticatedUser.isValidPassword(_password.text);
  }

  void _submit() {
    assert(_valid);
    if (_forgot) {
      Cruise.of(context).resetPassword(
        username: _username.text,
        registrationCode: _registrationCode.text,
        password: _password1.text,
      );
      Navigator.pop(context);
    } else {
      Cruise.of(context).login(
        username: _username.text,
        password: _password.text,
      );
      Navigator.pop(context);
    }
  }

  bool _forgot = false;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[
      const SizedBox(height: 12.0),
      SizedBox(
        height: 96.0,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: TextFormField(
            controller: _username,
            focusNode: _usernameFocus,
            autofocus: true,
            onFieldSubmitted: (String value) {
              FocusScope.of(context).requestFocus(_forgot ? _registrationCodeFocus : _passwordFocus);
            },
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'User name',
              errorMaxLines: null,
            ),
            validator: (String name) {
              if (name.isNotEmpty) {
                if (!AuthenticatedUser.isValidUsername(name))
                  return 'User names must be alphabetic and between three and forty characters long.';
              }
              return null;
            },
          ),
        ),
      ),
    ];
    if (_forgot) {
      children.addAll(<Widget>[
        SizedBox(
          height: 96.0,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: TextFormField(
              controller: _registrationCode,
              focusNode: _registrationCodeFocus,
              onFieldSubmitted: (String value) {
                FocusScope.of(context).requestFocus(_password1Focus);
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
                return null;
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
              textInputAction: TextInputAction.next,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                errorMaxLines: null,
              ),
              validator: (String password) {
                if (password.isNotEmpty) {
                  if (!AuthenticatedUser.isValidPassword(password))
                    return 'Passwords must be at least six characters long.';
                }
                return null;
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
                if (_valid)
                  _submit();
              },
              textInputAction: TextInputAction.done,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
                errorMaxLines: null,
              ),
              validator: (String password) {
                if (password.isEmpty)
                  return null;
                if (password != _password1.text) {
                  return 'Passwords don\'t match.';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 12.0),
        const Text('If you no longer have your registration desk, ask the JoCo info desk in the Atrium on Deck 1. If you remembered your password, you can log in with that instead.'),
        FlatButton(
          onPressed: () {
            setState(() {
              _forgot = false;
            });
            FocusScope.of(context).requestFocus(_usernameFocus);
          },
          child: const Text('USE PASSWORD'),
        ),
      ]);
    } else {
      children.addAll(<Widget>[
        SizedBox(
          height: 96.0,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: TextFormField(
              controller: _password,
              focusNode: _passwordFocus,
              onFieldSubmitted: (String value) {
                if (_valid)
                  _submit();
              },
              textInputAction: TextInputAction.done,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                errorMaxLines: null,
              ),
              validator: (String password) {
                if (password.isNotEmpty) {
                  if (!AuthenticatedUser.isValidPassword(password))
                    return 'Passwords must be at least six characters long.';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 12.0),
        const Text('If you forgot your password, you can log in again using your registration code instead. If you no longer have that, ask the JoCo info desk in the Atrium on Deck 1.'),
        FlatButton(
          onPressed: () {
            setState(() {
              _forgot = true;
            });
            FocusScope.of(context).requestFocus(_usernameFocus);
          },
          child: const Text('FORGOT PASSWORD'),
        ),
      ]);
    }
    return AlertDialog(
      title: const Text('Login'),
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
          child: const Text('LOGIN'),
        ),
      ],
    );
  }
}
