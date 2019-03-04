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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool get _valid {
    return AuthenticatedUser.isValidUsername(_username.text) &&
           AuthenticatedUser.isValidPassword(_password.text);
  }

  @override
  Widget build(BuildContext context) {
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
          autovalidate: true,
          onChanged: () {
            setState(() {
              /* need to recheck whether the submit button should be enabled */
            });
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 8.0),
            child: ListBody(
              children: <Widget>[
                SizedBox(
                  height: 96.0,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: TextFormField(
                      controller: _username,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'User name',
                      ),
                      validator: (String name) {
                        if (!AuthenticatedUser.isValidUsername(name))
                          return 'User names are be alphabetic and at least three characters long.';
                      },
                    ),
                  ),
                ),
                SizedBox(
                  height: 96.0,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                      ),
                      validator: (String password) {
                        if (password.isNotEmpty && !AuthenticatedUser.isValidPassword(password, allowShort: true))
                          return 'Passwords are at least six characters long.';
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        FlatButton(
          onPressed: _valid ? () {
            Cruise.of(context).login(
              username: _username.text,
              password: _password.text,
            );
            Navigator.pop(context);
          } : null,
          child: const Text('LOGIN'),
        ),
      ],
    );
  }
}
