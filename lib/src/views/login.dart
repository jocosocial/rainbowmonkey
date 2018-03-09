import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../widgets.dart';

class LoginDialog extends StatefulWidget {
  const LoginDialog({
    Key key,
  }) : super(key: key);

  @override
  _LoginDialogState createState() => new _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final TextEditingController _username = new TextEditingController();
  final TextEditingController _password = new TextEditingController();
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();

  bool get _valid {
    return User.isValidUsername(_username.text) &&
           User.isValidPassword(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    return new AlertDialog(
      title: const Text('Login'),
      contentPadding: const EdgeInsets.fromLTRB(0.0, 20.0, 0.0, 0.0),
      content: new DecoratedBox(
        decoration: new BoxDecoration(
          border: new Border(
            top: Divider.createBorderSide(context),
            bottom: Divider.createBorderSide(context),
          ),
        ),
        child: new Form(
          key: _formKey,
          autovalidate: true,
          onChanged: () {
            setState(() {
              /* need to recheck whether the submit button should be enabled */
            });
          },
          child: new SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 8.0),
            child: new ListBody(
              children: <Widget>[
                new SizedBox(
                  height: 96.0,
                  child: new Align(
                    alignment: AlignmentDirectional.topStart,
                    child: new TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(
                        labelText: 'User name',
                      ),
                      validator: (String name) {
                        if (!User.isValidUsername(name))
                          return 'User names are be alphabetic and at least three characters long.';
                      },
                    ),
                  ),
                ),
                new SizedBox(
                  height: 96.0,
                  child: new Align(
                    alignment: AlignmentDirectional.topStart,
                    child: new TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                      ),
                      validator: (String password) {
                        if (!User.isValidPassword(password))
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
        new FlatButton(
          onPressed: () {
            Cruise.of(context).login(
              username: 'aaa',
              password: 'aaaaaa',
            );
            Navigator.pop(context);
          },
          child: const Text('TEST AAA'),
        ),
        new FlatButton(
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
